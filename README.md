# mistralrs-container

Container build for [mistral.rs](https://github.com/EricLBuehler/mistral.rs) with CUDA, flash-attn, and NCCL tensor parallelism.

The upstream project doesn't ship images with flash-attn or NCCL enabled, so we build our own.

## Quick Start

```bash
# Build (requires amd64 machine or builder with CUDA — see below)
cd docker
MISTRALRS_REF=main ./build-image.sh

# Push
docker push ghcr.io/ormandj/mistralrs:cuda86-<hash>
```

## What's Included

| Binary | Description |
|---|---|
| `mistralrs` | CLI (run, serve, bench, from-config) |
| `mistralrs-server` | HTTP server (OpenAI-compatible API) |
| `mistralrs-bench` | Benchmarking tool |
| `mistralrs-web-chat` | Web UI chat interface |

Compiled features: `cuda`, `cudnn`, `flash-attn`, `nccl`

## Build Options

| Variable | Default | Description |
|---|---|---|
| `MISTRALRS_REF` | `main` | Git ref (tag, branch, commit hash) |
| `CUDA_COMPUTE_CAP` | `86` | Target GPU (86=RTX 3090, 89=RTX 4090, 90=H100) |
| `CUDA_VERSION` | `13.2.0` | CUDA toolkit version |
| `WITH_FEATURES` | `cuda,cudnn,flash-attn,nccl` | Cargo features |
| `DOCKER_IMAGE_TAG` | auto-generated | Override output tag |

## Building on ARM Mac

Cross-compiling CUDA kernels under QEMU requires enormous memory (>48GB) and will
likely fail for flash-attn. Build natively on amd64 instead:

- **On-cluster build pod**: See `homelab/kubernetes/quasar/apps/mistralrs/build-pod.yaml`
- **GitHub Actions CI**: Push to this repo and trigger the workflow

## NCCL Tensor Parallelism

NCCL TP auto-enables with multiple GPUs. **World size must be a power of 2** (2, 4, 8).

- 2 GPUs: works
- 3 GPUs: does NOT work — set `MISTRALRS_NO_NCCL=1` for layer-based device mapping
- 4 GPUs: works

## CI

GitHub Actions builds weekly (Monday 6am UTC) and on manual dispatch.
Images pushed to `ghcr.io/ormandj/mistralrs:cuda86-latest` and date-tagged.
