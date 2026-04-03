#!/bin/bash
#
# Build mistral.rs container image with version pinning
#
# Usage:
#   ./build-image.sh                                    # Build with defaults (latest master)
#   ./build-image.sh --no-cache                         # Build without cache
#   MISTRALRS_REF=v0.8.1 ./build-image.sh              # Pin to a tag
#   MISTRALRS_REF=master ./build-image.sh               # Pin to branch
#   CUDA_COMPUTE_CAP=89 ./build-image.sh                # Target different GPU (Ada)
#
# Environment variables:
#   MISTRALRS_REF         mistral.rs commit/tag/branch (default: master)
#   CUDA_COMPUTE_CAP      CUDA compute capability (default: 86)
#   CUDA_VERSION          CUDA toolkit version (default: 13.2.0)
#   DOCKER_IMAGE_TAG      Override image tag
#   WITH_FEATURES         Override cargo features

set -euo pipefail

NO_CACHE=false
for arg in "$@"; do
    case $arg in
        --no-cache) NO_CACHE=true ;;
        --help|-h)
            echo "Usage: ./build-image.sh [--no-cache]"
            echo ""
            echo "Environment variables:"
            echo "  MISTRALRS_REF      Pin mistral.rs to commit/tag/branch (default: master)"
            echo "  CUDA_COMPUTE_CAP   Target GPU compute capability (default: 86)"
            echo "  CUDA_VERSION       CUDA toolkit version (default: 13.2.0)"
            echo "  DOCKER_IMAGE_TAG   Override output image tag"
            echo "  WITH_FEATURES      Override cargo features (default: cuda,cudnn,flash-attn,nccl)"
            exit 0
            ;;
    esac
done

MISTRALRS_REPO="https://github.com/EricLBuehler/mistral.rs.git"
MISTRALRS_REF="${MISTRALRS_REF:-master}"
CUDA_COMPUTE_CAP="${CUDA_COMPUTE_CAP:-86}"
CUDA_VERSION="${CUDA_VERSION:-13.2.0}"
WITH_FEATURES="${WITH_FEATURES:-cuda,cudnn,flash-attn,nccl}"

# Resolve ref to commit hash
resolve_ref() {
    local repo_url="$1" ref="$2"
    if [[ "${ref}" =~ ^[0-9a-f]{40}$ ]]; then
        echo "${ref}"; return
    fi
    local hash
    hash=$(git ls-remote "${repo_url}" "refs/tags/${ref}" "refs/heads/${ref}" 2>/dev/null | head -1 | cut -f1)
    if [[ -n "${hash}" ]]; then
        echo "${hash}"; return
    fi
    # Try with v prefix for tags
    hash=$(git ls-remote "${repo_url}" "refs/tags/v${ref}" 2>/dev/null | head -1 | cut -f1)
    if [[ -n "${hash}" ]]; then
        echo "${hash}"; return
    fi
    echo "ERROR: Could not resolve ref '${ref}' for ${repo_url}" >&2
    return 1
}

echo "=========================================="
echo "mistral.rs Container Build"
echo "=========================================="
echo ""

MISTRALRS_HASH=$(resolve_ref "${MISTRALRS_REPO}" "${MISTRALRS_REF}") || exit 1
echo "mistral.rs: ${MISTRALRS_REF} -> ${MISTRALRS_HASH:0:12}"
echo "CUDA:       ${CUDA_VERSION} (sm_${CUDA_COMPUTE_CAP})"
echo "Features:   ${WITH_FEATURES}"

SHORT_HASH="${MISTRALRS_HASH:0:7}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-ghcr.io/ormandj/mistralrs:cuda${CUDA_COMPUTE_CAP}-${SHORT_HASH}}"

echo "Image tag:  ${DOCKER_IMAGE_TAG}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BUILD_ARGS=(
    --build-arg "CUDA_COMPUTE_CAP=${CUDA_COMPUTE_CAP}"
    --build-arg "CUDA_VERSION=${CUDA_VERSION}"
    --build-arg "MISTRALRS_REF=${MISTRALRS_REF}"
    --build-arg "WITH_FEATURES=${WITH_FEATURES}"
    -t "${DOCKER_IMAGE_TAG}"
    -f "${SCRIPT_DIR}/Containerfile"
)

if [[ "$NO_CACHE" == true ]]; then
    BUILD_ARGS+=(--no-cache)
fi

if [[ "${GITHUB_ACTIONS:-}" == "true" && "${ACT:-}" != "true" ]]; then
    CACHE_REF="ghcr.io/ormandj/mistralrs:buildcache-cuda${CUDA_COMPUTE_CAP}"
    BUILD_ARGS+=(
        --cache-from "type=registry,ref=${CACHE_REF}"
        --cache-to "type=registry,ref=${CACHE_REF},mode=max"
    )
fi

DOCKER_BUILDKIT=1 docker buildx build --load "${BUILD_ARGS[@]}" "${SCRIPT_DIR}"

echo ""
echo "=========================================="
echo "Verifying build artifacts..."
echo "=========================================="
echo ""

MISSING=()
for bin in mistralrs mistralrs-server mistralrs-bench mistralrs-web-chat; do
    if ! docker run --rm --entrypoint which "${DOCKER_IMAGE_TAG}" "${bin}" >/dev/null 2>&1; then
        MISSING+=("${bin}")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "ERROR: Missing binaries: ${MISSING[*]}"
    exit 1
fi

echo "All binaries verified: mistralrs, mistralrs-server, mistralrs-bench, mistralrs-web-chat"
echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Image:    ${DOCKER_IMAGE_TAG}"
echo "Version:  $(docker run --rm --entrypoint cat "${DOCKER_IMAGE_TAG}" /versions.txt | head -1)"
echo ""
echo "Run with: docker run --rm --gpus all ${DOCKER_IMAGE_TAG}"
