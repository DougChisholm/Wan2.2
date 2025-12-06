#!/usr/bin/env python3
"""
Download Wan 2.2 model weights from Hugging Face
"""
import os
import sys
from pathlib import Path
from huggingface_hub import snapshot_download

# Model configurations
MODELS = {
    "ti2v-5B": "Wan2.2-TI2V-5B",
    "t2v-A14B": "Wan2.2-T2V-A14B", 
    "i2v-A14B": "Wan2.2-I2V-A14B"
}

def download_model(model_type, output_dir="/app/models"):
    """Download model from Hugging Face"""
    if model_type not in MODELS:
        print(f"Error: Unknown model type {model_type}")
        sys.exit(1)
    
    model_name = MODELS[model_type]
    model_path = Path(output_dir) / model_name
    
    # Check if model already exists
    if model_path.exists():
        print(f"Model {model_name} already exists at {model_path}")
        return
    
    print(f"Downloading {model_name} to {model_path}...")
    
    try:
        # Download from Hugging Face
        # Replace with actual Hugging Face repo path
        repo_id = f"Alibaba-PAI/{model_name}"
        
        snapshot_download(
            repo_id=repo_id,
            local_dir=str(model_path),
            local_dir_use_symlinks=False,
            resume_download=True
        )
        
        print(f"Successfully downloaded {model_name}")
        
    except Exception as e:
        print(f"Error downloading model: {e}")
        print(f"Please ensure the model is available at: {repo_id}")
        sys.exit(1)

if __name__ == "__main__":
    # Get model type from environment variable
    model_type = os.getenv("MODEL_TYPE", "ti2v-5B")
    output_dir = os.getenv("MODEL_PATH", "/app/models")
    
    print(f"Starting model download for: {model_type}")
    download_model(model_type, output_dir)
    print("Model download complete!")
