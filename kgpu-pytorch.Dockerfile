# kgpu-pytorch — PyTorch base with rclone+fuse pre-installed so users
# can mount the lab shared drive at /shared without extra setup.
#
# Built automatically by .github/workflows/build-base-image.yml on any
# push that touches this file. Published to:
#   ghcr.io/vitaldb/kgpu-pytorch:24.10-py3
#   ghcr.io/vitaldb/kgpu-pytorch:latest
#
# Rent with:
#   POST /v1/gpus  {"name":"exp","image":"ghcr.io/vitaldb/kgpu-pytorch:latest"}

FROM nvcr.io/nvidia/pytorch:24.10-py3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        fuse3 \
        ca-certificates \
        curl \
        unzip \
        zstd \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    # Pin numpy<2 explicitly: torch 2.5 (nv24.10) in this base image
    # was compiled against numpy 1.x and aborts at import time on 2.x
    # ("A module compiled using NumPy 1.x cannot be run in NumPy 2.2.6").
    # Without this pin, `pip install duckdb pyarrow` (or any later
    # `pip install` by the user) drags in numpy 2.x and breaks torch /
    # wfdb / scipy on the first import — caught in alpha v2 review.
    # Drop this pin only when we rebase on a pytorch image whose torch
    # build supports numpy 2.x.
    && pip install --no-cache-dir 'numpy<2' duckdb pyarrow \
    && rm -rf /var/lib/apt/lists/*

# Mount helpers — `kgpu-mount-shared [/path]` for the read-only HTTP
# mount of the shared drive, `kgpu-mount-files [/path]` for the WebDAV
# read+write mount of mydrive (shared/ subdir is RO inside it).
# kgpu-bootstrap runs both at pod start, then idles — used as the pod's
# main process by the gateway manifest so /shared + /files are present
# the moment the rental becomes Ready.
COPY kgpu-mount-shared /usr/local/bin/kgpu-mount-shared
COPY kgpu-mount-files  /usr/local/bin/kgpu-mount-files
COPY kgpu-bootstrap    /usr/local/bin/kgpu-bootstrap
RUN chmod +x /usr/local/bin/kgpu-mount-shared /usr/local/bin/kgpu-mount-files /usr/local/bin/kgpu-bootstrap

LABEL org.opencontainers.image.source="https://github.com/vitaldb/kgpu-images"
LABEL org.opencontainers.image.description="kgpu.net — PyTorch + rclone + fuse + duckdb base image (arm64 / GB10)"
LABEL org.opencontainers.image.licenses="MIT"
