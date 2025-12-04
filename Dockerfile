# Use NVIDIA CUDA base image with Ubuntu
FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    git \
    wget \
    curl \
    ffmpeg \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.10 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Set working directory
WORKDIR /app

# Copy requirements files
COPY requirements.txt requirements_api.txt ./

# Install PyTorch with CUDA support first
RUN pip install --no-cache-dir torch==2.4.0 torchvision==0.19.0 torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install flash-attn (may take a while to build)
RUN pip install --no-cache-dir flash-attn --no-build-isolation

# Install remaining requirements
RUN pip install --no-cache-dir -r requirements_api.txt

# Copy application code
COPY . .

# Create output directory
RUN mkdir -p /tmp/outputs

# Expose API port
EXPOSE 8000

# Set environment variables for the API
ENV MODEL_TYPE=ti2v-5B
ENV MODEL_PATH=/app/models
ENV DEVICE_ID=0
ENV OUTPUT_DIR=/tmp/outputs
ENV HOST=0.0.0.0
ENV PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run the API server
CMD ["python", "api.py"]
