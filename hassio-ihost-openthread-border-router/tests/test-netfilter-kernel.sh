#!/bin/bash
set -euo pipefail

readonly COMMON=/usr/local/lib/otbr-agent-common
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1091
source "${COMMON}"

readonly keep_chain_v4=OTBR_SMOKE_KEEP4
readonly keep_chain_v6=OTBR_SMOKE_KEEP6
readonly keep_ipset=otbr-smoke-keep
readonly reference_chain=OTBR_SMOKE_REF6
readonly legacy_backbone_if=legacy0
readonly lock_probe_path=/usr/local/libexec/otbr-lock-probe
declare lock_pid=""
declare original_path=""

fail()
{
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

expect_success()
{
    local message="$1"
    shift
    "$@" >/dev/null 2>&1 || fail "${message}"
}

expect_failure()
{
    local message="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "${message}"
    fi
}

assert_nat64_absent()
{
    expect_failure "NAT64 chain remains" \
        iptables -t filter -L "${otbr_forward_nat64_chain}" -n
    expect_failure "NAT64 FORWARD jump remains" \
        iptables -t filter -C FORWARD -j "${otbr_forward_nat64_chain}"
    expect_failure "NAT64 MARK rule remains" \
        iptables -t mangle -C PREROUTING -i "${thread_if}" \
        -j MARK --set-mark "${otbr_fw_mark}"
    expect_failure "NAT64 MASQUERADE rule remains" \
        iptables -t nat -C POSTROUTING \
        -m mark --mark "${otbr_fw_mark}" -j MASQUERADE
}

assert_firewall_absent()
{
    local ipset_name

    expect_failure "IPv6 ingress chain remains" \
        ip6tables -L "${otbr_forward_ingress_chain}" -n
    expect_failure "IPv6 egress chain remains" \
        ip6tables -L "${otbr_forward_egress_chain}" -n
    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        expect_failure "owned ipset ${ipset_name} remains" \
            ipset list "${ipset_name}"
    done
}

assert_owned_absent()
{
    assert_nat64_absent
    assert_firewall_absent
}

assert_sentinels_present()
{
    expect_success "unrelated IPv4 chain was removed" \
        iptables -t filter -L "${keep_chain_v4}" -n
    expect_success "unrelated IPv4 jump was removed" \
        iptables -t filter -C FORWARD -j "${keep_chain_v4}"
    expect_success "unrelated IPv6 chain was removed" \
        ip6tables -L "${keep_chain_v6}" -n
    expect_success "unrelated IPv6 jump was removed" \
        ip6tables -C FORWARD -j "${keep_chain_v6}"
    expect_success "unrelated ipset was removed" ipset list "${keep_ipset}"
}

cleanup_smoke()
{
    trap - EXIT
    set +e

    if [[ -n "${lock_pid}" ]]; then
        kill "${lock_pid}" >/dev/null 2>&1
        wait "${lock_pid}" >/dev/null 2>&1
        lock_pid=""
    fi
    if [[ -n "${original_path}" ]]; then
        PATH="${original_path}"
        export PATH
        original_path=""
    fi
    unset XTABLES_LOCKFILE

    ip6tables -w 1 -F "${reference_chain}" >/dev/null 2>&1
    ip6tables -w 1 -X "${reference_chain}" >/dev/null 2>&1

    otbr_cleanup_budget_milliseconds=4000
    otbr_ipset_destroy_attempts=20
    otbr_netfilter_cleanup >/dev/null 2>&1

    ip6tables -w 1 -D FORWARD -j "${keep_chain_v6}" >/dev/null 2>&1
    ip6tables -w 1 -F "${keep_chain_v6}" >/dev/null 2>&1
    ip6tables -w 1 -X "${keep_chain_v6}" >/dev/null 2>&1
    iptables -w 1 -t filter -D FORWARD \
        -j "${keep_chain_v4}" >/dev/null 2>&1
    iptables -w 1 -t filter -F "${keep_chain_v4}" >/dev/null 2>&1
    iptables -w 1 -t filter -X "${keep_chain_v4}" >/dev/null 2>&1
    ipset destroy "${keep_ipset}" >/dev/null 2>&1
}
trap cleanup_smoke EXIT

# Empty teardown is deliberately repeatable, including iptables-nft's
# nonzero probe result when a referenced custom target does not exist.
otbr_netfilter_cleanup
otbr_netfilter_cleanup
assert_owned_absent

# These unrelated objects prove cleanup is limited to exact owned names and
# signatures.
ip6tables -w "${otbr_iptables_wait_seconds}" -N "${keep_chain_v6}"
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -A "${keep_chain_v6}" -j RETURN
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -I FORWARD 1 -j "${keep_chain_v6}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -N "${keep_chain_v4}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -A "${keep_chain_v4}" -j RETURN
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -I FORWARD 1 -j "${keep_chain_v4}"
ipset create "${keep_ipset}" hash:net family inet6

otbr_firewall_setup true
otbr_nat64_setup eth0

for ipset_name in "${otbr_firewall_ipsets[@]}"; do
    expect_success "firewall setup omitted ${ipset_name}" \
        ipset list "${ipset_name}"
done
expect_success "firewall setup omitted ingress chain" \
    ip6tables -L "${otbr_forward_ingress_chain}" -n
expect_success "firewall setup omitted egress chain" \
    ip6tables -L "${otbr_forward_egress_chain}" -n
expect_success "firewall setup omitted ingress jump" \
    ip6tables -C FORWARD -o "${thread_if}" \
    -j "${otbr_forward_ingress_chain}"
expect_success "firewall setup omitted egress jump" \
    ip6tables -C FORWARD -i "${thread_if}" \
    -j "${otbr_forward_egress_chain}"
expect_success "NAT64 setup omitted chain" \
    iptables -t filter -L "${otbr_forward_nat64_chain}" -n
expect_success "NAT64 setup omitted jump" \
    iptables -t filter -C FORWARD -j "${otbr_forward_nat64_chain}"
expect_success "NAT64 setup omitted MARK" \
    iptables -t mangle -C PREROUTING -i "${thread_if}" \
    -j MARK --set-mark "${otbr_fw_mark}"
expect_success "NAT64 setup omitted MASQUERADE" \
    iptables -t nat -C POSTROUTING \
    -m mark --mark "${otbr_fw_mark}" -j MASQUERADE

# Seed duplicate rules that can be left by interrupted startup attempts.
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -I FORWARD 1 -o "${thread_if}" -j "${otbr_forward_ingress_chain}"
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -I FORWARD 1 -i "${thread_if}" -j "${otbr_forward_egress_chain}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -I FORWARD 1 -j "${otbr_forward_nat64_chain}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t mangle -A PREROUTING -i "${thread_if}" \
    -j MARK --set-mark "${otbr_fw_mark}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t nat -A POSTROUTING -m mark --mark "${otbr_fw_mark}" -j MASQUERADE

# A foreign chain keeps the first owned ipset referenced. Its repeated EBUSY
# destroy failures must not consume the deadline before NAT64 is removed.
ip6tables -w "${otbr_iptables_wait_seconds}" -N "${reference_chain}"
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -A "${reference_chain}" \
    -m set --match-set otbr-ingress-deny-src src -j RETURN
otbr_cleanup_budget_milliseconds=750
otbr_ipset_destroy_attempts=100
if otbr_netfilter_cleanup; then
    fail "cleanup unexpectedly destroyed a referenced ipset"
fi
assert_nat64_absent
expect_success "referenced ipset was unexpectedly destroyed" \
    ipset list otbr-ingress-deny-src
assert_sentinels_present

ip6tables -w "${otbr_iptables_wait_seconds}" -F "${reference_chain}"
ip6tables -w "${otbr_iptables_wait_seconds}" -X "${reference_chain}"
otbr_cleanup_budget_milliseconds=4000
otbr_ipset_destroy_attempts=20
otbr_netfilter_cleanup
otbr_netfilter_cleanup
assert_owned_absent
assert_sentinels_present

# Exercise migration of the unambiguous broad rules emitted by version 2.13.0.
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -A FORWARD -i "${legacy_backbone_if}" -j ACCEPT
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -A FORWARD -o "${legacy_backbone_if}" -j ACCEPT
iptables -w "${otbr_iptables_wait_seconds}" \
    -t mangle -A PREROUTING -i "${thread_if}" \
    -j MARK --set-mark "${otbr_fw_mark}"
iptables -w "${otbr_iptables_wait_seconds}" \
    -t nat -A POSTROUTING -m mark --mark "${otbr_fw_mark}" -j MASQUERADE
otbr_nat64_cleanup
expect_failure "legacy ingress ACCEPT remains" \
    iptables -t filter -C FORWARD \
    -i "${legacy_backbone_if}" -j ACCEPT
expect_failure "legacy egress ACCEPT remains" \
    iptables -t filter -C FORWARD \
    -o "${legacy_backbone_if}" -j ACCEPT
assert_nat64_absent
assert_sentinels_present

# Some iptables-nft builds skip the historical global lock. Put a narrow probe
# shim in PATH for this case so -w contention is deterministic while the real
# iptables binary still performs every operation after acquiring the lock.
# The outer timeout must bound the wait and return control promptly.
otbr_nat64_setup eth0
export XTABLES_LOCKFILE=/tmp/otbr-xtables-probe.lock
rm -f "${XTABLES_LOCKFILE}" /tmp/otbr-xtables-lock-ready
original_path="${PATH}"
PATH="${lock_probe_path}:${PATH}"
export PATH
flock --exclusive --no-fork "${XTABLES_LOCKFILE}" \
    sh -c 'touch /tmp/otbr-xtables-lock-ready; exec sleep 10' &
lock_pid=$!
for ((attempt = 0; attempt < 100; attempt++)); do
    [[ -e /tmp/otbr-xtables-lock-ready ]] && break
    sleep 0.01
done
[[ -e /tmp/otbr-xtables-lock-ready ]] \
    || fail "could not acquire the xtables lock for the bounded-wait test"

otbr_cleanup_budget_milliseconds=500
_otbr_now_milliseconds || fail "could not read monotonic time"
start_milliseconds="${otbr_now_milliseconds}"
if otbr_nat64_cleanup >/dev/null 2>&1; then
    fail "NAT64 cleanup unexpectedly succeeded while xtables was locked"
fi
_otbr_now_milliseconds || fail "could not read monotonic time"
elapsed_milliseconds=$((otbr_now_milliseconds - start_milliseconds))
(( elapsed_milliseconds >= 300 )) \
    || fail "xtables lock test returned too quickly (${elapsed_milliseconds}ms)"
(( elapsed_milliseconds < 2500 )) \
    || fail "xtables lock exceeded its bound (${elapsed_milliseconds}ms)"

kill "${lock_pid}"
wait "${lock_pid}" >/dev/null 2>&1 || true
lock_pid=""
PATH="${original_path}"
export PATH
original_path=""
unset XTABLES_LOCKFILE
expect_success "NAT64 state vanished while xtables was locked" \
    iptables -t filter -L "${otbr_forward_nat64_chain}" -n

otbr_cleanup_budget_milliseconds=4000
otbr_nat64_cleanup
assert_owned_absent
assert_sentinels_present

printf 'PASS: real-kernel standalone OTBR netfilter lifecycle\n'
