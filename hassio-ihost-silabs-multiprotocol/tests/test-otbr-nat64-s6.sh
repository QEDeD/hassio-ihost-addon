#!/bin/bash
# Released /init + notifyoncheck. No devices, host networking, volumes or credentials.
set -euo pipefail
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
IMAGE="local/otbr-nat64-s6-test:$$"
container=""
cleanup()
{
    if [[ -n "$container" ]]; then
        timeout 15s docker logs "$container" 2>&1 || true
        timeout 15s docker rm --force "$container" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
timeout 300s docker build --file "$TEST_DIR/s6-nat64/Dockerfile" --tag "$IMAGE" "$ADDON_DIR"
for scenario in off on error error-stall; do
    container="otbr-nat64-s6-$$-$scenario"
    timeout 30s docker run --detach --name "$container" \
        --network none --cap-drop ALL \
        --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
        --cap-add SETGID --cap-add SETUID --cap-add KILL \
        --security-opt no-new-privileges --pids-limit 128 \
        --env "NAT64_CASE=$scenario" "$IMAGE" >/dev/null
    # The controller itself waits for s6 service startup and bounds every stage.
    timeout 60s docker exec "$container" python3 -u /fixture/assert.py "$scenario"
    if [[ "$scenario" == error* ]]; then
        shutdown_started=$SECONDS
        result="$(timeout 20s docker wait "$container")"
        shutdown_elapsed=$((SECONDS - shutdown_started))
        [[ "$result" == 1 ]] || { echo "Expected configuration failure exit 1, got $result" >&2; exit 1; }
        log="$(timeout 10s docker logs "$container" 2>&1)"
        printf '%s\n' "$log"
        [[ "$log" == *"Could not configure NAT64/upstream DNS; stopping the add-on."* ]]
        [[ "$log" == *"Error 7: InvalidState"* ]]
        [[ "$log" != *NAT64_FIXTURE_PREMATURE_READY* ]]
        [[ "$log" != *"service otbr-agent successfully started"* ]]
        # Read final container-local state after shutdown, including any late retries.
        actual="$(timeout 10s docker cp "$container:/tmp/commands" - | tar -xOf -)"
        expected=$'1 dns server upstream disable\n1 nat64 disable'
        [[ "$actual" == "$expected" ]] || {
            printf 'CLI after failure: actual=%s; expected=%s\n' "$actual" "$expected" >&2
            exit 1
        }
        generation="$(timeout 10s docker cp "$container:/tmp/generation" - | tar -xOf -)"
        [[ "$generation" == 1 ]] || { echo "Unexpected restart generation=$generation" >&2; exit 1; }
        if [[ "$scenario" == error-stall ]]; then
            (( shutdown_elapsed >= 2 ))
            [[ "$log" == *NAT64_FIXTURE_SIGTERM_IGNORED* ]]
            [[ "$log" == *"otbr-agent exited with code 1 (by signal 9)."* ]]
        else
            [[ "$log" == *NAT64_FIXTURE_SIGTERM_CLEAN_EXIT* ]]
            [[ "$log" == *"otbr-agent exited with code 1 (by signal 0)."* ]]
        fi
    else
        timeout 20s docker stop --time 10 "$container" >/dev/null
        result="$(timeout 10s docker inspect --format '{{.State.ExitCode}}' "$container")"
        [[ "$result" == 0 ]] || { echo "Expected clean shutdown, got $result" >&2; exit 1; }
        timeout 10s docker logs "$container"
    fi
    log="$(timeout 10s docker logs "$container" 2>&1)"
    [[ "$log" != *"Something went wrong contacting the API"* ]]
    [[ "$log" != *"Could not resolve host: supervisor"* ]]
    timeout 15s docker rm "$container" >/dev/null
    container=""
    printf 'PASS: released init NAT64 scenario=%s\n' "$scenario"
done
