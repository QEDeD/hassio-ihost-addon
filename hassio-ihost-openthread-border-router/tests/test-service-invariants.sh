#!/bin/bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly COMMON="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"

bash -n "${COMMON}" "${RUN}" "${FINISH}"

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

backbone_line=$(grep -n 'backbone_if="eth0"' "${RUN}" | head -n1 | cut -d: -f1)
cleanup_line=$(grep -n 'otbr_netfilter_cleanup "${backbone_if}"' "${RUN}" | head -n1 | cut -d: -f1)
setup_line=$(grep -n 'otbr_firewall_setup' "${RUN}" | head -n1 | cut -d: -f1)
(( backbone_line < cleanup_line && cleanup_line < setup_line ))

grep -q 'otbr_netfilter_cleanup' "${FINISH}"
grep -qE '^[[:space:]]*-[[:space:]]+armv7[[:space:]]*$' "${ADDON_DIR}/config.yaml"

# All four configuration combinations are represented by independent Boolean
# setup paths. Verify the source keeps both branches and makes NAT64 optional.
grep -q "bashio::config.true 'firewall'" "${RUN}"
grep -q "bashio::config.true 'nat64'" "${RUN}"
grep -q 'otbr_firewall_setup "${firewall_enabled}"' "${RUN}"
grep -q 'otbr_nat64_setup "${backbone_if}"' "${RUN}"

printf 'PASS: standalone OTBR service invariants\n'
