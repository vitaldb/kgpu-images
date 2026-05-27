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
        # iproute2 ships `ip` and `ss` — basic netutils that almost
        # every network debug session needs. The base nvidia/pytorch
        # image ships neither, so alpha users hit "ip: command not
        # found" the first time their pip install times out and they
        # try to diagnose. Add ~3 MiB to the image so the common case
        # works without `apt install` from inside the rental.
        # Alpha 2026-05-27 reconfirmed.
        iproute2 \
        # openssh-server — kgpu v2 마이그레이션 (NO_K3S_PLAN.md) 의
        # per-port relay 모델에서 컨테이너가 SSH 종단을 직접 한다.
        # 기존 k3s 모드 (kubectl exec) 에서는 sshd 가 실행되지 않으므로
        # (kgpu-sshd-entrypoint 의 KGPU_AUTHORIZED_KEY 분기) 비파괴적.
        # apt postinst 가 host key 자동 생성.
        openssh-server \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    # Pin numpy<2 system-wide via a pip constraint file. Reason:
    # torch 2.5 (nv24.10) in this base image was compiled against
    # numpy 1.x and aborts at import time on 2.x:
    #   "A module compiled using NumPy 1.x cannot be run in NumPy 2.2.6"
    # A single `pip install 'numpy<2' ...` at build time is *not*
    # enough — alpha v4 caught the regression when the user ran
    # `pip install wfdb` later inside the rental: wfdb's deps
    # transitively dragged numpy back to 2.2.6 and torch broke. With
    # a global constraint file pip respects `numpy<2` on every install
    # the user runs, so wfdb / scipy / sklearn etc. all resolve to
    # numpy-1.x-compatible releases automatically.
    # Drop both the pin and the constraint when we rebase on a pytorch
    # image whose torch build supports numpy 2.x.
    && printf 'numpy<2\n' > /etc/pip-constraints.txt \
    && printf '[global]\nconstraint = /etc/pip-constraints.txt\n' > /etc/pip.conf \
    # Pre-install the common scientific stack alongside numpy<2 so the
    # user's `pip install ...` for any of these is a no-op
    # ("Requirement already satisfied") rather than a version-resolution
    # round that might fight the pin or pull a transitive numpy 2.x.
    # Picked by SNUH research workload survey — wfdb (PhysioNet readers),
    # vitaldb (lab's own SDK for .vital files), scipy/sklearn (signal +
    # ML), pandas (tabular), matplotlib (most plots), seaborn (stats
    # plots). Drop / extend as the workload shifts.
    && pip install --no-cache-dir \
         'numpy<2' \
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
COPY kgpu-mount-shared    /usr/local/bin/kgpu-mount-shared
COPY kgpu-mount-files     /usr/local/bin/kgpu-mount-files
COPY kgpu-bootstrap       /usr/local/bin/kgpu-bootstrap
# kgpu v2 마이그레이션 (NO_K3S_PLAN.md) 의 새 ENTRYPOINT.
# KGPU_AUTHORIZED_KEY env 가 set 되면 sshd -D -p 2222 를 exec.
# 안 set 이면 sleep infinity → 기존 k3s 모드 호환.
# k8s pod spec 의 `command: ["sleep","infinity"]` 가 ENTRYPOINT 를
# override 하므로 현재 운영에 무영향.
COPY kgpu-sshd-entrypoint /usr/local/bin/kgpu-sshd-entrypoint
RUN chmod +x /usr/local/bin/kgpu-mount-shared /usr/local/bin/kgpu-mount-files \
             /usr/local/bin/kgpu-bootstrap /usr/local/bin/kgpu-sshd-entrypoint

# sshd 가 --cap-drop ALL + --security-opt no-new-privileges 환경에서
# 안정적으로 동작하려면 PAM/DNS 가 비활성화돼야 한다. PAM 의 일부
# 모듈이 setuid 를 시도하다 ENPRIV 로 실패하면 로그인 자체가 깨짐.
# Port 2222 는 unprivileged → CAP_NET_BIND_SERVICE 불필요.
RUN mkdir -p /etc/ssh/sshd_config.d \
 && printf '%s\n' \
        '# Installed by kgpu-pytorch Dockerfile — see NO_K3S_PLAN.md' \
        'Port 2222' \
        'PermitRootLogin prohibit-password' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        'UsePAM no' \
        'UseDNS no' \
        'PrintMotd no' \
        'AcceptEnv LANG LC_*' \
        > /etc/ssh/sshd_config.d/kgpu.conf
# `Subsystem sftp ...` 는 main sshd_config 에 이미 정의돼 있다 — drop-in
# 에 또 쓰면 sshd 8.x+ 가 "Subsystem 'sftp' already defined." 로 fatal
# (exit 255). main 에서 그대로 받음.

ENTRYPOINT ["/usr/local/bin/kgpu-sshd-entrypoint"]

LABEL org.opencontainers.image.source="https://github.com/vitaldb/kgpu-images"
LABEL org.opencontainers.image.description="kgpu.net — PyTorch + rclone + fuse + duckdb base image (arm64 / GB10)"
LABEL org.opencontainers.image.licenses="MIT"
