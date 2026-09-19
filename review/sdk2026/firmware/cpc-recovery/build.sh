#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
out=${RECOVERY_OUTPUT:-$repo/review/sdk2026/firmware/cpc-recovery/output}
[[ ! -e "$out" ]] || { echo 'Refusing existing output directory' >&2; exit 2; }
exec docker build --platform linux/amd64 --progress plain \
  --file "$repo/review/sdk2026/firmware/cpc-recovery/Dockerfile.offline" \
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-2}" --output "type=local,dest=$out" "$repo"
