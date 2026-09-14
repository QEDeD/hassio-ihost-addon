#!/bin/bash
# Example (explicit experimental selection):
# CPC_ENCRYPTION=OFF bash review/sdk2026/build-host-sdk2026.sh
# Builds a local image only. Does not run, publish or attach it to hardware.
set -euo pipefail
: "${CPC_ENCRYPTION:?Set CPC_ENCRYPTION explicitly to ON or OFF}"
case "$CPC_ENCRYPTION" in ON|OFF) ;; *) echo 'CPC_ENCRYPTION must be ON or OFF' >&2; exit 2;; esac
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
exec docker build --platform linux/amd64 \
  --file "$repo/hassio-ihost-silabs-multiprotocol/Dockerfile.sdk2026" \
  --build-arg "CPC_ENCRYPTION=$CPC_ENCRYPTION" \
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-4}" \
  --tag "${IMAGE_TAG:-local/silabs-multiprotocol:sdk2026-candidate}" \
  "$@" "$repo"
