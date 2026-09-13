#!/bin/bash
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]] || {
    echo 'Use only a disposable GitHub-hosted runner.' >&2; exit 1;
}
audit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
addon="$(cd "$audit_dir/../.." && pwd)"
# shellcheck source=inputs.sh
source "$audit_dir/inputs.sh"

inventory() {
    local image="$1" label="$2" required=0
    [[ "$label" != release ]] || required=1
    printf 'IMAGE_BEGIN %s %s\n' "$label" "$image"
    timeout 300s docker pull --platform linux/amd64 "$image" || return
    docker image inspect --format '{{.Id}} {{.Architecture}} {{json .RepoDigests}} {{json .Config.Labels}}' "$image" || return
    timeout 120s docker run --rm -i --network none --read-only --cap-drop ALL \
        --security-opt no-new-privileges --pids-limit 128 \
        --env "AUDIT_REQUIRE_APPLICATIONS=$required" --entrypoint /bin/bash "$image" < "$audit_dir/inventory.sh" || return
    printf 'IMAGE_END %s\n' "$label"
}
# Inventory exact installed contents, not package-index candidates.
failed_inventory=0
for spec in release ha-base builder-base; do
    case "$spec" in
        release) image="$RELEASE_IMAGE";;
        ha-base) image="$HA_IMAGE";;
        builder-base) image="$BUILDER_IMAGE";;
    esac
    if ! inventory "$image" "$spec"; then failed_inventory=1; fi
done
(( failed_inventory == 0 )) || { echo 'Base inventory failed; stop before build'; exit 1; }

AUDIT_CONTEXT="$(mktemp -d "$RUNNER_TEMP/trixie-build.XXXXXX")"
cp -a "$addon/." "$AUDIT_CONTEXT/"
# Anonymous official HTTPS download only; any login/error/changed ZIP is a failure.
curl --fail --location --proto '=https' --proto-redir '=https' \
    --connect-timeout 20 --max-time 180 --retry 2 \
    --output "$AUDIT_CONTEXT/slc_cli_linux.zip" "$SLC_URL"
printf '%s  %s\n' "$SLC_SHA256" "$AUDIT_CONTEXT/slc_cli_linux.zip" | sha256sum -c -
[[ "$(stat -c %s "$AUDIT_CONTEXT/slc_cli_linux.zip")" == "$SLC_BYTES" ]]
export AUDIT_CONTEXT BUILDER_IMAGE SLC_SHA256 CPC_REVISION SDK_REVISION
python3 "$audit_dir/prepare.py"
printf 'SLC_PROVENANCE url=%s sha256=%s bytes=%s\n' "$SLC_URL" "$SLC_SHA256" "$SLC_BYTES"
printf 'SOURCE_PROVENANCE CPC=v4.6.1/%s SDK=v2024.12.1-0/%s\n' "$CPC_REVISION" "$SDK_REVISION"
diff -u "$addon/Dockerfile" "$AUDIT_CONTEXT/Dockerfile" || [[ $? == 1 ]]

# Preserve the entire production AMD64 build, including SLC-generated Zigbee,
# OTBR WEB/npm and package cleanup. Do not fix failures automatically.
result=0
timeout --kill-after=30s 5400s docker build --progress=plain --platform linux/amd64 \
    --build-arg "BUILD_FROM=$HA_IMAGE" --build-arg BUILD_ARCH=amd64 \
    --build-arg CPCD_VERSION=v4.6.1 --build-arg GECKO_SDK_VERSION=v2024.12.1-0 \
    --tag local/ihost-trixie-audit "$AUDIT_CONTEXT" 2>&1 | tee "$RUNNER_TEMP/trixie-full-build.log" || result=$?
if (( result != 0 )); then
    printf 'BUILD_RESULT: complete AMD64 attempt failed, status=%s; BuildKit stage/command above is the failure evidence.\n' "$result"
    exit "$result"
fi
printf 'BUILD_RESULT: complete AMD64 image built; inspecting without starting services\n'
docker image inspect --format '{{.Id}} {{.Architecture}} {{json .Config.Labels}}' local/ihost-trixie-audit
timeout 120s docker run --rm -i --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 128 --env AUDIT_REQUIRE_APPLICATIONS=1 --entrypoint /bin/bash \
    local/ihost-trixie-audit < "$audit_dir/inventory.sh"
printf 'PASS: complete AMD64 build plus linkage inventory; no physical/radio/runtime service acceptance claimed\n'
