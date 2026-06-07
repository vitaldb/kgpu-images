# kgpu-pytorch — PyTorch base with rclone+fuse pre-installed so users
# can mount the lab shared drive at /shared without extra setup.
#
# Built automatically by .github/workflows/build-base-image.yml on any
# push that touches this file. Published to:
#   ghcr.io/vitaldb/kgpu-pytorch:25.05-py3
#   ghcr.io/vitaldb/kgpu-pytorch:latest
#
# Rent with:
#   POST /v1/gpus  {"name":"exp","image":"ghcr.io/vitaldb/kgpu-pytorch:latest"}
#
# Base bumped 2026-06-07: 24.10-py3 (torch 2.5.0a0, CUDA 12.6, arch list
# sm_70..sm_90+compute_90) → 25.05-py3 (torch 2.8.0a0, CUDA 12.9.0,
# Blackwell sm_100/sm_120 prebuilt). The 24.10 base ran rtx5090 only via
# PTX JIT from compute_90 — 0% GPU util for minutes during warmup
# (alpha report 2026-06-07). 25.05 ships sm_120 kernels prebuilt, so
# rtx5090 / B200 launch immediately.

FROM nvcr.io/nvidia/pytorch:25.05-py3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        fuse3 \
        ca-certificates \
        curl \
        unzip \
        zstd \
        # iproute2 ships `ip` and `ss` — basic netutils that almost
        # every network debug session needs. The base nvidia/pytorch
        # image ships neither, so alpha users hit "ip: command not
        # found" the first time their pip install times out and they
        # try to diagnose. Add ~3 MiB to the image so the common case
        # works without `apt install` from inside the rental.
        # Alpha 2026-05-27 reconfirmed.
        iproute2 \
        # openssh-sftp-server ships /usr/lib/openssh/sftp-server, the
        # binary the kgpu bastion execs into the pod when a user mounts
        # the workspace via sshfs (`sshfs ... -o
        # sftp_server=/usr/lib/openssh/sftp-server`). Adds ~600 KiB but
        # removes the only blocker for live local-folder editing.
        openssh-sftp-server \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    # numpy<2 pin dropped 2026-06-07 with the 25.05 base bump — torch
    # 2.8 (nv25.05) is built against numpy 2.x ABI, and the rest of
    # the preinstalled scientific stack (scipy, sklearn, pandas, wfdb,
    # vitaldb) all ship numpy-2-compatible wheels at current
    # major versions. If a future user `pip install`s something that
    # drags numpy back to 1.x, that's their breakage to resolve.
    #
    # Pre-install the common scientific stack so the user's
    # `pip install ...` for any of these is a no-op ("Requirement
    # already satisfied") rather than a version-resolution round.
    # Picked by SNUH research workload survey — wfdb (PhysioNet readers),
    # vitaldb (lab's own SDK for .vital files), scipy/sklearn (signal +
    # ML), pandas (tabular), matplotlib (most plots), seaborn (stats
    # plots). Drop / extend as the workload shifts.
    && pip install --no-cache-dir \
         duckdb pyarrow \
         scipy scikit-learn pandas matplotlib seaborn \
         wfdb vitaldb \
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
