#!/usr/bin/env python3
"""
FastAPI REST API for Wan 2.2 Video Generation Model
Provides endpoints for text-to-video and image-to-video generation
"""
import io
import logging
import os
import random
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Optional

import torch
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse
from PIL import Image

import wan
from wan.configs import MAX_AREA_CONFIGS, SIZE_CONFIGS, WAN_CONFIGS
from wan.utils.utils import save_video

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    handlers=[logging.StreamHandler(stream=sys.stdout)]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Wan 2.2 Video Generation API",
    description="API for generating videos from text prompts and images using Wan 2.2 models",
    version="1.0.0"
)

# Global variables for model configuration
MODEL_TYPE = os.getenv("MODEL_TYPE", "ti2v-5B")  # Default to TI2V-5B (most efficient)
MODEL_PATH = os.getenv("MODEL_PATH", "./models")
DEVICE_ID = int(os.getenv("DEVICE_ID", "0"))
OUTPUT_DIR = Path(os.getenv("OUTPUT_DIR", "/tmp/outputs"))
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Model cache
_model_cache = {}


def get_model(task: str):
    """Get or initialize the model for a given task"""
    if task not in _model_cache:
        logger.info(f"Initializing model for task: {task}")
        
        if task not in WAN_CONFIGS:
            raise ValueError(f"Unsupported task: {task}")
        
        cfg = WAN_CONFIGS[task]
        checkpoint_dir = os.path.join(MODEL_PATH, f"Wan2.2-{task.upper()}")
        
        if not os.path.exists(checkpoint_dir):
            raise FileNotFoundError(f"Model checkpoint not found at {checkpoint_dir}")
        
        # Initialize appropriate model based on task
        if "t2v" in task:
            model = wan.WanT2V(
                config=cfg,
                checkpoint_dir=checkpoint_dir,
                device_id=DEVICE_ID,
                rank=0,
                t5_fsdp=False,
                dit_fsdp=False,
                use_sp=False,
                t5_cpu=False,
                convert_model_dtype=True,
            )
        elif "ti2v" in task:
            model = wan.WanTI2V(
                config=cfg,
                checkpoint_dir=checkpoint_dir,
                device_id=DEVICE_ID,
                rank=0,
                t5_fsdp=False,
                dit_fsdp=False,
                use_sp=False,
                t5_cpu=True,  # Use CPU for T5 to save GPU memory
                convert_model_dtype=True,
            )
        elif "i2v" in task:
            model = wan.WanI2V(
                config=cfg,
                checkpoint_dir=checkpoint_dir,
                device_id=DEVICE_ID,
                rank=0,
                t5_fsdp=False,
                dit_fsdp=False,
                use_sp=False,
                t5_cpu=False,
                convert_model_dtype=True,
            )
        else:
            raise ValueError(f"Unsupported task type: {task}")
        
        _model_cache[task] = model
        logger.info(f"Model initialized successfully for task: {task}")
    
    return _model_cache[task]


