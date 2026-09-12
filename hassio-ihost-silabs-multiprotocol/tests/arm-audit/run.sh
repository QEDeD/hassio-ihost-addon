#!/bin/bash
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
audit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
addon="$(cd "$audit_dir/../.." && pwd)"
# shellcheck source=../trixie-audit/inputs.sh
source "$audit_dir/../trixie-audit/inputs.sh"
arch="${1:?armv7 or aarch64 required}"
case "$arch" in
    armv7)
        base='ghcr.io/home-assistant/armv7-base-debian@sha256:3240030791b68354aa2a8d0e46c5ed02dd90971d559dce25ff17649a86d06e1d'
        platform=linux/arm/v7;;
    aarch64)
        base='ghcr.io/home-assistant/aarch64-base-debian@sha256:d5eadceb6b0a2b32145065cc3dfd085e740e9805d1c443ca2f09bc4241f946e7'
        platform=linux/arm64;;
    *) exit 1;;
esac
AUDIT_CONTEXT="$(mktemp -d "$RUNNER_TEMP/trixie-arm.XXXXXX")"
cp -a "$addon/." "$AUDIT_CONTEXT/"
curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 20 --max-time 180 --retry 2 \
    --output "$AUDIT_CONTEXT/slc_cli_linux.zip" "$SLC_URL"
printf '%s  %s\n' "$SLC_SHA256" "$AUDIT_CONTEXT/slc_cli_linux.zip" | sha256sum -c -
[[ "$(stat -c %s "$AUDIT_CONTEXT/slc_cli_linux.zip")" == "$SLC_BYTES" ]]
export AUDIT_CONTEXT BUILDER_IMAGE SLC_SHA256 CPC_REVISION SDK_REVISION
python3 "$audit_dir/../trixie-audit/prepare.py"
python3 - <<'PY'
import os
from pathlib import Path
path = Path(os.environ['AUDIT_CONTEXT'])/'Dockerfile'
text = path.read_text()
marker = '\nFROM $BUILD_FROM'
assert text.count(marker) == 1
text = text.replace(marker, '\nCOPY --from=cpcd-builder /usr/src/cpc-daemon/build /audit/cpc-build\n' + marker)
path.write_text(text)
PY
printf 'ARM_INPUT arch=%s base=%s CPC=%s SDK=%s SLC=%s\n' "$arch" "$base" "$CPC_REVISION" "$SDK_REVISION" "$SLC_SHA256"
# Inspect target image metadata/files without starting it or installing emulation.
timeout 180s docker pull --platform "$platform" "$base"
docker image inspect --format '{{.Architecture}} {{.Os}} {{json .RepoDigests}}' "$base"
container="$(docker create --platform "$platform" --entrypoint /bin/true "$base")"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker cp "$container:/etc/os-release" "$AUDIT_CONTEXT/base-os-release"
cat "$AUDIT_CONTEXT/base-os-release"
grep -q 'VERSION_CODENAME=trixie' "$AUDIT_CONTEXT/base-os-release"
docker rm "$container" >/dev/null
trap - EXIT
# The actual cross stages run on AMD64, including the unchanged SLC generator.
timeout --kill-after=30s 1800s docker build --progress=plain --platform linux/amd64 \
    --target zigbeed-builder --build-arg "BUILD_FROM=$base" --build-arg "BUILD_ARCH=$arch" \
    --build-arg CPCD_VERSION=v4.6.1 --build-arg GECKO_SDK_VERSION=v2024.12.1-0 \
    --tag "local/trixie-cross-$arch" "$AUDIT_CONTEXT"
timeout 90s docker run --rm -i --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 128 --tmpfs /tmp:rw,nosuid,nodev,size=16m \
    --entrypoint /bin/bash "local/trixie-cross-$arch" < "$audit_dir/probe.sh"
