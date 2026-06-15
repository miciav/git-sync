# Build stage: cross-compile the Go binary for the target platform.
# Runs natively on the builder ($BUILDPLATFORM) and cross-compiles via Go,
# which is much faster than emulating the target arch.
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GO111MODULE=off \
    go build -a -installsuffix cgo -ldflags "-s" -o /out/git-sync main.go

# Runtime stage.
FROM alpine:3.20
LABEL maintainer="Jason Hansen <jhansen@deis.com>"

RUN apk add --no-cache git

VOLUME ["/git"]
ENV GIT_SYNC_DEST=/git

COPY --from=build /out/git-sync /bin/git-sync

CMD ["/bin/git-sync"]
