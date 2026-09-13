#!/bin/bash
set -euo pipefail
[[ ${AUDIT_LOCAL_DOCKER:-} == 1 || ( ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ) ]] || {
    echo 'Use a disposable GitHub-hosted runner or explicitly opt in with AUDIT_LOCAL_DOCKER=1.' >&2; exit 1;
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
    docker image inspect --format '{{.Id}} {{.Architecture}} {{json .RepoDigests}} {{json .Config}}' "$image" || return
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

# A fresh record cannot be mistaken for an earlier successful build.
AUDIT_BUILD_RECORD="${AUDIT_BUILD_RECORD:-$RUNNER_TEMP/trixie-build-record}"
mkdir "$AUDIT_BUILD_RECORD"
export AUDIT_BUILD_RECORD
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
# Record the actual checkout state and copied, instrumented build inputs. Hashes
# retain dirty/untracked evidence without publishing arbitrary source contents.
export addon
python3 - <<'PY'
import hashlib, json, os, subprocess
from pathlib import Path
addon = Path(os.environ['addon'])
context = Path(os.environ['AUDIT_CONTEXT'])
record = Path(os.environ['AUDIT_BUILD_RECORD'])
def git(*args):
    return subprocess.check_output(['git', '-C', str(addon), *args])
revision = git('rev-parse', 'HEAD').decode().strip()
requested = os.environ.get('AUDIT_SOURCE_REVISION') or os.environ.get('GITHUB_SHA')
if requested and requested != revision:
    raise SystemExit('requested source revision differs from actual checkout HEAD')
evidence = {
    'revision': revision,
    'status_porcelain': git('status', '--porcelain=v1', '--untracked-files=all').decode(),
    'tracked_diff_sha256': hashlib.sha256(git('diff', '--binary', 'HEAD')).hexdigest(),
    'untracked_paths': git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')[:-1],
    'build_context_files': {p.relative_to(context).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                            for p in sorted(context.rglob('*')) if p.is_file()},
}
(record / 'source-evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
PY
diff -u "$addon/Dockerfile" "$AUDIT_CONTEXT/Dockerfile" || [[ $? == 1 ]]

# Preserve the entire production AMD64 build, including SLC-generated Zigbee,
# OTBR WEB/npm and package cleanup. Do not fix failures automatically.
result=0
timeout --kill-after=30s 5400s docker build --progress=plain --platform linux/amd64 \
    --build-arg "BUILD_FROM=$HA_IMAGE" --build-arg BUILD_ARCH=amd64 \
    --build-arg CPCD_VERSION=v4.6.1 --build-arg GECKO_SDK_VERSION=v2024.12.1-0 \
    --iidfile "$AUDIT_BUILD_RECORD/image-id" --tag local/ihost-trixie-audit "$AUDIT_CONTEXT" 2>&1 | tee "$RUNNER_TEMP/trixie-full-build.log" || result=$?
if (( result != 0 )); then
    printf 'BUILD_RESULT: complete AMD64 attempt failed, status=%s; BuildKit stage/command above is the failure evidence.\n' "$result"
    exit "$result"
fi
built_id="$(cat "$AUDIT_BUILD_RECORD/image-id" )"
[[ "$built_id" =~ ^sha256:[0-9a-f]{64}$ ]]
[[ "$(docker image inspect --format '{{.Id}}' local/ihost-trixie-audit)" == "$built_id" ]]
printf 'BUILD_RESULT: complete AMD64 image built; inspecting without starting services\n'
docker image inspect --format '{{.Id}} {{.Architecture}} {{json .Config}}' "$built_id"
timeout 120s docker run --rm -i --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 128 --env AUDIT_REQUIRE_APPLICATIONS=1 --entrypoint /bin/bash \
    "$built_id" < "$audit_dir/inventory.sh"
printf 'PASS: complete AMD64 build plus linkage inventory; no physical/radio/runtime service acceptance claimed\n'

# Only a successful build and linkage inventory produce this acceptance record.
export built_id
python3 - <<'PY'
import hashlib, json, os
from pathlib import Path
record = Path(os.environ['AUDIT_BUILD_RECORD'])
source = record / 'source-evidence.json'
(record / 'success.json').write_text(json.dumps({
    'image_id': os.environ['built_id'],
    'source_revision': json.loads(source.read_text())['revision'],
    'source_evidence_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'build_and_inventory_passed': True,
}, indent=2) + '\n')
PY
