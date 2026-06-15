#!/usr/bin/env bash
#
# Build the git-sync image for both amd64 and arm64 and push a single
# multi-arch manifest to Docker Hub.
#
# Usage:
#   DOCKER_USER=<user> ./scripts/build-and-push.sh [VERSION]
#
# Examples:
#   DOCKER_USER=miciav ./scripts/build-and-push.sh        # tags :latest
#   DOCKER_USER=miciav ./scripts/build-and-push.sh 1.0    # tags :1.0 and :latest
#
# Environment overrides:
#   DOCKER_USER   Docker Hub username        (required)
#   SHORT_NAME    Image name                 (default: git-sync)
#   PLATFORMS     Target platforms           (default: linux/amd64,linux/arm64)

set -euo pipefail

DOCKER_USER="${DOCKER_USER:-}"
SHORT_NAME="${SHORT_NAME:-git-sync}"
VERSION="${1:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

if [[ -z "${DOCKER_USER}" ]]; then
  echo "ERROR: DOCKER_USER is not set." >&2
  echo "Pass it via the environment, e.g.:" >&2
  echo "  DOCKER_USER=youruser ./scripts/build-and-push.sh [VERSION]" >&2
  echo "Or via make:" >&2
  echo "  make push-hub DOCKER_USER=youruser VERSION=1.0" >&2
  exit 1
fi

# Resolve repo root from this script's location so it works from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="docker.io/${DOCKER_USER}/${SHORT_NAME}"

# Always tag the requested version; also tag :latest unless that's already it.
TAGS=(-t "${IMAGE}:${VERSION}")
if [[ "${VERSION}" != "latest" ]]; then
  TAGS+=(-t "${IMAGE}:latest")
fi

echo "==> Image:     ${IMAGE}:${VERSION}"
echo "==> Platforms: ${PLATFORMS}"

# Ensure we're logged in to Docker Hub; prompt only if needed.
if ! docker system info 2>/dev/null | grep -q "Username:"; then
  echo "==> Not logged in to Docker Hub, running 'docker login'..."
  docker login -u "${DOCKER_USER}"
fi

# buildx needs a builder that supports multi-platform output. Create a
# dedicated one if it doesn't already exist, then use it.
BUILDER="git-sync-builder"
if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
  echo "==> Creating buildx builder '${BUILDER}'..."
  docker buildx create --name "${BUILDER}" --driver docker-container --use
else
  docker buildx use "${BUILDER}"
fi
docker buildx inspect --bootstrap >/dev/null

echo "==> Building and pushing multi-arch image..."
docker buildx build \
  --platform "${PLATFORMS}" \
  "${TAGS[@]}" \
  -f "${REPO_ROOT}/rootfs/Dockerfile" \
  --push \
  "${REPO_ROOT}"

echo "==> Done. Pushed ${IMAGE}:${VERSION} for ${PLATFORMS}"