@app.get("/")
async def root():
    """Root endpoint - API health check"""
    return {
        "status": "healthy",
        "message": "Wan 2.2 Video Generation API",
        "model_type": MODEL_TYPE,
        "available_tasks": list(WAN_CONFIGS.keys())
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.post("/generate")
async def generate_video(
    prompt: str = Form(..., description="Text prompt for video generation"),
    image: Optional[UploadFile] = File(None, description="Optional input image for image-to-video generation"),
    task: str = Form(MODEL_TYPE, description="Model task type (t2v-A14B, i2v-A14B, ti2v-5B)"),
    size: str = Form("1280*704", description="Video size (width*height)"),
    frame_num: Optional[int] = Form(None, description="Number of frames to generate"),
    seed: int = Form(-1, description="Random seed for generation"),
    sample_steps: Optional[int] = Form(None, description="Number of sampling steps"),
    guide_scale: Optional[float] = Form(None, description="Guidance scale"),
):
    """
    Generate a video from a text prompt and optional image
    
    Args:
        prompt: Text description for the video
        image: Optional image file for image-to-video generation
        task: Model task type (t2v-A14B, i2v-A14B, ti2v-5B)
        size: Video resolution (e.g., "1280*704")
        frame_num: Number of frames (default from config)
        seed: Random seed (-1 for random)
        sample_steps: Sampling steps (default from config)
        guide_scale: Guidance scale (default from config)
    
    Returns:
        Generated video file
    """
    try:
        # Validate task
        if task not in WAN_CONFIGS:
            raise HTTPException(status_code=400, detail=f"Unsupported task: {task}")
        
        # Validate size
        if size not in SIZE_CONFIGS:
            raise HTTPException(status_code=400, detail=f"Unsupported size: {size}")
        
        cfg = WAN_CONFIGS[task]
        
        # Set defaults from config
        if sample_steps is None:
            sample_steps = cfg.sample_steps
        if guide_scale is None:
            guide_scale = cfg.sample_guide_scale
        if frame_num is None:
            frame_num = cfg.frame_num
        
        # Handle seed
        if seed < 0:
            seed = random.randint(0, sys.maxsize)
        
        # Process input image if provided
        img = None
        if image is not None:
            image_data = await image.read()
            img = Image.open(io.BytesIO(image_data)).convert("RGB")
            logger.info(f"Loaded input image: {image.filename}")
        
        # Get model
        model = get_model(task)
        
        # Generate video
        logger.info(f"Generating video with task={task}, prompt='{prompt[:50]}...', size={size}")
        
        if "t2v" in task:
            video = model.generate(
                prompt,
                size=SIZE_CONFIGS[size],
                frame_num=frame_num,
                shift=cfg.sample_shift,
                sample_solver='unipc',
                sampling_steps=sample_steps,
                guide_scale=guide_scale,
                seed=seed,
                offload_model=True
            )
        elif "ti2v" in task:
            video = model.generate(
                prompt,
                img=img,
                size=SIZE_CONFIGS[size],
                max_area=MAX_AREA_CONFIGS[size],
                frame_num=frame_num,
                shift=cfg.sample_shift,
                sample_solver='unipc',
                sampling_steps=sample_steps,
                guide_scale=guide_scale,
                seed=seed,
                offload_model=True
            )
        elif "i2v" in task:
            if img is None:
                raise HTTPException(status_code=400, detail="Image is required for i2v task")
            video = model.generate(
                prompt,
                img,
                max_area=MAX_AREA_CONFIGS[size],
                frame_num=frame_num,
                shift=cfg.sample_shift,
                sample_solver='unipc',
                sampling_steps=sample_steps,
                guide_scale=guide_scale,
                seed=seed,
                offload_model=True
            )
        else:
            raise HTTPException(status_code=400, detail=f"Unsupported task type: {task}")
        
        # Save video to temporary file
        video_id = str(uuid.uuid4())
        output_path = OUTPUT_DIR / f"{video_id}.mp4"
        
        save_video(
            tensor=video[None],
            save_file=str(output_path),
            fps=cfg.sample_fps,
            nrow=1,
            normalize=True,
            value_range=(-1, 1)
        )
        
        logger.info(f"Video generated successfully: {output_path}")
        
        # Clean up
        del video
        torch.cuda.empty_cache()
        
        # Return video file
        return FileResponse(
            path=output_path,
            media_type="video/mp4",
            filename=f"wan_video_{video_id}.mp4"
        )
    
    except Exception as e:
        logger.error(f"Error generating video: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Video generation failed: {str(e)}")


@app.get("/tasks")
async def list_tasks():
    """List available model tasks"""
    return {
        "available_tasks": list(WAN_CONFIGS.keys()),
        "current_task": MODEL_TYPE
    }


@app.get("/sizes/{task}")
async def list_sizes(task: str):
    """List supported sizes for a given task"""
    from wan.configs import SUPPORTED_SIZES
    
    if task not in SUPPORTED_SIZES:
        raise HTTPException(status_code=400, detail=f"Unknown task: {task}")
    
    return {
        "task": task,
        "supported_sizes": SUPPORTED_SIZES[task]
    }


if __name__ == "__main__":
    import uvicorn
    
    # Get port from environment or default to 8000
    port = int(os.getenv("PORT", "8000"))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info(f"Starting Wan 2.2 API server on {host}:{port}")
    uvicorn.run(app, host=host, port=port)
