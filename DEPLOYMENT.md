# Wan 2.2 Video Generation API - Azure Deployment

This directory contains the infrastructure and deployment scripts to deploy the Wan 2.2 video generation model as a REST API on Azure using Container Apps with A100 GPU support.

## Overview

The deployment creates:
- **Azure Container Registry (ACR)**: Stores the Docker container image
- **Azure Container Apps**: Runs the API with A100 GPU support
- **Log Analytics Workspace**: Monitors application logs and metrics
- **REST API**: FastAPI-based service for video generation

## Prerequisites

Before deploying, ensure you have:

1. **Azure CLI** installed ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
2. **Docker** installed ([Installation Guide](https://docs.docker.com/get-docker/))
3. **Azure Subscription** with appropriate permissions
4. **Logged into Azure**: Run `az login`

## Quick Start

### 1. Login to Azure

```bash
az login
```

### 2. Set Configuration (Optional)

You can customize the deployment by setting environment variables:

```bash
export RESOURCE_GROUP="wan-video-api-rg"
export LOCATION="eastus"
export BASE_NAME="wan-video-api"
export MODEL_TYPE="ti2v-5B"  # Options: ti2v-5B, t2v-A14B, i2v-A14B
export IMAGE_TAG="latest"
export MIN_REPLICAS="1"
export MAX_REPLICAS="3"
```

### 3. Deploy to Azure

Run the deployment script:

```bash
./deploy.sh
```

The script will:
1. Create a resource group
2. Deploy Azure Container Registry
3. Build the Docker image (takes 15-30 minutes)
4. Push the image to ACR
5. Wait for the image to be available
6. Deploy Azure Container Apps with A100 GPU
7. Output the API endpoint URL

### 4. Test the API

Once deployed, the script will output the API URL. Test it with:

```bash
# Health check
curl https://<your-app-url>/health

# Generate video from text
curl -X POST "https://<your-app-url>/generate" \
  -F "prompt=A cat sitting on a surfboard" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -o output.mp4

# Generate video from text and image
curl -X POST "https://<your-app-url>/generate" \
  -F "prompt=A white cat wearing sunglasses on a beach" \
  -F "image=@path/to/image.jpg" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -o output.mp4
```

## API Endpoints

### `GET /`
Root endpoint - API information and health status

### `GET /health`
Health check endpoint

### `POST /generate`
Generate a video from a text prompt and optional image

**Parameters:**
- `prompt` (required): Text description for the video
- `image` (optional): Image file for image-to-video generation
- `task` (optional): Model task type (default: "ti2v-5B")
  - `ti2v-5B`: Text/Image-to-Video (most efficient, 720P)
  - `t2v-A14B`: Text-to-Video (high quality, 480P/720P)
  - `i2v-A14B`: Image-to-Video (high quality, 480P/720P)
- `size` (optional): Video resolution (default: "1280*704")
  - For ti2v-5B: "1280*704" or "704*1280"
  - For t2v/i2v-A14B: "1280*720", "720*1280", "480*832", "832*480"
- `frame_num` (optional): Number of frames to generate
- `seed` (optional): Random seed (-1 for random)
- `sample_steps` (optional): Number of sampling steps
- `guide_scale` (optional): Guidance scale

**Response:**
Returns an MP4 video file

### `GET /tasks`
List available model tasks

### `GET /sizes/{task}`
List supported sizes for a specific task

## Infrastructure Details

### Azure Resources

The deployment creates the following Azure resources:

1. **Container Registry (ACR)**
   - SKU: Premium
   - Purpose: Store Docker images
   - Features: Admin user enabled, retention policy

2. **Container App Environment**
   - Workload Profile: NC24ads-A100-v4 (A100 GPU)
   - Minimum Count: 1
   - Maximum Count: 3

3. **Container App**
   - Resources: 4 CPU cores, 16GB memory, 1x A100 GPU
   - Scaling: HTTP-based autoscaling (10 concurrent requests)
   - Health Checks: Liveness and readiness probes
   - Ingress: External HTTPS endpoint

4. **Log Analytics Workspace**
   - Purpose: Application logs and monitoring
   - Retention: 30 days

### GPU Configuration

The deployment uses Azure's NC24ads-A100-v4 VM size which includes:
- 1x NVIDIA A100 GPU (40GB memory)
- 24 CPU cores
- 220GB RAM
- High-performance NVMe storage

## File Structure

```
.
├── api.py                    # FastAPI application
├── Dockerfile                # Docker container definition
├── requirements_api.txt      # API-specific Python dependencies
├── deploy.sh                 # Main deployment script
├── infra/
│   ├── main.bicep           # Main Bicep orchestration template
│   ├── acr.bicep            # Azure Container Registry template
│   └── container-app.bicep  # Container Apps with GPU template
└── DEPLOYMENT.md            # This file
```

## Configuration

### Environment Variables

The API accepts the following environment variables:

- `MODEL_TYPE`: Model to use (default: "ti2v-5B")
- `MODEL_PATH`: Path to model checkpoints (default: "/app/models")
- `DEVICE_ID`: CUDA device ID (default: "0")
- `OUTPUT_DIR`: Directory for output videos (default: "/tmp/outputs")
- `HOST`: API host (default: "0.0.0.0")
- `PORT`: API port (default: "8000")

### Model Selection

Three model types are available:

1. **ti2v-5B** (Recommended for production)
   - Most efficient model
   - Supports both text-to-video and image-to-video
   - 720P resolution at 24fps
   - Can run on consumer GPUs
   - Fastest inference time

2. **t2v-A14B**
   - High-quality text-to-video
   - MoE architecture (27B total, 14B active)
   - Supports 480P and 720P
   - Requires 80GB+ GPU memory

3. **i2v-A14B**
   - High-quality image-to-video
   - MoE architecture (27B total, 14B active)
   - Supports 480P and 720P
   - Requires 80GB+ GPU memory

## Monitoring and Logs

### View Container App Logs

```bash
# Follow logs in real-time
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow

# Query logs using Log Analytics
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == '<app-name>' | project TimeGenerated, Log_s"
```

### View Metrics

```bash
# Get container app metrics
az monitor metrics list \
  --resource <container-app-resource-id> \
  --metric "Requests" "HttpResponseTime"
```

## Troubleshooting

### Image Build Fails

If the Docker build fails during flash-attn compilation:
- Ensure you have sufficient disk space (30GB+)
- Try building with more memory allocated to Docker
- Check Docker logs for specific errors

### Container App Fails to Start

1. Check logs:
   ```bash
   az containerapp logs show --name <app-name> --resource-group <rg-name> --follow
   ```

2. Verify GPU availability:
   ```bash
   az containerapp show --name <app-name> --resource-group <rg-name> --query "properties.template.containers[0].resources.gpu"
   ```

3. Check model path:
   - Ensure `MODEL_PATH` environment variable is set correctly
   - Model checkpoints should be in the container image or mounted volume

### API Returns 500 Error

1. Check if model checkpoints are available
2. Verify GPU is accessible (check CUDA_VISIBLE_DEVICES)
3. Review application logs for specific errors
4. Ensure sufficient GPU memory for the selected model

### Slow Inference

- Use ti2v-5B for faster inference
- Reduce frame_num parameter
- Decrease sample_steps
- Check if GPU is being utilized (should show in logs)

## Cost Considerations

### Estimated Monthly Costs

Based on Azure pricing (as of 2024):

- **Container Registry (Premium)**: ~$525/month
- **Container Apps (NC24ads-A100-v4)**:
  - Per GPU hour: ~$3.67
  - 1 replica, 24/7: ~$2,650/month
  - 1 replica, 8hrs/day: ~$880/month
- **Log Analytics**: ~$2.30/GB ingested + $0.12/GB retention

**Total (1 replica, 24/7)**: ~$3,175/month

### Cost Optimization Tips

1. **Scale to Zero**: Modify minReplicas to 0 in container-app.bicep
2. **Use Spot Instances**: If available for your region
3. **Optimize Image Size**: Remove unused dependencies
4. **Batch Requests**: Process multiple videos in one request
5. **Use Smaller Models**: ti2v-5B is more cost-effective

## Security Considerations

1. **API Authentication**: Add authentication middleware (JWT, API keys)
2. **Network Security**: Configure virtual network integration
3. **Secrets Management**: Use Azure Key Vault for sensitive data
4. **Input Validation**: Validate and sanitize all user inputs
5. **Rate Limiting**: Implement rate limiting to prevent abuse

## Cleanup

To delete all deployed resources:

```bash
az group delete --name <resource-group-name> --yes --no-wait
```

## Model Download

The Docker image expects model checkpoints in `/app/models`. You have two options:

### Option 1: Download During Build (Not Recommended)
Increase image size significantly. Not included by default.

### Option 2: Mount from Azure Storage (Recommended)
1. Upload models to Azure Blob Storage or Azure Files
2. Mount the storage to the Container App
3. Update MODEL_PATH to point to the mount

Example for Azure Files:

```bash
# Create storage account and file share
az storage account create --name wanmodels --resource-group <rg> --location <loc>
az storage share create --name models --account-name wanmodels

# Upload models to file share
az storage file upload-batch --destination models --source ./local-models --account-name wanmodels

# Add storage mount to container app (update container-app.bicep)
```

## Support

For issues specific to:
- **Wan 2.2 Model**: See [main README](../README.md) and [project page](https://wan.video)
- **Azure Deployment**: Check Azure documentation or open an issue
- **API Issues**: Review application logs and API documentation

## License

This deployment infrastructure is provided as-is. The Wan 2.2 models are licensed under Apache 2.0 License. See [LICENSE.txt](../LICENSE.txt) for details.
