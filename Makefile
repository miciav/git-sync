SHORT_NAME ?= git-sync
VERSION ?= latest
REGISTRY ?= quay.io/jhansen
IMAGE := ${REGISTRY}/${SHORT_NAME}:${VERSION}

# Docker Hub username (no default; required by the push-hub target).
DOCKER_USER ?=

# Platforms to build the multi-arch image for.
PLATFORMS ?= linux/amd64,linux/arm64

export GOARCH ?= amd64
export GOOS ?= linux
export CGO_ENABLED=0

BINDIR := rootfs/bin
LDFLAGS := "-s"

.PHONY: info all clean build docker-build docker-buildx push push-multiarch push-hub
all: info docker-build
	echo "Done! ${IMAGE}"

clean:
	rm -f ${BINDIR}/git-sync

# Optional host build (binary is also built inside the Docker image).
build: clean
	go build -o ${BINDIR}/git-sync -a -installsuffix cgo -ldflags ${LDFLAGS} main.go

# Build a single-arch image for the local machine and load it into Docker.
# The Go binary is cross-compiled inside the image, so the build context is the
# repo root (to reach main.go) using rootfs/Dockerfile.
docker-build:
	docker build --rm -t ${IMAGE} -f rootfs/Dockerfile .

# Build a multi-arch image (does not load locally; use push-multiarch to publish).
docker-buildx:
	docker buildx build --platform ${PLATFORMS} -t ${IMAGE} -f rootfs/Dockerfile .

info:
	@echo "Docker: REGISTRY=${REGISTRY} VERSION=${VERSION} IMAGE=${IMAGE}"
	@echo "Platforms: ${PLATFORMS}"
	@echo "Environment: BINDIR=${BINDIR}"
	@echo "Go Environment: GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=${CGO_ENABLED} LDFLAGS=${LDFLAGS}"

push:
	docker push ${IMAGE}

# Build and push a multi-arch (amd64 + arm64) image manifest in one step.
push-multiarch:
	docker buildx build --platform ${PLATFORMS} -t ${IMAGE} -f rootfs/Dockerfile --push .

# Build and push a multi-arch image to Docker Hub via the helper script.
# Requires DOCKER_USER, e.g.: make push-hub DOCKER_USER=youruser VERSION=1.0
push-hub:
	DOCKER_USER="${DOCKER_USER}" SHORT_NAME="${SHORT_NAME}" PLATFORMS="${PLATFORMS}" \
		scripts/build-and-push.sh ${VERSION}
