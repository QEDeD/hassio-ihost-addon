#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly DOCKERFILE="${ADDON_DIR}/Dockerfile"
readonly RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"
readonly AGENT_CHECK="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/data/check"
readonly TIMEOUT_FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish"
readonly WEB_CONFIG_DEPENDENCY="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-web/dependencies.d/otbr-agent-configure"
readonly SPINEL_RECOVERY_PATCH="${ADDON_DIR}/0002-spinel-Clear-source-match-tables-before-restoring.patch"
readonly NAT64_OPTIONS_PATCH="${ADDON_DIR}/0003-nat64-handle-ipv4-options.patch"

bash -n "${COMMON}" "${RUN}" "${FINISH}" "${AGENT_CHECK}"
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
claim_reset_line=$(grep -n '^if ! otbr_firewall_cleanup_claim_reset; then' "${RUN}" | cut -d: -f1)
guard_line=$(grep -n '^if ! otbr_firewall_cleanup_is_safe; then' "${RUN}" | cut -d: -f1)
claim_create_line=$(grep -n '^if ! otbr_firewall_cleanup_claim_create; then' "${RUN}" | cut -d: -f1)
cleanup_line=$(grep -n '^if ! otbr_netfilter_cleanup; then' "${RUN}" | head -n1 | cut -d: -f1)
setup_line=$(grep -n 'otbr_firewall_setup' "${RUN}" | head -n1 | cut -d: -f1)
(( claim_reset_line < guard_line \
    && guard_line < claim_create_line \
    && claim_create_line < cleanup_line \
    && cleanup_line < api_line \
    && api_line < setup_line ))

grep -q 'otbr_netfilter_cleanup' "${FINISH}"
grep -q 'otbr_firewall_cleanup_claim_consume' "${FINISH}"
grep -q '^otbr_firewall_cleanup_is_safe()$' "${COMMON}"
grep -q '^otbr_firewall_cleanup_claim_consume()$' "${COMMON}"
grep -qE '^[[:space:]]*-[[:space:]]+armv7[[:space:]]*$' "${ADDON_DIR}/config.yaml"
grep -Fqx 'version: 2.13.0' "${ADDON_DIR}/config.yaml"
if grep -qE '^(host_ipc|stage):' "${ADDON_DIR}/config.yaml"; then
    echo 'default-valued host_ipc or stage metadata must be omitted' >&2
    exit 1
fi
grep -Fqx '  device: device(subsystem=tty)?' "${ADDON_DIR}/config.yaml"
grep -Fqx \
    '  baudrate: list(57600|115200|230400|460800|921600|1000000)' \
    "${ADDON_DIR}/config.yaml"
grep -Fqx '  backbone_interface: str?' "${ADDON_DIR}/config.yaml"
options_block="$(sed -n '/^options:/,/^ports:/p' "${ADDON_DIR}/config.yaml")"
[[ "${options_block}" != *"backbone_interface"* ]]

grep -Fqx '# check=error=true' "${DOCKERFILE}"
grep -Fqx \
    'ARG BUILD_FROM=ghcr.io/home-assistant/armv7-base-debian:bookworm' \
    "${DOCKERFILE}"
grep -Fqx 'ARG BUILD_IMAGE_PLATFORM=linux/arm/v7' "${DOCKERFILE}"
grep -Fqx 'FROM --platform=${BUILD_IMAGE_PLATFORM} $BUILD_FROM' "${DOCKERFILE}"
copy_rootfs_line=$(grep -n '^COPY rootfs /$' "${DOCKERFILE}" | cut -d: -f1)
for build_arg in BUILD_ARCH BUILD_COMMIT BUILD_VERSION; do
    build_arg_line=$(grep -n "^ARG ${build_arg}$" "${DOCKERFILE}" | cut -d: -f1)
    (( build_arg_line > copy_rootfs_line ))
    grep -Fq "test -n \"\${${build_arg}}\"" "${DOCKERFILE}"
done
source_assert_line=$(grep -n 'test -n "${OTBR_VERSION}"' "${DOCKERFILE}" | cut -d: -f1)
apt_line=$(grep -n 'apt-get update' "${DOCKERFILE}" | cut -d: -f1)
(( source_assert_line < apt_line ))
grep -Fq 'test -n "${UNIVERSAL_SILABS_FLASHER}"' "${DOCKERFILE}"
grep -Fqx '    io.hass.version="${BUILD_VERSION}" \' "${DOCKERFILE}"
grep -Fqx '    io.hass.type="app" \' "${DOCKERFILE}"
grep -Fqx '    io.hass.arch="${BUILD_ARCH}" \' "${DOCKERFILE}"
grep -Fqx \
    '    org.opencontainers.image.version="${BUILD_VERSION}" \' \
    "${DOCKERFILE}"
