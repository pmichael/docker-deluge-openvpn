#!/usr/bin/env sh
set -e

IMAGE=$1

docker push "${IMAGE}:amd64-latest"
