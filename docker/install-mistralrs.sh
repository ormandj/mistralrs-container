#!/bin/bash
# Build mistral.rs from source and install binaries to /install
set -euo pipefail

MISTRALRS_REF="${1:-master}"
MISTRALRS_REPO="https://github.com/EricLBuehler/mistral.rs.git"
WITH_FEATURES="${WITH_FEATURES:-cuda,cudnn,flash-attn,nccl}"
CUDA_COMPUTE_CAP="${CUDA_COMPUTE_CAP:-86}"

echo "=== Building mistral.rs ==="
echo "  ref:      ${MISTRALRS_REF}"
echo "  features: ${WITH_FEATURES}"
echo "  compute:  sm_${CUDA_COMPUTE_CAP}"

cd /build
git clone "${MISTRALRS_REPO}" src
cd src

# Try checkout as tag, branch, or commit
git checkout "${MISTRALRS_REF}" 2>/dev/null || \
git checkout "v${MISTRALRS_REF}" 2>/dev/null || \
true

COMMIT_HASH=$(git rev-parse --short HEAD)
VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "  version:  ${VERSION} (${COMMIT_HASH})"

export CUDA_COMPUTE_CAP
cargo build --release --workspace --exclude mistralrs-pyo3 --features "${WITH_FEATURES}"

echo "=== Installing binaries ==="
mkdir -p /install/bin
cp target/release/mistralrs /install/bin/
cp target/release/mistralrs-server /install/bin/
cp target/release/mistralrs-bench /install/bin/
cp target/release/mistralrs-web-chat /install/bin/
cp -r chat_templates /install/
echo "${VERSION} (${COMMIT_HASH})" > /install/mistralrs-version

ls -lh /install/bin/
echo "=== Build complete ==="
