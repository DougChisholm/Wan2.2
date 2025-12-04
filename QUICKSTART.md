# Quick Start Guide - Wan 2.2 API Deployment

This guide will help you quickly deploy the Wan 2.2 video generation API to Azure.

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] Azure subscription with appropriate permissions
- [ ] Azure CLI installed (`az --version` to check)
- [ ] Docker installed (`docker --version` to check)
- [ ] Logged into Azure (`az login`)
- [ ] ~30GB free disk space for Docker build
- [ ] Stable internet connection (image push takes time)

## Step-by-Step Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/DougChisholm/Wan2.2.git
cd Wan2.2
```

### 2. Login to Azure

```bash
az login
```

Follow the prompts to authenticate.

### 3. (Optional) Customize Configuration

Edit environment variables or use defaults:

```bash
# Optional: Set custom configuration
export RESOURCE_GROUP="my-wan-api-rg"
export LOCATION="eastus"
export MODEL_TYPE="ti2v-5B"
```

Or edit `infra/parameters.json` for Bicep parameters.

### 4. Run Deployment Script

```bash
./deploy.sh
```

**Expected Duration:** 30-45 minutes
- Docker build: 15-30 minutes (includes PyTorch and flash-attn compilation)
- ACR deployment: 2-3 minutes
- Image push: 5-10 minutes
- Container App deployment: 3-5 minutes

### 5. Verify Deployment

Once complete, the script will output your API URL:

```bash
# Test health endpoint
curl https://your-app-url.azurecontainerapps.io/health

# Should return: {"status":"healthy"}
```

### 6. Generate Your First Video

```bash
# Text-to-video
curl -X POST "https://your-app-url.azurecontainerapps.io/generate" \
  -F "prompt=A cat playing with a ball of yarn" \
  -F "task=ti2v-5B" \
  -F "size=1280*704" \
  -o my_first_video.mp4
```

## What Gets Deployed?

The deployment creates these Azure resources:

1. **Resource Group**: Container for all resources
2. **Container Registry**: Stores your Docker image
3. **Log Analytics Workspace**: Application monitoring and logs
4. **Container App Environment**: GPU-enabled runtime environment
5. **Container App**: Your API running with A100 GPU

## Deployment Architecture

```
┌─────────────────────────────────────────────┐
│           Azure Resource Group              │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │   Azure Container Registry (ACR)      │ │
│  │   - Stores Docker images              │ │
│  └───────────────────────────────────────┘ │
│                      │                      │
│                      ▼                      │
│  ┌───────────────────────────────────────┐ │
│  │   Container App Environment           │ │
│  │   - GPU Workload Profile (A100)       │ │
│  │   - Log Analytics Integration         │ │
│  │                                        │ │
│  │   ┌─────────────────────────────────┐ │ │
│  │   │   Container App                 │ │ │
│  │   │   - FastAPI Server              │ │ │
│  │   │   - Wan 2.2 Model               │ │ │
│  │   │   - HTTPS Endpoint              │ │ │
│  │   │   - Auto-scaling (1-3 replicas) │ │ │
│  │   └─────────────────────────────────┘ │ │
│  └───────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

## Common Issues & Solutions

### Issue: Docker build fails
**Solution:** Ensure you have 30GB+ free space and sufficient memory (16GB+ recommended)

### Issue: "az: command not found"
**Solution:** Install Azure CLI from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

### Issue: "not logged in to Azure"
**Solution:** Run `az login` and authenticate

### Issue: Deployment takes too long
**Normal:** Docker build with PyTorch and flash-attn takes 15-30 minutes. Be patient!

### Issue: Container app fails to start
**Solution:** Check logs with:
```bash
az containerapp logs show \
  --name <app-name> \
  --resource-group <rg-name> \
  --follow
```

## Post-Deployment Configuration

### View Deployment Info

```bash
# Get container app URL
az containerapp show \
  --name wan-video-api-app \
  --resource-group wan-video-api-rg \
  --query "properties.configuration.ingress.fqdn" \
  -o tsv

# View logs
az containerapp logs show \
  --name wan-video-api-app \
  --resource-group wan-video-api-rg \
  --follow
```

### Scale Configuration

Edit `infra/parameters.json` and redeploy:

```json
{
  "minReplicas": { "value": 0 },  // Scale to zero when idle
  "maxReplicas": { "value": 5 }   // Support more concurrent requests
}
```

Then redeploy:
```bash
./deploy.sh
```

## Model Checkpoints

**Important:** The Docker image does NOT include model checkpoints (they're too large).

### Option 1: Mount Azure Storage (Recommended)

1. Upload models to Azure Files or Blob Storage
2. Mount to Container App
3. Update MODEL_PATH environment variable

### Option 2: Build Custom Image

1. Download models locally
2. Modify Dockerfile to copy models
3. Rebuild and deploy

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions.

## Cost Management

### Estimated Monthly Costs (1 replica, 24/7)
- Container Registry (Premium): ~$525
- Container App (A100 GPU): ~$2,650
- Log Analytics: ~$10
- **Total: ~$3,185/month**

### Cost Optimization Tips

1. **Scale to zero when not in use:**
   ```json
   "minReplicas": { "value": 0 }
   ```

2. **Use scheduled scaling:**
   Configure scale rules based on time of day

3. **Choose smaller regions:**
   Some regions have lower GPU pricing

4. **Delete when not needed:**
   ```bash
   az group delete --name wan-video-api-rg --yes
   ```

## Next Steps

- ✅ Review [DEPLOYMENT.md](DEPLOYMENT.md) for detailed documentation
- ✅ Explore [API_EXAMPLES.md](API_EXAMPLES.md) for usage examples
- ✅ Check [README.md](README.md) for model information
- ✅ Monitor costs in Azure Portal
- ✅ Set up authentication for production use
- ✅ Configure custom domain (optional)

## Cleanup

To delete all resources and stop billing:

```bash
az group delete --name wan-video-api-rg --yes --no-wait
```

**Warning:** This deletes everything including the Container Registry and any stored images!

## Getting Help

- Check [DEPLOYMENT.md](DEPLOYMENT.md) for troubleshooting
- Review Azure Container Apps documentation
- Check logs for specific errors
- Open an issue on GitHub

## Success Indicators

Your deployment is successful when:

- ✅ `deploy.sh` completes without errors
- ✅ Health check returns `{"status":"healthy"}`
- ✅ You can generate a test video
- ✅ Logs show "Model initialized successfully"

Congratulations! Your Wan 2.2 API is now running on Azure! 🎉
