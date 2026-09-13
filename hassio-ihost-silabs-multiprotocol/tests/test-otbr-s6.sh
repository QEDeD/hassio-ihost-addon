#!/bin/bash
# Actual released s6 lifecycle; no radio services, devices or host networking.
set -euo pipefail
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
IMAGE="local/otbr-s6-test:$$"
EVIDENCE_DIR="${OTBR_S6_EVIDENCE_DIR:-$(mktemp -d)}"
mkdir -p -- "${EVIDENCE_DIR}"
container=""
cleanup()
{
    if [[ -n "${container}" ]]; then
        timeout 15s docker rm --force "${container}" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT
fail()
{
    printf 'FAIL: %s (evidence: %s)\n' "$*" "${EVIDENCE_DIR}" >&2
    exit 1
}
# A build timeout also bounds a failed registry request.
timeout 300s docker build --file "${TEST_DIR}/s6/Dockerfile" \
    --tag "${IMAGE}" "${ADDON_DIR}"
for scenario in failure bounded-stall finish-timeout shutdown-order; do
    container="otbr-s6-test-$$-${scenario}"
    log="${EVIDENCE_DIR}/${scenario}.log"
    # Only process/identity capabilities needed by init; no NET_ADMIN/NET_RAW,
    # privileged mode, devices, volumes or host namespace sharing.
    timeout 30s docker run --detach --name "${container}" \
        --network none --cap-drop ALL \
        --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER \
        --cap-add SETGID --cap-add SETUID --cap-add KILL \
        --security-opt no-new-privileges --pids-limit 128 \
        --env "OTBR_S6_CASE=${scenario}" "${IMAGE}" >/dev/null
    if [[ "${scenario}" == shutdown-order ]]; then
        timeout 10s docker exec "${container}" sh -c \
            'until test -f /run/s6-test-client-ready; do sleep 0.1; done' \
            || fail "${scenario}: client did not become ready"
        timeout 15s docker stop --time 10 "${container}" >/dev/null \
            || fail "${scenario}: ordered shutdown timed out"
    fi
    started_seconds=${SECONDS}
    wait_status=0
    timeout 35s docker wait "${container}" \
        > "${EVIDENCE_DIR}/${scenario}.exitcode" || wait_status=$?
    elapsed_seconds=$((SECONDS - started_seconds))
    timeout 10s docker logs "${container}" > "${log}" 2>&1 || true
    timeout 10s docker inspect "${container}" \
        > "${EVIDENCE_DIR}/${scenario}.inspect.json" || true
    cat "${log}"
    (( wait_status == 0 )) || fail "${scenario}: container did not stop within 35 seconds"
    expected_exit=23
    if [[ "${scenario}" == shutdown-order ]]; then expected_exit=0; fi
    [[ "$(cat "${EVIDENCE_DIR}/${scenario}.exitcode")" == "${expected_exit}" ]] \
        || fail "${scenario}: original daemon exit code was not preserved"
    [[ "$(grep -c '^S6_TEST_DAEMON_START$' "${log}" || true)" == 1 ]] \
        || fail "${scenario}: daemon did not start exactly once"
    if [[ "${scenario}" == shutdown-order ]]; then
        client_line=$(grep -n '^S6_TEST_CLIENT_STOP_COMPLETE$' "${log}" | cut -d: -f1 || true)
        server_line=$(grep -n '^S6_TEST_MDNS_STOP$' "${log}" | cut -d: -f1 || true)
        [[ -n "${client_line}" && -n "${server_line}" ]] \
            || fail "${scenario}: missing shutdown completion markers"
        (( client_line < server_line )) \
            || fail "${scenario}: mDNS stopped before its client completed"
    elif [[ "${scenario}" == finish-timeout ]]; then
        (( elapsed_seconds >= 9 )) || fail "${scenario}: shutdown preceded the 10-second finish timeout"
        grep -q '^S6_TEST_FORCED_FINISH_TIMEOUT status=23$' "${log}" \
            || fail "${scenario}: stalled cleanup did not observe persisted exit status"
        if grep -q 'OTBR firewall teardown was incomplete\|OTBR firewall teardown completed' "${log}"; then
            fail "${scenario}: cleanup returned instead of reaching s6 finish expiry"
        fi
    else
        grep -q '^S6_TEST_CLEANUP_STATUS=23$' "${log}" \
            || fail "${scenario}: cleanup did not observe persisted exit status"
        grep -q 'OTBR firewall teardown was incomplete' "${log}" \
            || fail "${scenario}: real cleanup failure did not return to finish"
    fi
    timeout 15s docker rm "${container}" >/dev/null
    container=""
    printf 'PASS: released s6 shutdown (%s)\n' "${scenario}"
done
printf 's6 evidence: %s\n' "${EVIDENCE_DIR}"
