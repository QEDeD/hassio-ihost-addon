#!/usr/bin/env bash
# Offline build only. No serial device, flashing, or host mounts in the build.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
out=${DIAGNOSTIC_OUTPUT:-$repo/review/sdk2026/firmware/cpc-crypto-diagnostic/output}
[[ ! -e "$out" ]] || { echo 'Refusing existing output directory' >&2; exit 2; }
exec docker build --platform linux/amd64 --progress plain \
  --file "$repo/review/sdk2026/firmware/cpc-crypto-diagnostic/Dockerfile.offline" \
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-2}" --output "type=local,dest=$out" "$repo"
