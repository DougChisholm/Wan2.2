#!/bin/bash

# Wan 2.2 Video API - Azure Deployment Script
# This script deploys the complete infrastructure to Azure including:
# - Azure Container Registry (ACR)
# - Docker image build and push
# - Azure Container Apps with A100 GPU support

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration - can be overridden by environment variables
RESOURCE_GROUP="${RESOURCE_GROUP:-wan-video-api-rg}"
LOCATION="${LOCATION:-eastus}"
BASE_NAME="${BASE_NAME:-wan-video-api}"
MODEL_TYPE="${MODEL_TYPE:-ti2v-5B}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
MIN_REPLICAS="${MIN_REPLICAS:-1}"
MAX_REPLICAS="${MAX_REPLICAS:-3}"

# Derived names (actual registry name will be determined by Bicep's uniqueString function)
# This is just for logging/reference
UNIQUE_SUFFIX=$(date +%s | tail -c 5)
REGISTRY_NAME="acrwanvideoapi${UNIQUE_SUFFIX}"
IMAGE_NAME="wan-api"

log_info "==================================================================="
log_info "Wan 2.2 Video API - Azure Deployment"
log_info "==================================================================="
log_info "Configuration:"
log_info "  Resource Group: $RESOURCE_GROUP"
log_info "  Location: $LOCATION"
log_info "  Base Name: $BASE_NAME"
log_info "  Model Type: $MODEL_TYPE"
log_info "  Image Tag: $IMAGE_TAG"
log_info "  Container Registry: $REGISTRY_NAME"
log_info "==================================================================="

# Check prerequisites
log_info "Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install it from https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if logged into Azure
log_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    log_error "You are not logged into Azure. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
log_success "Logged into Azure subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create resource group
log_info "Creating resource group: $RESOURCE_GROUP in $LOCATION..."
if az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none; then
    log_success "Resource group created/updated successfully"
else
    log_error "Failed to create resource group"
    exit 1
fi

# Deploy Azure Container Registry first (separate deployment for ACR)
log_info "Deploying Azure Container Registry..."
ACR_DEPLOYMENT_NAME="acr-deployment-$(date +%s)"

# Generate registry name that matches Bicep's logic
UNIQUE_SUFFIX=$(az group show --name "$RESOURCE_GROUP" --query id -o tsv | md5sum | cut -c1-13)
REGISTRY_NAME="acrwanvideoapi${UNIQUE_SUFFIX}"

if az deployment group create \
    --name "$ACR_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infra/acr.bicep \
    --parameters registryName="$REGISTRY_NAME" \
                 location="$LOCATION" \
    --query 'properties.outputs.registryName.value' \
    -o tsv > /tmp/registry_name.txt; then
    REGISTRY_NAME=$(cat /tmp/registry_name.txt)
    log_success "Azure Container Registry deployed: $REGISTRY_NAME"
else
    log_error "Failed to deploy Azure Container Registry"
    exit 1
fi

# Get ACR login server
log_info "Retrieving ACR credentials..."
ACR_LOGIN_SERVER=$(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)
log_success "ACR Login Server: $ACR_LOGIN_SERVER"

# Login to ACR
log_info "Logging into Azure Container Registry..."
if az acr login --name "$REGISTRY_NAME"; then
    log_success "Logged into ACR successfully"
else
    log_error "Failed to login to ACR"
    exit 1
fi

# Build Docker image
log_info "Building Docker image: $IMAGE_NAME:$IMAGE_TAG..."
log_info "This may take 15-30 minutes due to PyTorch and flash-attn compilation..."
FULL_IMAGE_NAME="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

if docker build -t "$FULL_IMAGE_NAME" .; then
    log_success "Docker image built successfully"
else
    log_error "Failed to build Docker image"
    exit 1
fi

# Push Docker image to ACR
log_info "Pushing Docker image to ACR: $FULL_IMAGE_NAME..."
if docker push "$FULL_IMAGE_NAME"; then
    log_success "Docker image pushed successfully"
else
    log_error "Failed to push Docker image"
    exit 1
fi

# Wait for image to be available in ACR
log_info "Waiting for image to be available in ACR..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if az acr repository show --name "$REGISTRY_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" &> /dev/null; then
        log_success "Image is available in ACR"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_info "Waiting for image to be available... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    log_error "Timeout waiting for image to be available in ACR"
    exit 1
fi

# Get image details from ACR
log_info "Retrieving image details from ACR..."
IMAGE_DIGEST=$(az acr repository show --name "$REGISTRY_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --query digest -o tsv)
log_success "Image digest: $IMAGE_DIGEST"

# Deploy Container App using Bicep
log_info "Deploying Azure Container App with GPU support..."
log_info "This will create a container app with A100 GPU..."
CONTAINER_APP_DEPLOYMENT_NAME="container-app-deployment-$(date +%s)"

if az deployment group create \
    --name "$CONTAINER_APP_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --template-file infra/main.bicep \
    --parameters baseName="$BASE_NAME" \
                 location="$LOCATION" \
                 containerImageTag="$IMAGE_TAG" \
                 modelType="$MODEL_TYPE" \
                 minReplicas="$MIN_REPLICAS" \
                 maxReplicas="$MAX_REPLICAS" \
    --output none; then
    log_success "Container App deployed successfully"
else
    log_error "Failed to deploy Container App"
    exit 1
fi

# Get deployment outputs
log_info "Retrieving deployment information..."
CONTAINER_APP_URL=$(az deployment group show \
    --name "$CONTAINER_APP_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.outputs.containerAppUrl.value -o tsv)

CONTAINER_APP_NAME=$(az deployment group show \
    --name "$CONTAINER_APP_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.outputs.containerAppName.value -o tsv)

log_success "==================================================================="
log_success "Deployment completed successfully!"
log_success "==================================================================="
log_success "Container App URL: $CONTAINER_APP_URL"
log_success "Container App Name: $CONTAINER_APP_NAME"
log_success "Resource Group: $RESOURCE_GROUP"
log_success "Container Registry: $ACR_LOGIN_SERVER"
log_success "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
log_success "==================================================================="
log_info ""
log_info "API Endpoints:"
log_info "  Health Check: $CONTAINER_APP_URL/health"
log_info "  API Root: $CONTAINER_APP_URL/"
log_info "  Generate Video: POST $CONTAINER_APP_URL/generate"
log_info ""
log_info "Example curl command to test the API:"
log_info "curl -X POST \"$CONTAINER_APP_URL/generate\" \\"
log_info "  -F \"prompt=A cat sitting on a surfboard\" \\"
log_info "  -F \"task=$MODEL_TYPE\" \\"
log_info "  -F \"size=1280*704\" \\"
log_info "  -o output.mp4"
log_info ""
log_info "To view logs:"
log_info "az containerapp logs show --name \"$CONTAINER_APP_NAME\" --resource-group \"$RESOURCE_GROUP\" --follow"
log_info ""
log_success "Deployment complete!"
