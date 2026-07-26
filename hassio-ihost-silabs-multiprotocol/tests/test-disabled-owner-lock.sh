#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly OWNER_LOCK="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-owner-lock.py"
readonly ENABLE_CHECK="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-enable-check.sh"
TOUCH_COMMAND="$(command -v touch)"
readonly TOUCH_COMMAND

scratch="$(mktemp -d)"
holder_pid=""

cleanup()
{
    if [[ -n "${holder_pid}" ]] && kill -0 "${holder_pid}" 2>/dev/null; then
        kill -KILL "${holder_pid}" 2>/dev/null || true
        wait "${holder_pid}" 2>/dev/null || true
    fi
    rm -f "${scratch}/cleanup-ran" "${scratch}/ready"
    rmdir "${scratch}"
}
trap cleanup EXIT

wait_for_readiness()
{
    local attempt

    for ((attempt = 0; attempt < 200; attempt++)); do
        if [[ -s "${scratch}/ready" ]]; then
            return 0
        fi
        if ! kill -0 "${holder_pid}" 2>/dev/null; then
            echo "ownership helper exited before reporting readiness" >&2
            return 1
        fi
        sleep 0.01
    done
    echo "ownership helper did not report readiness" >&2
    return 1
}

run_disabled_path()
{
    local script

    script="$(
        sed \
            -e "s#/etc/s6-overlay/scripts/otbr-owner-lock.py#${OWNER_LOCK}#" \
            -e "s#/etc/s6-overlay/scripts/otbr-disabled-cleanup.sh#${TOUCH_COMMAND} ${scratch}/cleanup-ran#" \
            "${ENABLE_CHECK}"
    )"

    (
        function bashio::config.false() { return 0; }
        function bashio::log.info() { printf 'INFO:%s\n' "$*"; }
        function bashio::log.warning() { printf 'WARNING:%s\n' "$*"; }
        function bashio::exit.ok() {
            printf 'EXIT_OK\n'
            exit 0
        }
        function rm() { printf 'REMOVE:%s\n' "$1"; }

        eval "${script}"
    )
}

assert_disabled_success()
{
    local output="$1"

    grep -Fq 'EXIT_OK' <<<"${output}"
    grep -Fq \
        'REMOVE:/etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent' \
        <<<"${output}"
    grep -Fq \
        'REMOVE:/etc/s6-overlay/s6-rc.d/user/contents.d/otbr-web' \
        <<<"${output}"
    grep -Fq \
        'REMOVE:/etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent-rest-discovery' \
        <<<"${output}"
    grep -Fq \
        'REMOVE:/etc/s6-overlay/s6-rc.d/user/contents.d/mdns' \
        <<<"${output}"
    if grep -Fq 'contents.d/zigbeed' <<<"${output}"; then
        echo "disabled OTBR path removed a Zigbee service" >&2
        return 1
    fi
}

python3 "${OWNER_LOCK}" 3>"${scratch}/ready" &
holder_pid=$!
wait_for_readiness

conflict_output="$(run_disabled_path 2>&1)"
assert_disabled_success "${conflict_output}"
grep -Fq \
    'Skipping stale OTBR firewall cleanup: another OTBR add-on owns the host-network resources.' \
    <<<"${conflict_output}"
[[ ! -e "${scratch}/cleanup-ran" ]]

kill -TERM "${holder_pid}"
wait "${holder_pid}"
holder_pid=""

released_output="$(run_disabled_path 2>&1)"
assert_disabled_success "${released_output}"
[[ -e "${scratch}/cleanup-ran" ]]
if grep -Fq 'another OTBR add-on owns' <<<"${released_output}"; then
    echo "released ownership gate still reported a conflict" >&2
    exit 1
fi

printf 'PASS: disabled OTBR cleanup respects cross-add-on ownership\n'
