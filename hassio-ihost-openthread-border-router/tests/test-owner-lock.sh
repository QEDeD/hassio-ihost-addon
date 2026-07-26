#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly OWNER_LOCK="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-owner-lock.py"

scratch="$(mktemp -d)"
holder_pid=""

cleanup()
{
    if [[ -n "${holder_pid}" ]] && kill -0 "${holder_pid}" 2>/dev/null; then
        kill -KILL "${holder_pid}" 2>/dev/null || true
        wait "${holder_pid}" 2>/dev/null || true
    fi
    rm -f \
        "${scratch}/blocked" \
        "${scratch}/blocked-during-command" \
        "${scratch}/contender.err" \
        "${scratch}/killed-ready" \
        "${scratch}/post-kill" \
        "${scratch}/post-release" \
        "${scratch}/ready"
    rmdir "${scratch}"
}
trap cleanup EXIT

wait_for_readiness()
{
    local pid="$1"
    local ready_file="$2"
    local attempt

    for ((attempt = 0; attempt < 200; attempt++)); do
        if [[ -s "${ready_file}" ]]; then
            return 0
        fi
        if ! kill -0 "${pid}" 2>/dev/null; then
            echo "ownership helper exited before reporting readiness" >&2
            return 1
        fi
        sleep 0.01
    done
    echo "ownership helper did not report readiness" >&2
    return 1
}

readonly socket_name="io.home-assistant.otbr-owner.test-${BASHPID}"

python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    3>"${scratch}/ready" &
holder_pid=$!
wait_for_readiness "${holder_pid}" "${scratch}/ready"

set +e
python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    -- /usr/bin/touch "${scratch}/blocked" \
    3>/dev/null 2>"${scratch}/contender.err"
contender_status=$?
set -e
[[ "${contender_status}" -eq 75 ]]
[[ ! -e "${scratch}/blocked" ]]
grep -Fq \
    "the OTBR ownership gate '@${socket_name}' is already held" \
    "${scratch}/contender.err"

kill -TERM "${holder_pid}"
wait "${holder_pid}"
holder_pid=""

python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    -- /usr/bin/touch "${scratch}/post-release" 3>/dev/null
[[ -e "${scratch}/post-release" ]]

python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    -- /usr/bin/sleep 30 3>"${scratch}/killed-ready" &
holder_pid=$!
wait_for_readiness "${holder_pid}" "${scratch}/killed-ready"

set +e
python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    -- /usr/bin/touch "${scratch}/blocked-during-command" \
    3>/dev/null 2>"${scratch}/contender.err"
contender_status=$?
set -e
[[ "${contender_status}" -eq 75 ]]
[[ ! -e "${scratch}/blocked-during-command" ]]

kill -KILL "${holder_pid}"
set +e
wait "${holder_pid}" 2>/dev/null
killed_status=$?
set -e
[[ "${killed_status}" -eq 137 ]]
holder_pid=""

python3 "${OWNER_LOCK}" --socket-name "${socket_name}" \
    -- /usr/bin/touch "${scratch}/post-kill" 3>/dev/null
[[ -e "${scratch}/post-kill" ]]

printf 'PASS: atomic OTBR ownership contention and release\n'
