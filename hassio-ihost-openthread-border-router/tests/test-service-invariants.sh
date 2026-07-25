#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"
readonly TIMEOUT_FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish"

bash -n "${COMMON}" "${RUN}" "${FINISH}"
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON}"

if grep -RqsE 'ip6tables-legacy|ip6tables[[:space:]]+-P[[:space:]]+FORWARD' \
    "${COMMON}" "${RUN}" "${FINISH}"; then
    echo 'obsolete IPv6 forwarding command remains' >&2
    exit 1
fi

if grep -RqsE 'iptables[[:space:]].*-A[[:space:]]+FORWARD[[:space:]]+(-i|-o)' \
    "${COMMON}" "${RUN}" "${FINISH}"; then
    echo 'broad direct NAT64 FORWARD rule remains' >&2
    exit 1
fi

api_line=$(grep -n 'bashio::api.supervisor' "${RUN}" | head -n1 | cut -d: -f1)
cleanup_line=$(grep -n '^if ! otbr_netfilter_cleanup; then' "${RUN}" | head -n1 | cut -d: -f1)
setup_line=$(grep -n 'otbr_firewall_setup' "${RUN}" | head -n1 | cut -d: -f1)
(( cleanup_line < api_line && api_line < setup_line ))

grep -q 'otbr_netfilter_cleanup' "${FINISH}"
grep -qE '^[[:space:]]*-[[:space:]]+armv7[[:space:]]*$' "${ADDON_DIR}/config.yaml"

[[ -f "${TIMEOUT_FINISH}" ]]
finish_timeout_milliseconds=$(<"${TIMEOUT_FINISH}")
[[ "${finish_timeout_milliseconds}" =~ ^[0-9]+$ ]]
(( finish_timeout_milliseconds \
    >= otbr_cleanup_budget_milliseconds + 3000 ))

printf 'PASS: standalone OTBR service invariants\n'
