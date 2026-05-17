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
| `ghcr.io/vitaldb/kgpu-pytorch:latest` | [kgpu-pytorch.Dockerfile](kgpu-pytorch.Dockerfile) | NGC PyTorch 24.10-py3 + rclone + fuse3 + duckdb + pyarrow + uv + zstd, with `kgpu-mount-shared` (RO) and `kgpu-mount-files` (RW WebDAV) helpers |

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
kgpu-mount-shared             # /shared  (rclone HTTP, read-only)
kgpu-mount-files              # /files   (rclone WebDAV, mydrive RW + shared/ RO subdir)
ls /shared/datasets/ecg/
echo hi > /files/scratch.txt  # writes through to your R2 prefix
```

Don't drive your training loop's I/O through `/files` — see the
[AGENTS.md "Filesystem write hygiene"](https://api.kgpu.net/AGENTS.md)
section. Train on `/workspace` (ephemeral local), upload outputs as a
single tar at the end.

## Building locally (rare)

Workflow does this on every push that touches a tracked path. If you
need to iterate locally:

```bash
docker buildx build --platform linux/arm64 \
  -t ghcr.io/vitaldb/kgpu-pytorch:dev \
  -f kgpu-pytorch.Dockerfile .
```

(arm64 because GB10 is arm64.)
