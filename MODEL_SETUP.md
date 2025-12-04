# Important Note About Model Checkpoints

## ⚠️ Model Files Not Included

The Docker image does **NOT** include the actual Wan 2.2 model checkpoint files because:
- Model files are very large (14B-27B parameters = 20-50GB per model)
- Including them in the Docker image would make build and deployment impractical
- Models should be managed separately from application code

## Where to Get Models

Download models from:
- 🤗 [Hugging Face](https://huggingface.co/Wan-AI/)
- 🤖 [ModelScope](https://modelscope.cn/organization/Wan-AI)

Available models:
- **TI2V-5B** (~10GB) - Recommended for API deployment
- **T2V-A14B** (~30GB) - High quality text-to-video
- **I2V-A14B** (~30GB) - High quality image-to-video
- **S2V-14B** (~30GB) - Speech-to-video
- **Animate-14B** (~30GB) - Character animation

## How to Use Models with Deployment

### Option 1: Azure Files Mount (Recommended for Production)

1. **Create Azure Files Share**
   ```bash
   # Create storage account
   az storage account create \
     --name wanmodelstorage \
     --resource-group wan-video-api-rg \
     --location eastus \
     --sku Standard_LRS

   # Create file share
   az storage share create \
     --name models \
     --account-name wanmodelstorage \
     --quota 100
   ```

2. **Upload Models**
   ```bash
   # Get storage key
   STORAGE_KEY=$(az storage account keys list \
     --account-name wanmodelstorage \
     --resource-group wan-video-api-rg \
     --query "[0].value" -o tsv)

   # Upload models (using Azure Portal or azcopy is easier for large files)
   az storage file upload-batch \
     --destination models \
     --source ./local-models \
     --account-name wanmodelstorage \
     --account-key $STORAGE_KEY
   ```

3. **Mount to Container App**
   
   Update `infra/container-app.bicep` to add volume mount:
   ```bicep
   // Add to container app template
   volumes: [
     {
       name: 'models-volume'
       storageType: 'AzureFile'
       storageName: 'models'
     }
   ]
   
   // Add to container
   volumeMounts: [
     {
       volumeName: 'models-volume'
       mountPath: '/app/models'
     }
   ]
   ```

4. **Redeploy**
   ```bash
   ./deploy.sh
   ```

### Option 2: Build Custom Image with Models (Development/Testing)

⚠️ Not recommended for production due to large image size and long build times

1. **Download models locally**
   ```bash
   mkdir models
   huggingface-cli download Wan-AI/Wan2.2-TI2V-5B --local-dir ./models/Wan2.2-TI2V-5B
   ```

2. **Update Dockerfile**
   ```dockerfile
   # Add before CMD
   COPY models/ /app/models/
   ```

3. **Update .dockerignore**
   Remove or comment out the models line:
   ```
   # models/  # COMMENTED OUT - now including models in image
   ```

4. **Build and deploy**
   ```bash
   ./deploy.sh
   ```

   ⚠️ Warning: Build will take much longer and push will be slow (50GB+ image)

### Option 3: Download on First Run (Not Recommended)

Modify the API to download models on first startup:
- Adds significant startup time (10-30 minutes)
- May cause health check timeouts
- Wastes bandwidth on each deployment

## Testing Without Models

You can test the API structure without models:

```bash
# Build test image
docker build -f Dockerfile.test -t wan-api-test .

# Run without GPU
docker run -p 8000:8000 wan-api-test

# Test endpoints (generation will fail without models)
curl http://localhost:8000/health     # ✓ Works
curl http://localhost:8000/tasks      # ✓ Works
curl http://localhost:8000/           # ✓ Works
```

## Recommended Setup for Production

1. **Use Azure Files or Blob Storage** for models
2. **Mount as read-only volume** to Container App
3. **Set MODEL_PATH** environment variable to mount point
4. **Use TI2V-5B model** for best performance/cost ratio
5. **Pre-download models** before going live

## Storage Costs

Storing models in Azure:
- **Azure Files (Standard)**: ~$0.06/GB/month
- **Azure Blob (Hot)**: ~$0.018/GB/month
- **For 50GB of models**: ~$1-3/month

Much cheaper than including in Docker image!

## FAQ

**Q: Can I use models from Hugging Face directly in the API?**
A: Not recommended. Download once and store in Azure for better performance.

**Q: Which model should I use for production?**
A: TI2V-5B - it's the most efficient, supports both T2V and I2V, runs on single GPU.

**Q: Do I need all models?**
A: No! Start with TI2V-5B. Add others only if you need specific features.

**Q: Can I use my own fine-tuned models?**
A: Yes! Follow the same mounting process with your model files.

**Q: How do I update models?**
A: Upload new models to Azure Files/Blob, restart Container App. No rebuild needed!

## Next Steps

1. Choose your model deployment strategy
2. Download required models
3. Set up Azure storage (if using Option 1)
4. Configure model paths in deployment
5. Test video generation

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions on each option.
