# labgpu-pytorch — PyTorch base with rclone+fuse pre-installed so users
# can mount the lab shared drive at /shared without extra setup.
#
# Built automatically by .github/workflows/build-base-image.yml on any
# push that touches this file. Published to:
#   ghcr.io/vitaldb/labgpu-pytorch:24.10-py3
#   ghcr.io/vitaldb/labgpu-pytorch:latest
#
# Rent with:
#   POST /v1/gpus  {"name":"exp","image":"ghcr.io/vitaldb/labgpu-pytorch:latest"}

FROM nvcr.io/nvidia/pytorch:24.10-py3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        fuse3 \
        ca-certificates \
        curl \
        unzip \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && pip install --no-cache-dir duckdb pyarrow \
    && rm -rf /var/lib/apt/lists/*

# Convenience wrapper — `lgpu-mount-shared [/mount/path]` runs the
# canonical rclone HTTP mount against $LABGPU_API_BASE/v1/files/shared/
# with the auto-injected Bearer token.
COPY lgpu-mount-shared /usr/local/bin/lgpu-mount-shared
RUN chmod +x /usr/local/bin/lgpu-mount-shared

LABEL org.opencontainers.image.source="https://github.com/vitaldb/labgpu-images"
LABEL org.opencontainers.image.description="labgpu.com — PyTorch + rclone + fuse + duckdb base image (arm64 / GB10)"
LABEL org.opencontainers.image.licenses="MIT"
