#!/bin/bash
set -euo pipefail
[[ ${AUDIT_LOCAL_DOCKER:-} == 1 || ( ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ) ]]
helper="${1:?pinned local-service directory required}"
helper_revision=391bb7c56e01ef34ae5ae0b8cd259f31fdb7d6d0
[[ "$(git -C "$helper" rev-parse HEAD)" == "$helper_revision" ]]
[[ -z "$(git -C "$helper" status --porcelain=v1 --untracked-files=all)" ]]
record="${AUDIT_BUILD_RECORD:-$RUNNER_TEMP/trixie-build-record}"
# Refuse alias-only or retrospectively inferred provenance. run.sh writes this
# record only after a successful build and immutable-image linkage inventory.
mapfile -t identity < <(python3 - "$record" <<'PY'
import hashlib, json, re, sys
from pathlib import Path
record = Path(sys.argv[1])
success = json.loads((record / 'success.json').read_text())
source = record / 'source-evidence.json'
assert success.get('build_and_inventory_passed') is True
assert re.fullmatch(r'sha256:[0-9a-f]{64}', success['image_id'])
assert re.fullmatch(r'[0-9a-f]{40}', success['source_revision'])
assert source.is_file() and hashlib.sha256(source.read_bytes()).hexdigest() == success['source_evidence_sha256']
assert json.loads(source.read_text())['revision'] == success['source_revision']
assert (record / 'image-id').read_text().strip() == success['image_id']
print(success['image_id'])
print(success['source_revision'])
PY
)
[[ ${#identity[@]} == 2 ]]
base_id="${identity[0]}"
source_revision="${identity[1]}"
[[ "${AUDIT_SOURCE_REVISION:-${GITHUB_SHA:-$source_revision}}" == "$source_revision" ]]
[[ "$(docker image inspect --format '{{.Id}}' local/ihost-trixie-audit)" == "$base_id" ]]
base="local/otbr-combined-base:$source_revision"
docker tag "$base_id" "$base"
package="$RUNNER_TEMP/otbr-trial-package"
mkdir "$package"
cp "$record/success.json" "$record/source-evidence.json" "$record/image-id" "$package/"
printf '%s\n' "$helper_revision" > "$package/helper-revision.txt"
docker image inspect "$base" > "$package/base-inspect.json"
python3 "$helper/make_trial_contexts.py" "$package/contexts" \
    --combined-image "$base" --expected-image-id "$base_id" \
    --image-inspect "$package/base-inspect.json"
[[ "$(docker image inspect --format '{{.Id}}' "$base")" == "$base_id" ]]
for variant in candidate baseline recovery; do
    timeout --kill-after=10s 180s docker build --pull=false --network none \
        --tag "local/otbr-trial-$variant:ci" "$package/contexts/$variant"
done
[[ "$(docker image inspect --format '{{.Id}}' "$base")" == "$base_id" ]]
candidate="$(docker image inspect --format '{{.Id}}' local/otbr-trial-candidate:ci)"
baseline="$(docker image inspect --format '{{.Id}}' local/otbr-trial-baseline:ci)"
recovery="$(docker image inspect --format '{{.Id}}' local/otbr-trial-recovery:ci)"
# Compile the complete installed graph, including the local observer. Never run
# /init or any service; the only writable filesystem is temporary compiler output.
for variant in candidate baseline recovery; do
    case "$variant" in
        candidate) image="$candidate";;
        baseline) image="$baseline";;
        recovery) image="$recovery";;
    esac
    graph_container="otbr-graph-$variant-$$"
    trap 'docker rm -f "$graph_container" >/dev/null 2>&1 || true' EXIT
    # Inner expressions expand in the isolated container shell.
    # shellcheck disable=SC2016
    timeout --kill-after=5s 45s docker run --rm --pull=never --no-healthcheck --name "$graph_container" \
        --network none --read-only --cap-drop ALL --security-opt no-new-privileges \
        --pids-limit 32 --memory 128m --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m \
        --entrypoint /bin/sh "$image" -ec '
            set -- /package/admin/s6-overlay-*/etc/s6-rc/sources
            test "$#" -eq 1 && test -d "$1"
            command -v s6-rc-compile
            s6-rc-compile /tmp/full-s6-db "$1" /etc/s6-overlay/s6-rc.d
            printf "PASS: complete packaged s6 graph compiled; no services started\n"
        ' | tee "$package/$variant-s6-graph.log"
    trap - EXIT
done
python3 "$helper/check_image_switch.py" \
    --candidate "$candidate" --baseline "$baseline" --recovery "$recovery"
docker image inspect local/otbr-trial-candidate:ci local/otbr-trial-baseline:ci \
    local/otbr-trial-recovery:ci > "$package/packaged-images.json"
printf 'source=%s\nbase=%s\ncandidate=%s\nbaseline=%s\nrecovery=%s\n' \
    "$source_revision" "$base_id" "$candidate" "$baseline" "$recovery" | tee "$package/identity.txt"
# Existing runtime/QR checks now exercise the final guarded candidate's contents.
# Keep the original unique base tag intact for reproducible wrapper provenance.
docker tag "$candidate" local/ihost-trixie-audit
