# kgpu-images

Container images for [kgpu.net](https://kgpu.net) — pulled by the
lab's K3s cluster into rented GPU pods.

The gateway source (FastAPI, K8s glue, R2 client, web dashboard) lives
in a separate private repo. **This repo is the artifact side only**:
Dockerfiles, helper scripts, and the GH Actions workflow that publishes
to `ghcr.io/vitaldb/...`.

## Published images

| Image | Built from | Use |
|---|---|---|
| `ghcr.io/vitaldb/kgpu-pytorch:latest` | [kgpu-pytorch.Dockerfile](kgpu-pytorch.Dockerfile) | NGC PyTorch 24.10-py3 + rclone + fuse3 + duckdb + pyarrow, with `kgpu-mount-shared` helper |

Pull is anonymous (the repo is public, so the package inherits public
visibility).

## Renting with one of these images

```bash
curl -X POST -H "Authorization: Bearer $KGPU_API_TOKEN" \
  -H "Content-Type: application/json" \
  https://api.kgpu.net/v1/gpus \
  -d '{"name":"exp","image":"ghcr.io/vitaldb/kgpu-pytorch:latest"}'
```

Inside the pod:

```bash
kgpu-mount-shared             # mounts /shared via rclone HTTP
ls /shared/datasets/ecg/
```

## Building locally (rare)

Workflow does this on every push that touches a tracked path. If you
need to iterate locally:

```bash
docker buildx build --platform linux/arm64 \
  -t ghcr.io/vitaldb/kgpu-pytorch:dev \
  -f kgpu-pytorch.Dockerfile .
```

(arm64 because GB10 is arm64.)
