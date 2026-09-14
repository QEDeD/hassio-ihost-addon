#!/usr/bin/env bash
# Reconstruct offline firmware from a digest-pinned pristine builder.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
out=${FIRMWARE_OUTPUT:-$repo/review/sdk2026/firmware/candidate-clean}
if [[ -e "$out" ]]; then echo "Refusing existing output directory: $out" >&2; exit 2; fi
exec docker build --platform linux/amd64 --no-cache --progress plain \
  --file "$repo/review/sdk2026/firmware/Dockerfile.offline" \
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-2}" \
  --output "type=local,dest=$out" "$repo"
