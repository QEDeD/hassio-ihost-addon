#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly SYSTEM_PATH="${PATH}"

# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON_SCRIPT}"

xtables_lock_pid=""

fail()
{
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

release_xtables_lock()
{
    if [[ -n "${xtables_lock_pid}" ]] \
        && kill -0 "${xtables_lock_pid}" 2>/dev/null; then
        kill "${xtables_lock_pid}" 2>/dev/null || true
    fi
    if [[ -n "${xtables_lock_pid}" ]]; then
        wait "${xtables_lock_pid}" 2>/dev/null || true
    fi
    xtables_lock_pid=""
}

best_effort_cleanup()
{
    release_xtables_lock
    PATH="${SYSTEM_PATH}"
    otbr_firewall_cleanup >/dev/null 2>&1 || true
}

trap best_effort_cleanup EXIT

assert_absent()
{
    local chain_name
    local ipset_name

    for chain_name in \
        "${otbr_forward_ingress_chain}" \
        "${otbr_forward_egress_chain}"; do
        if ip6tables -w 1 -L "${chain_name}" -n >/dev/null 2>&1; then
            fail "chain ${chain_name} still exists"
        fi
    done

    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        if ipset list "${ipset_name}" >/dev/null 2>&1; then
            fail "ipset ${ipset_name} still exists"
        fi
    done
}

assert_chain_rule_count()
{
    local chain_name="$1"
    local expected="$2"
    local actual

    actual="$(
        ip6tables -w 1 -S "${chain_name}" \
            | awk '$1 == "-A" { count++ } END { print count + 0 }'
    )"
    [[ "${actual}" == "${expected}" ]] \
        || fail "${chain_name} has ${actual} rules; expected ${expected}"
}

forward_jump_count()
{
    local interface_flag="$1"
    local chain_name="$2"

    ip6tables -w 1 -S FORWARD \
        | awk -v needle="${interface_flag} ${thread_if} -j ${chain_name}" \
            'index($0, needle) { count++ } END { print count + 0 }'
}

for command_name in awk flock ip6tables ip6tables-legacy ipset timeout; do
    command -v "${command_name}" >/dev/null \
        || fail "required command ${command_name} is unavailable"
done

[[ "$(ip6tables --version)" == *"nf_tables"* ]] \
    || fail "kernel smoke test requires the nft-backed iptables frontend"

# Absent state is a successful, idempotent cleanup.
otbr_firewall_cleanup
otbr_firewall_cleanup
assert_absent

# Filtering-enabled setup creates every owned object and the full ingress
# policy, then teardown removes all of it.
otbr_firewall_setup true
for ipset_name in "${otbr_firewall_ipsets[@]}"; do
    ipset list "${ipset_name}" >/dev/null \
        || fail "enabled setup did not create ${ipset_name}"
done
ip6tables -w 1 -C FORWARD -o "${thread_if}" \
    -j "${otbr_forward_ingress_chain}"
ip6tables -w 1 -C FORWARD -i "${thread_if}" \
    -j "${otbr_forward_egress_chain}"
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" \
    -m pkttype --pkt-type unicast -i "${thread_if}" -j DROP
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" \
    -m set --match-set otbr-ingress-deny-src src -j DROP
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" \
    -m set --match-set otbr-ingress-allow-dst dst -j ACCEPT
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" \
    -m pkttype --pkt-type unicast -j DROP
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" -j ACCEPT
ip6tables -w 1 -C "${otbr_forward_egress_chain}" -j ACCEPT
assert_chain_rule_count "${otbr_forward_ingress_chain}" 5
assert_chain_rule_count "${otbr_forward_egress_chain}" 1
otbr_firewall_cleanup
assert_absent

# Filtering-disabled setup remains interface-scoped and has only permissive
# rules in the two owned chains.
otbr_firewall_setup false
ip6tables -w 1 -C FORWARD -o "${thread_if}" \
    -j "${otbr_forward_ingress_chain}"
ip6tables -w 1 -C FORWARD -i "${thread_if}" \
    -j "${otbr_forward_egress_chain}"
ip6tables -w 1 -C "${otbr_forward_ingress_chain}" -j ACCEPT
ip6tables -w 1 -C "${otbr_forward_egress_chain}" -j ACCEPT
assert_chain_rule_count "${otbr_forward_ingress_chain}" 1
assert_chain_rule_count "${otbr_forward_egress_chain}" 1

# Teardown removes every duplicate owned jump, not only the first one.
ip6tables -w 1 -I FORWARD 1 -o "${thread_if}" \
    -j "${otbr_forward_ingress_chain}"
ip6tables -w 1 -I FORWARD 1 -i "${thread_if}" \
    -j "${otbr_forward_egress_chain}"
[[ "$(forward_jump_count -o "${otbr_forward_ingress_chain}")" == "2" ]] \
    || fail "duplicate ingress jump was not installed"
[[ "$(forward_jump_count -i "${otbr_forward_egress_chain}")" == "2" ]] \
    || fail "duplicate egress jump was not installed"
otbr_firewall_cleanup
assert_absent

# The nft frontend is atomic and treats -w as a no-op. Exercise the same cleanup
# path through the installed legacy frontend here so a real xtables lock can
# prove that the shared deadline bounds every blocking subprocess.
otbr_firewall_setup true
rm -f /tmp/xtables-lock-ready
mkdir -p /tmp/otbr-legacy-bin
ln -s "$(command -v ip6tables-legacy)" \
    /tmp/otbr-legacy-bin/ip6tables
PATH="/tmp/otbr-legacy-bin:${SYSTEM_PATH}"

flock --exclusive /run/xtables.lock \
    sh -c 'touch /tmp/xtables-lock-ready; exec sleep 30' &
xtables_lock_pid=$!

for ((attempt = 0; attempt < 100; attempt++)); do
    if [[ -e /tmp/xtables-lock-ready ]]; then
        break
    fi
    sleep 0.01
done
[[ -e /tmp/xtables-lock-ready ]] \
    || fail "could not acquire the xtables test lock"

_otbr_clock_milliseconds \
    || fail "could not read the monotonic clock before lock test"
lock_test_started="${REPLY}"
if otbr_firewall_cleanup; then
    fail "cleanup unexpectedly succeeded while the xtables lock was held"
fi
_otbr_clock_milliseconds \
    || fail "could not read the monotonic clock after lock test"
lock_test_elapsed=$((REPLY - lock_test_started))
lock_test_limit=$((otbr_cleanup_budget_milliseconds \
    + otbr_cleanup_kill_grace_milliseconds + 2000))
(( lock_test_elapsed <= lock_test_limit )) \
    || fail "xtables lock cleanup took ${lock_test_elapsed}ms"

release_xtables_lock
PATH="${SYSTEM_PATH}"
otbr_firewall_cleanup
assert_absent

trap - EXIT
printf 'PASS: real-kernel OTBR firewall lifecycle\n'
