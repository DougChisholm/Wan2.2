#!/bin/bash
set -e

echo "Starting Wan 2.2 API container..."

# Download models if they don't exist
if [ ! -d "/app/models/Wan2.2-TI2V-5B" ] && [ "$MODEL_TYPE" = "ti2v-5B" ]; then
    echo "Models not found. Downloading..."
    python download_models.py
else
    echo "Models already present, skipping download"
fi

# Start the API server
echo "Starting API server..."
exec python api.py
