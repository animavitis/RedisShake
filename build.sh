#!/bin/bash

set -e

echo "[ BUILD RELEASE ]"
BIN_DIR=$(pwd)/bin/
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

cp shake.toml "$BIN_DIR"

VERSION=${VERSION:-"dev"}
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    COMMIT=${COMMIT:-$(git rev-parse --short HEAD)}
else
    COMMIT=${COMMIT:-"unknown"}
fi
# Use GO_LDFLAGS to avoid conflict with system LDFLAGS (e.g., from Homebrew)
GO_LDFLAGS="-X main.Version=${VERSION} -X main.GitCommit=${COMMIT}"

dist() {
    echo "try build GOOS=$1 GOARCH=$2"
    # Windows needs the .exe suffix; without it the archive ships a file Windows
    # will not execute directly.
    BIN_NAME="redis-shake"
    if [ "$1" == "windows" ]; then
        BIN_NAME="redis-shake.exe"
    fi
    export GOOS=$1
    export GOARCH=$2
    export CGO_ENABLED=0
    go build -v -trimpath -ldflags "${GO_LDFLAGS}" -o "$BIN_DIR/$BIN_NAME" "./cmd/redis-shake"
    unset GOOS
    unset GOARCH
    echo "build success GOOS=$1 GOARCH=$2"

    cd "$BIN_DIR"
    tar -czvf ./redis-shake-"$1"-"$2".tar.gz ./"$BIN_NAME" ./shake.toml
    # Do not leave the Windows binary behind; the final native build writes
    # redis-shake and would otherwise sit next to a stale redis-shake.exe.
    if [ "$1" == "windows" ]; then
        rm -f ./"$BIN_NAME"
    fi
    cd ..
}

if [ "$1" == "dist" ]; then
    echo "[ DIST ]"
    for g in "linux" "darwin" "windows"; do
        for a in "amd64" "arm64"; do
            dist "$g" "$a"
        done
    done
fi

# build the current platform
echo "try build for current platform"
go build -v -trimpath -ldflags "${GO_LDFLAGS}" -o "$BIN_DIR/redis-shake" "./cmd/redis-shake"
echo "build success"
