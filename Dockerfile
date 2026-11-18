# Use your custom CUDA 13.0 + Python 3.12 base image
FROM vishva123/nvidia-cuda-13.0-cudnn-devel-ubuntu24.04-python-3.12

# Environment configuration
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    VLLM_USE_PRECOMPILED=1 \
    UV_TORCH_BACKEND=cu130 \
    VIRTUAL_ENV=/workspace/.venv \
    PATH="/workspace/.venv/bin:${PATH}"

# Install core build and system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ninja-build \
    build-essential \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Set working directory
WORKDIR /workspace

# Step 1: Create virtual environment
RUN uv venv /workspace/.venv --python python3.12

# Step 2: Install required packaging and build dependencies
RUN uv pip install setuptools-scm setuptools_rust wheel ninja

# Step 3: Clone your rebased feature branch
RUN git clone --depth 1 -b feat/systemone-generative-box https://github.com/vishvaRam/vllm.git /workspace/vllm

# Step 4: Install compatible cu130 PyTorch, relax torch* pins in cuda.txt, and install vLLM
WORKDIR /workspace/vllm
RUN sed -i '/^torchaudio/d; s/^torchvision==.*/torchvision/' requirements/cuda.txt && \
    VLLM_USE_PRECOMPILED=1 uv pip install --editable .

# Step 5: Verify installation points to the cloned repository and CUDA PyTorch is loaded
WORKDIR /workspace
RUN python3 -c "import torch, vllm; print('Torch:', torch.__version__, 'CUDA:', torch.version.cuda); print('Loaded vllm path:', vllm.__file__)"

# Expose default API server port
EXPOSE 8000

# Step 6: Official entrypoint configured for "vllm serve"
ENTRYPOINT ["vllm", "serve"]
