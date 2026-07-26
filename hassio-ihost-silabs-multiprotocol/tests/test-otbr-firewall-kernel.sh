#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly LOCK_PROBE_PATH="/usr/local/libexec/otbr-lock-probe"
readonly SYSTEM_PATH="${PATH}"
readonly FOREIGN_CHAIN="OTBR-FOREIGN-SENTINEL"
readonly FOREIGN_IPSET="otbr-foreign-sentinel"
readonly FOREIGN_IP="fd00:cafe::1"
readonly FOREIGN_FORWARD_POLICY="DROP"

# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON_SCRIPT}"

xtables_lock_pid=""
original_path=""
original_forward_policy=""

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

cleanup_foreign_state()
{
    if ip6tables -w 1 -C FORWARD -i lo \
        -j "${FOREIGN_CHAIN}" >/dev/null 2>&1; then
        ip6tables -w 1 -D FORWARD -i lo -j "${FOREIGN_CHAIN}"
    fi
    if ip6tables -w 1 -L "${FOREIGN_CHAIN}" -n >/dev/null 2>&1; then
        ip6tables -w 1 -F "${FOREIGN_CHAIN}"
        ip6tables -w 1 -X "${FOREIGN_CHAIN}"
    fi
    if ipset list "${FOREIGN_IPSET}" >/dev/null 2>&1; then
        ipset destroy "${FOREIGN_IPSET}"
    fi
    if [[ -n "${original_forward_policy}" ]]; then
        ip6tables -w 1 -P FORWARD "${original_forward_policy}"
    fi
}

best_effort_cleanup()
{
    set +e
    release_xtables_lock
    if [[ -n "${original_path}" ]]; then
        PATH="${original_path}"
        export PATH
        original_path=""
    fi
    unset XTABLES_LOCKFILE
    PATH="${SYSTEM_PATH}"
    otbr_cleanup_budget_milliseconds=4000
    otbr_firewall_cleanup >/dev/null 2>&1 || true
    cleanup_foreign_state >/dev/null 2>&1
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

assert_foreign_state_preserved()
{
    local forward_policy

    ip6tables -w 1 -C FORWARD -i lo -j "${FOREIGN_CHAIN}" \
        || fail "unrelated FORWARD jump was removed"
    ip6tables -w 1 -C "${FOREIGN_CHAIN}" \
        -m set --match-set "${FOREIGN_IPSET}" src -j ACCEPT \
        || fail "unrelated chain rule was removed"
    ipset test "${FOREIGN_IPSET}" "${FOREIGN_IP}" >/dev/null 2>&1 \
        || fail "unrelated IPv6 ipset entry was removed"

    forward_policy="$(
        ip6tables -w 1 -S FORWARD \
            | awk '$1 == "-P" { print $3 }'
    )"
    [[ "${forward_policy}" == "${FOREIGN_FORWARD_POLICY}" ]] \
        || fail "FORWARD policy changed to ${forward_policy}"
}

forward_jump_count()
{
    local interface_flag="$1"
    local chain_name="$2"

    ip6tables -w 1 -S FORWARD \
        | awk -v needle="${interface_flag} ${thread_if} -j ${chain_name}" \
            'index($0, needle) { count++ } END { print count + 0 }'
}

for command_name in awk flock ip6tables ipset timeout; do
    command -v "${command_name}" >/dev/null \
        || fail "required command ${command_name} is unavailable"
done
[[ -x "${LOCK_PROBE_PATH}/ip6tables" ]] \
    || fail "required ip6tables lock probe is unavailable"

[[ "$(ip6tables --version)" == *"nf_tables"* ]] \
    || fail "kernel smoke test requires the nft-backed iptables frontend"

# Seed unrelated host-owned netfilter state. Every lifecycle transition must
# leave this chain, jump, ipset, and deliberately restrictive policy intact.
original_forward_policy="$(
    ip6tables -w 1 -S FORWARD \
        | awk '$1 == "-P" { print $3 }'
)"
[[ -n "${original_forward_policy}" ]] \
    || fail "could not capture the original FORWARD policy"
ipset create "${FOREIGN_IPSET}" hash:ip family inet6
ipset add "${FOREIGN_IPSET}" "${FOREIGN_IP}"
ip6tables -w 1 -N "${FOREIGN_CHAIN}"
ip6tables -w 1 -A "${FOREIGN_CHAIN}" \
    -m set --match-set "${FOREIGN_IPSET}" src -j ACCEPT
ip6tables -w 1 -I FORWARD 1 -i lo -j "${FOREIGN_CHAIN}"
ip6tables -w 1 -P FORWARD "${FOREIGN_FORWARD_POLICY}"
assert_foreign_state_preserved

# Absent state is a successful, idempotent cleanup.
otbr_firewall_cleanup
otbr_firewall_cleanup
assert_absent
assert_foreign_state_preserved

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
assert_foreign_state_preserved
otbr_firewall_cleanup
assert_absent
assert_foreign_state_preserved

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
assert_foreign_state_preserved

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
assert_foreign_state_preserved

# Some iptables-nft builds skip the historical global lock. Put a narrow probe
# shim in PATH for this case so -w contention is deterministic while the real
# ip6tables binary still performs every operation after acquiring the lock.
# The outer timeout must bound the wait and return control promptly.
otbr_firewall_setup true
export XTABLES_LOCKFILE=/tmp/otbr-xtables-probe.lock
rm -f "${XTABLES_LOCKFILE}" /tmp/otbr-xtables-lock-ready
original_path="${PATH}"
PATH="${LOCK_PROBE_PATH}:${PATH}"
export PATH

flock --exclusive --no-fork "${XTABLES_LOCKFILE}" \
    sh -c 'touch /tmp/otbr-xtables-lock-ready; exec sleep 10' &
xtables_lock_pid=$!

for ((attempt = 0; attempt < 100; attempt++)); do
    [[ -e /tmp/otbr-xtables-lock-ready ]] && break
    sleep 0.01
done
[[ -e /tmp/otbr-xtables-lock-ready ]] \
    || fail "could not acquire the xtables lock for the bounded-wait test"

otbr_cleanup_budget_milliseconds=500
_otbr_clock_milliseconds \
    || fail "could not read the monotonic clock before lock test"
lock_test_started="${REPLY}"
if otbr_firewall_cleanup; then
    fail "cleanup unexpectedly succeeded while the xtables lock was held"
fi
_otbr_clock_milliseconds \
    || fail "could not read the monotonic clock after lock test"
lock_test_elapsed=$((REPLY - lock_test_started))
(( lock_test_elapsed >= 300 )) \
    || fail "xtables lock cleanup returned too early after ${lock_test_elapsed}ms"
(( lock_test_elapsed < 2500 )) \
    || fail "xtables lock cleanup took ${lock_test_elapsed}ms"

release_xtables_lock
PATH="${original_path}"
export PATH
original_path=""
unset XTABLES_LOCKFILE
ip6tables -w 1 -L "${otbr_forward_ingress_chain}" -n >/dev/null 2>&1 \
    || fail "firewall state vanished while xtables was locked"
assert_foreign_state_preserved

otbr_cleanup_budget_milliseconds=4000
otbr_firewall_cleanup
assert_absent
assert_foreign_state_preserved

cleanup_foreign_state
trap - EXIT
printf 'PASS: real-kernel OTBR firewall lifecycle\n'
