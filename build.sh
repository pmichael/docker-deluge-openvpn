#!/usr/bin/env sh
set -e

IMAGE=$1

docker build --no-cache --pull -t "${IMAGE}:amd64-latest" .