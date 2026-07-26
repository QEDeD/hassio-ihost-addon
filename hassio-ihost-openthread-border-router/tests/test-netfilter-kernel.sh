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
readonly owned_reference_chain_v4=OTBR_SMOKE_OWNED_REF4
readonly owned_reference_chain_v6=OTBR_SMOKE_OWNED_REF6
readonly legacy_backbone_if=legacy0
readonly ambiguous_legacy_backbone_if=legacy1
readonly incomplete_legacy_backbone_if=legacy2
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

assert_ip6_chain_rules_exact()
{
    local chain_name="$1"
    local index
    local rule
    local -a actual=()
    local -a expected=()
    shift
    expected=("$@")

    while IFS= read -r rule; do
        if [[ "${rule}" == "-A ${chain_name} "* ]]; then
            actual+=("${rule#"-A ${chain_name} "}")
        fi
    done < <(ip6tables -S "${chain_name}")

    (( ${#actual[@]} == ${#expected[@]} )) \
        || fail "${chain_name} rule count differs from the exact expected list"
    for index in "${!expected[@]}"; do
        [[ "${actual[index]}" == "${expected[index]}" ]] \
            || fail "${chain_name} rule $((index + 1)) is '${actual[index]}', expected '${expected[index]}'"
    done
}

assert_iptables_chain_rules_exact()
{
    local table_name="$1"
    local chain_name="$2"
    local index
    local rule
    local -a actual=()
    local -a expected=()
    shift 2
    expected=("$@")

    while IFS= read -r rule; do
        if [[ "${rule}" == "-A ${chain_name} "* ]]; then
            actual+=("${rule#"-A ${chain_name} "}")
        fi
    done < <(iptables -t "${table_name}" -S "${chain_name}")

    (( ${#actual[@]} == ${#expected[@]} )) \
        || fail "${table_name}/${chain_name} rule count differs from the exact expected list"
    for index in "${!expected[@]}"; do
        [[ "${actual[index]}" == "${expected[index]}" ]] \
            || fail "${table_name}/${chain_name} rule $((index + 1)) is '${actual[index]}', expected '${expected[index]}'"
    done
}

assert_forward_jump_order()
{
    local rule
    local -a forward_v4=()
    local -a forward_v6=()

    while IFS= read -r rule; do
        [[ "${rule}" == "-A FORWARD "* ]] && forward_v4+=("${rule}")
    done < <(iptables -t filter -S FORWARD)
    while IFS= read -r rule; do
        [[ "${rule}" == "-A FORWARD "* ]] && forward_v6+=("${rule}")
    done < <(ip6tables -S FORWARD)

    [[ "${forward_v4[0]:-}" == "-A FORWARD -j ${otbr_forward_nat64_chain}" ]] \
        || fail "NAT64 jump is not first in IPv4 FORWARD"
    [[ "${forward_v6[0]:-}" == "-A FORWARD -o ${thread_if} -j ${otbr_forward_ingress_chain}" ]] \
        || fail "ingress jump is not first in IPv6 FORWARD"
    [[ "${forward_v6[1]:-}" == "-A FORWARD -i ${thread_if} -j ${otbr_forward_egress_chain}" ]] \
        || fail "egress jump is not second in IPv6 FORWARD"
}

assert_forward_policies_preserved()
{
    local policy_v4
    local policy_v6

    IFS= read -r policy_v4 < <(iptables -t filter -S FORWARD)
    IFS= read -r policy_v6 < <(ip6tables -S FORWARD)
    [[ "${policy_v4}" == "-P FORWARD DROP" ]] \
        || fail "IPv4 FORWARD policy changed: ${policy_v4}"
    [[ "${policy_v6}" == "-P FORWARD DROP" ]] \
        || fail "IPv6 FORWARD policy changed: ${policy_v6}"
}

assert_firewall_ipsets_present()
{
    local ipset_name

    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        expect_success "firewall setup omitted ${ipset_name}" \
            ipset list "${ipset_name}"
    done
}

assert_firewall_jumps_present()
{
    expect_success "firewall setup omitted ingress jump" \
        ip6tables -C FORWARD -o "${thread_if}" \
        -j "${otbr_forward_ingress_chain}"
    expect_success "firewall setup omitted egress jump" \
        ip6tables -C FORWARD -i "${thread_if}" \
        -j "${otbr_forward_egress_chain}"
}

assert_enabled_firewall_rules()
{
    assert_ip6_chain_rules_exact "${otbr_forward_ingress_chain}" \
        "-i ${thread_if} -m pkttype --pkt-type unicast -j DROP" \
        "-m set --match-set otbr-ingress-deny-src src -j DROP" \
        "-m set --match-set otbr-ingress-allow-dst dst -j ACCEPT" \
        "-m pkttype --pkt-type unicast -j DROP" \
        "-j ACCEPT"
    assert_ip6_chain_rules_exact "${otbr_forward_egress_chain}" \
        "-j ACCEPT"

    expect_success "enabled firewall omitted Thread-source unicast drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m pkttype --pkt-type unicast -i "${thread_if}" -j DROP
    expect_success "enabled firewall omitted denied-source drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m set --match-set otbr-ingress-deny-src src -j DROP
    expect_success "enabled firewall omitted allowed-destination accept" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m set --match-set otbr-ingress-allow-dst dst -j ACCEPT
    expect_success "enabled firewall omitted residual unicast drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m pkttype --pkt-type unicast -j DROP
    expect_success "enabled firewall omitted residual ingress accept" \
        ip6tables -C "${otbr_forward_ingress_chain}" -j ACCEPT
    expect_success "enabled firewall omitted egress accept" \
        ip6tables -C "${otbr_forward_egress_chain}" -j ACCEPT
}

assert_disabled_firewall_rules()
{
    assert_ip6_chain_rules_exact "${otbr_forward_ingress_chain}" \
        "-j ACCEPT"
    assert_ip6_chain_rules_exact "${otbr_forward_egress_chain}" \
        "-j ACCEPT"

    expect_success "disabled firewall omitted scoped ingress accept" \
        ip6tables -C "${otbr_forward_ingress_chain}" -j ACCEPT
    expect_success "disabled firewall omitted scoped egress accept" \
        ip6tables -C "${otbr_forward_egress_chain}" -j ACCEPT
    expect_failure "disabled firewall retained Thread-source unicast drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m pkttype --pkt-type unicast -i "${thread_if}" -j DROP
    expect_failure "disabled firewall retained denied-source drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m set --match-set otbr-ingress-deny-src src -j DROP
    expect_failure "disabled firewall retained allowed-destination filter" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m set --match-set otbr-ingress-allow-dst dst -j ACCEPT
    expect_failure "disabled firewall retained residual unicast drop" \
        ip6tables -C "${otbr_forward_ingress_chain}" \
        -m pkttype --pkt-type unicast -j DROP
    expect_failure "disabled firewall added broad ingress accept" \
        ip6tables -C FORWARD -i "${thread_if}" -j ACCEPT
    expect_failure "disabled firewall added broad egress accept" \
        ip6tables -C FORWARD -o "${thread_if}" -j ACCEPT
}

seed_legacy_nat64_signature()
{
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t mangle -A PREROUTING -i "${thread_if}" \
        -j MARK --set-mark "${otbr_fw_mark}"
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t nat -A POSTROUTING -m mark --mark "${otbr_fw_mark}" \
        -j MASQUERADE
}

assert_legacy_nat64_signature_present()
{
    expect_success "legacy MARK signature was removed" \
        iptables -t mangle -C PREROUTING -i "${thread_if}" \
        -j MARK --set-mark "${otbr_fw_mark}"
    expect_success "legacy MASQUERADE signature was removed" \
        iptables -t nat -C POSTROUTING \
        -m mark --mark "${otbr_fw_mark}" -j MASQUERADE
}

remove_legacy_nat64_signature_fixture()
{
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t mangle -D PREROUTING -i "${thread_if}" \
        -j MARK --set-mark "${otbr_fw_mark}"
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t nat -D POSTROUTING -m mark --mark "${otbr_fw_mark}" \
        -j MASQUERADE
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

    expect_failure "IPv6 ingress FORWARD jump remains" \
        ip6tables -C FORWARD -o "${thread_if}" \
        -j "${otbr_forward_ingress_chain}"
    expect_failure "IPv6 egress FORWARD jump remains" \
        ip6tables -C FORWARD -i "${thread_if}" \
        -j "${otbr_forward_egress_chain}"
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
    local fixture_if

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

    for fixture_if in \
        "${legacy_backbone_if}" \
        "${ambiguous_legacy_backbone_if}" \
        "${incomplete_legacy_backbone_if}"; do
        iptables -w 1 -t filter -D FORWARD \
            -i "${fixture_if}" -j ACCEPT >/dev/null 2>&1
        iptables -w 1 -t filter -D FORWARD \
            -o "${fixture_if}" -j ACCEPT >/dev/null 2>&1
    done
    iptables -w 1 -t mangle -D PREROUTING -i "${thread_if}" \
        -j MARK --set-mark "${otbr_fw_mark}" >/dev/null 2>&1
    iptables -w 1 -t nat -D POSTROUTING \
        -m mark --mark "${otbr_fw_mark}" \
        -j MASQUERADE >/dev/null 2>&1

    ip6tables -w 1 -F "${reference_chain}" >/dev/null 2>&1
    ip6tables -w 1 -X "${reference_chain}" >/dev/null 2>&1
    ip6tables -w 1 -F "${owned_reference_chain_v6}" >/dev/null 2>&1
    ip6tables -w 1 -X "${owned_reference_chain_v6}" >/dev/null 2>&1
    iptables -w 1 -t filter \
        -F "${owned_reference_chain_v4}" >/dev/null 2>&1
    iptables -w 1 -t filter \
        -X "${owned_reference_chain_v4}" >/dev/null 2>&1

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

# A restrictive host policy is valid input state. Setup and every cleanup path
# must preserve it for both protocol families.
iptables -w "${otbr_iptables_wait_seconds}" -t filter -P FORWARD DROP
ip6tables -w "${otbr_iptables_wait_seconds}" -P FORWARD DROP

# Empty teardown is deliberately repeatable, including iptables-nft's
# nonzero probe result when a referenced custom target does not exist.
otbr_netfilter_cleanup
otbr_netfilter_cleanup
assert_owned_absent
assert_forward_policies_preserved

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

assert_firewall_ipsets_present
expect_success "firewall setup omitted ingress chain" \
    ip6tables -L "${otbr_forward_ingress_chain}" -n
expect_success "firewall setup omitted egress chain" \
    ip6tables -L "${otbr_forward_egress_chain}" -n
assert_firewall_jumps_present
assert_enabled_firewall_rules
expect_success "NAT64 setup omitted chain" \
    iptables -t filter -L "${otbr_forward_nat64_chain}" -n
expect_success "NAT64 setup omitted jump" \
    iptables -t filter -C FORWARD -j "${otbr_forward_nat64_chain}"
assert_iptables_chain_rules_exact filter "${otbr_forward_nat64_chain}" \
    "-o eth0 -m mark --mark ${otbr_fw_mark} -j ACCEPT" \
    "-i eth0 -o ${thread_if} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT"
assert_forward_jump_order
assert_forward_policies_preserved
expect_success "NAT64 setup omitted marked outbound accept" \
    iptables -t filter -C "${otbr_forward_nat64_chain}" \
    -m mark --mark "${otbr_fw_mark}" -o eth0 -j ACCEPT
expect_success "NAT64 setup omitted return-traffic accept" \
    iptables -t filter -C "${otbr_forward_nat64_chain}" \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -i eth0 -o "${thread_if}" -j ACCEPT
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
for independent_ipset in "${otbr_firewall_ipsets[@]:1}"; do
    expect_failure "busy first ipset starved cleanup of ${independent_ipset}" \
        ipset list "${independent_ipset}"
done
assert_sentinels_present
assert_forward_policies_preserved

ip6tables -w "${otbr_iptables_wait_seconds}" -F "${reference_chain}"
ip6tables -w "${otbr_iptables_wait_seconds}" -X "${reference_chain}"
otbr_cleanup_budget_milliseconds=4000
otbr_ipset_destroy_attempts=20
otbr_netfilter_cleanup
otbr_netfilter_cleanup
assert_owned_absent
assert_sentinels_present
assert_forward_policies_preserved

# Disabled mode must remain scoped to the owned chains. It may permit traffic
# through those chains, but it must not restore the broad FORWARD accepts used
# by version 2.13.0 or retain any enabled-mode filtering rules.
otbr_firewall_setup false
assert_firewall_ipsets_present
assert_firewall_jumps_present
assert_disabled_firewall_rules
assert_sentinels_present
assert_forward_policies_preserved
otbr_firewall_cleanup
otbr_firewall_cleanup
assert_owned_absent
assert_sentinels_present
assert_forward_policies_preserved

# An unexpected external reference must produce an incomplete cleanup result,
# preserve the referenced owned chain, and recover once only that foreign
# reference is removed.
otbr_firewall_setup false
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -N "${owned_reference_chain_v6}"
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -A "${owned_reference_chain_v6}" \
    -j "${otbr_forward_ingress_chain}"
expect_failure "IPv6 cleanup ignored an external owned-chain reference" \
    otbr_firewall_cleanup
expect_success "referenced IPv6 owned chain was unexpectedly removed" \
    ip6tables -L "${otbr_forward_ingress_chain}" -n
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -F "${owned_reference_chain_v6}"
ip6tables -w "${otbr_iptables_wait_seconds}" \
    -X "${owned_reference_chain_v6}"
otbr_firewall_cleanup
assert_owned_absent
assert_forward_policies_preserved

otbr_nat64_setup eth0
iptables -w "${otbr_iptables_wait_seconds}" -t filter \
    -N "${owned_reference_chain_v4}"
iptables -w "${otbr_iptables_wait_seconds}" -t filter \
    -A "${owned_reference_chain_v4}" \
    -j "${otbr_forward_nat64_chain}"
expect_failure "IPv4 cleanup ignored an external owned-chain reference" \
    otbr_nat64_cleanup
expect_success "referenced IPv4 owned chain was unexpectedly removed" \
    iptables -t filter -L "${otbr_forward_nat64_chain}" -n
iptables -w "${otbr_iptables_wait_seconds}" -t filter \
    -F "${owned_reference_chain_v4}"
iptables -w "${otbr_iptables_wait_seconds}" -t filter \
    -X "${owned_reference_chain_v4}"
otbr_nat64_cleanup
assert_owned_absent
assert_forward_policies_preserved

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

# A complete pair on more than one backbone interface is ambiguous. Cleanup
# must preserve every broad rule and the MARK+MASQUERADE ownership signature
# so that it cannot delete host rules belonging to another service.
for fixture_if in \
    "${legacy_backbone_if}" \
    "${ambiguous_legacy_backbone_if}"; do
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t filter -A FORWARD -i "${fixture_if}" -j ACCEPT
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t filter -A FORWARD -o "${fixture_if}" -j ACCEPT
done
seed_legacy_nat64_signature
expect_failure "ambiguous multi-interface legacy cleanup succeeded" \
    otbr_nat64_cleanup
for fixture_if in \
    "${legacy_backbone_if}" \
    "${ambiguous_legacy_backbone_if}"; do
    expect_success "ambiguous legacy ingress rule was removed" \
        iptables -t filter -C FORWARD -i "${fixture_if}" -j ACCEPT
    expect_success "ambiguous legacy egress rule was removed" \
        iptables -t filter -C FORWARD -o "${fixture_if}" -j ACCEPT
done
assert_legacy_nat64_signature_present
assert_sentinels_present

# Remove only the exact rules seeded by this test, then prove the unrelated
# sentinels survived both production cleanup and fixture cleanup.
for fixture_if in \
    "${legacy_backbone_if}" \
    "${ambiguous_legacy_backbone_if}"; do
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t filter -D FORWARD -i "${fixture_if}" -j ACCEPT
    iptables -w "${otbr_iptables_wait_seconds}" \
        -t filter -D FORWARD -o "${fixture_if}" -j ACCEPT
done
remove_legacy_nat64_signature_fixture
assert_nat64_absent
assert_sentinels_present

# One half of a historical broad ACCEPT pair is likewise insufficient proof
# of ownership and must be preserved together with the identifying signature.
iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -A FORWARD \
    -i "${incomplete_legacy_backbone_if}" -j ACCEPT
seed_legacy_nat64_signature
expect_failure "incomplete legacy cleanup succeeded" otbr_nat64_cleanup
expect_success "incomplete legacy ingress rule was removed" \
    iptables -t filter -C FORWARD \
    -i "${incomplete_legacy_backbone_if}" -j ACCEPT
expect_failure "incomplete fixture unexpectedly gained an egress rule" \
    iptables -t filter -C FORWARD \
    -o "${incomplete_legacy_backbone_if}" -j ACCEPT
assert_legacy_nat64_signature_present
assert_sentinels_present

iptables -w "${otbr_iptables_wait_seconds}" \
    -t filter -D FORWARD \
    -i "${incomplete_legacy_backbone_if}" -j ACCEPT
remove_legacy_nat64_signature_fixture
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