grep -Fqx \
    '    org.opencontainers.image.source="https://github.com/iHost-Open-Source-Project/hassio-ihost-addon" \' \
    "${DOCKERFILE}"
grep -Fqx \
    '    org.opencontainers.image.revision="${BUILD_COMMIT}"' \
    "${DOCKERFILE}"

[[ "$(sha256sum "${SPINEL_RECOVERY_PATCH}" | cut -d' ' -f1)" \
    == "19f6d7c5ba2166a9d3e7089bb50c3ee2c072d482327600e49cfc27405612cf32" ]]
[[ "$(sha256sum "${NAT64_OPTIONS_PATCH}" | cut -d' ' -f1)" \
    == "0731cfca9613528d12037255400619a2331c424f512fb0a737a9655a423c96ed" ]]
grep -Fq \
    '/usr/src/0002-spinel-Clear-source-match-tables-before-restoring.patch' \
    "${DOCKERFILE}"
grep -Fq \
    '/usr/src/0003-nat64-handle-ipv4-options.patch' \
    "${DOCKERFILE}"
grep -Fq 'IgnoreError(ClearSrcMatchShortEntries());' "${DOCKERFILE}"
grep -Fq 'VerifyOrExit(!HasSourceRouteOption(aMessage));' "${DOCKERFILE}"
grep -Fq \
    'aMessage.RemoveHeader(ip4Header.GetHeaderLength());' \
    "${DOCKERFILE}"
grep -Fq \
    'ip4Header.GetTotalLength() - ip4Header.GetHeaderLength());' \
    "${DOCKERFILE}"

# This pinned tree predates Ip4::Headers: its translator removes the IPv4
# header before transport parsing. Retain every applicable upstream security
# contract plus dynamic payload accounting in both old-tree counter paths.
grep -Fqx '+#include "common/offset_range.hpp"' "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+        return IsVersion4() && (GetIhl() >= kMinIhl) && (GetHeaderLength() <= GetTotalLength());' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+        VerifyOrExit(!HasSourceRouteOption(aMessage));' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+        if (optionType == kOptionLsrr || optionType == kOptionSsrr)' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+    aMessage.RemoveHeader(ip4Header.GetHeaderLength());' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+                              ip4Header.GetTotalLength() - ip4Header.GetHeaderLength());' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx \
    '+                                       ip4Header.GetTotalLength() - ip4Header.GetHeaderLength());' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx -- \
    '-    mCounters.Count4To6Packet(ip4Header.GetProtocol(), ip4Header.GetTotalLength() - sizeof(ip4Header));' \
    "${NAT64_OPTIONS_PATCH}"
grep -Fqx -- \
    '-    mapping->mCounters.Count4To6Packet(ip4Header.GetProtocol(), ip4Header.GetTotalLength() - sizeof(ip4Header));' \
    "${NAT64_OPTIONS_PATCH}"
! grep -Fq \
    '+    mCounters.Count4To6Packet(ip4Header.GetProtocol(), ip4Header.GetTotalLength() - sizeof(ip4Header));' \
    "${NAT64_OPTIONS_PATCH}"
! grep -Fq \
    '+    mapping->mCounters.Count4To6Packet(ip4Header.GetProtocol(), ip4Header.GetTotalLength() - sizeof(ip4Header));' \
    "${NAT64_OPTIONS_PATCH}"

[[ -e "${WEB_CONFIG_DEPENDENCY}" ]]
check_set_e_line=$(grep -n '^set -e$' "${AGENT_CHECK}" | cut -d: -f1)
check_socket_line=$(grep -n '^test -S /run/openthread-wpan0.sock$' "${AGENT_CHECK}" | cut -d: -f1)
check_mapfile_line=$(grep -n '^mapfile -t < /tmp/otbr-agent-rest-api$' "${AGENT_CHECK}" | cut -d: -f1)
check_rest_line=$(grep -n '^nc -z ' "${AGENT_CHECK}" | cut -d: -f1)
(( check_set_e_line < check_socket_line \
    && check_socket_line < check_mapfile_line \
    && check_mapfile_line < check_rest_line ))

[[ -f "${TIMEOUT_FINISH}" ]]
finish_timeout_milliseconds=$(<"${TIMEOUT_FINISH}")
[[ "${finish_timeout_milliseconds}" =~ ^[0-9]+$ ]]
(( finish_timeout_milliseconds \
    >= otbr_cleanup_budget_milliseconds + 3000 ))

printf 'PASS: standalone OTBR service invariants\n'
