#!/bin/bash
# Synthetic IPv4 packets only: this does not run the OpenThread translator.
# Run solely in the disposable --network none container documented below.
set -euo pipefail
TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
source "${TEST_DIR}/../rootfs/etc/s6-overlay/scripts/otbr-agent-common"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pids=()
cleanup() {
    local pid
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}
trap cleanup EXIT
# A network-none container starts with lo only. This is additional protection,
# not a substitute for the Docker namespace/capability boundary.
[[ "$(ip -o link show | wc -l)" == 1 ]] || fail 'expected only loopback'
[[ "$(iptables --version)" == *nf_tables* ]] || fail 'requires iptables-nft'
ip link set lo up
# Docker supplies these namespaced sysctls; /proc/sys stays read-only.
[[ "$(cat /proc/sys/net/ipv4/ip_forward)" == 1 ]] || fail 'IPv4 forwarding is disabled'
[[ "$(cat /proc/sys/net/ipv4/conf/all/rp_filter)" == 0 ]] || fail 'all.rp_filter must be zero'
[[ "$(cat /proc/sys/net/ipv4/conf/default/rp_filter)" == 0 ]] || fail 'default.rp_filter must be zero'

new_peer() {
    local root_if="$1" root_addr="$2" peer_addr="$3" attempt
    unshare --net sleep 120 &
    REPLY=$!
    pids+=("$REPLY")
    for ((attempt=0; attempt<100; attempt++)); do
        [[ "$(readlink "/proc/${REPLY}/ns/net")" != "$(readlink /proc/self/ns/net)" ]] && break
        sleep 0.01
    done
    [[ -e "/proc/${REPLY}/ns/net" ]] || fail 'peer namespace process exited'
    [[ "$(readlink "/proc/${REPLY}/ns/net")" != "$(readlink /proc/self/ns/net)" ]] || fail 'network unshare failed'
    ip link add "$root_if" type veth peer name peer0
    ip link set peer0 netns "$REPLY"
    ip addr add "$root_addr/30" dev "$root_if"
    ip link set "$root_if" up
    nsenter -t "$REPLY" -n ip link set lo up
    nsenter -t "$REPLY" -n ip addr add "$peer_addr/30" dev peer0
    nsenter -t "$REPLY" -n ip link set peer0 up
    nsenter -t "$REPLY" -n ip route add default via "$root_addr"
}
new_peer wpan0 198.18.0.1 198.18.0.2; thread_pid=$REPLY
new_peer infra0 198.18.0.5 198.18.0.6; infra_pid=$REPLY
new_peer other0 198.18.0.9 198.18.0.10; other_pid=$REPLY
nsenter -t "$thread_pid" -n ip addr add 192.168.255.2/32 dev lo
nsenter -t "$other_pid" -n ip addr add 192.168.255.3/32 dev lo

# Retain a preexisting mark-based forwarding policy for unrelated traffic.
iptables -P FORWARD DROP
iptables -t mangle -N TEST_MARK_SENTINEL
iptables -t mangle -A TEST_MARK_SENTINEL -j MARK --set-mark 0x400
iptables -t mangle -A PREROUTING -i other0 -s 198.18.0.10 -j TEST_MARK_SENTINEL
iptables -A FORWARD -i other0 -o infra0 -s 198.18.0.10 -d 198.18.0.6 -m mark --mark 0x400 -j ACCEPT
iptables -A FORWARD -i infra0 -o other0 -s 198.18.0.6 -d 198.18.0.10 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Initialize and retain unrelated NAT state before taking the baseline.
iptables -t nat -N TEST_NAT_SENTINEL
iptables -t nat -A TEST_NAT_SENTINEL -s 198.18.0.10 -j RETURN
iptables -t nat -A POSTROUTING -j TEST_NAT_SENTINEL
snapshot() {
    iptables-save | sed -E '/^#/d; s/\[[0-9]+:[0-9]+\]/[0:0]/g'
}
foreign_snapshot="$(snapshot)"
assert_foreign() {
    local current
    current="$(snapshot | grep -v -E 'OTBR_FORWARD_NAT64|OTBR_NAT64_MASQUERADE')"
    [[ "$current" == "$foreign_snapshot" ]] || fail 'unrelated rules, marks or policies changed'
}
assert_clean() {
    local current
    current="$(snapshot)"
    [[ "$current" == "$foreign_snapshot" ]] || fail 'cleanup left owned state or modified foreign state'
}
dropped() {
    iptables-save -c -t filter | awk '$1 == ":FORWARD" {gsub(/\[|\]/,"",$3); split($3,a,":"); print a[1]}'
}
assert_blocked_ping() {
    local pid="$1" source="$2" destination="$3" before status=0 after
    before="$(dropped)"
    timeout 3s nsenter -t "$pid" -n ping -n -c 1 -W 1 -I "$source" "$destination" >/dev/null 2>&1 || status=$?
    [[ "$status" == 1 ]] || fail "expected unreachable ping, got status ${status}"
    after="$(dropped)"
    (( after > before )) || fail 'negative packet did not reach the FORWARD DROP policy'
}
port=40000
udp_exchange() {
    local pid="$1" source="$2" observed="$3"
    port=$((port + 1))
    timeout 5s nsenter -t "$pid" -n python3 "$TEST_DIR/nat64-kernel/udp.py" client "$source" "$port" "$observed"
}
nsenter -t "$infra_pid" -n python3 "$TEST_DIR/nat64-kernel/udp.py" server &
pids+=("$!")
for ((attempt=0; attempt<100; attempt++)); do
    [[ -e /tmp/nat64-udp-ready ]] && break
    sleep 0.01
done
[[ -e /tmp/nat64-udp-ready ]] || fail 'UDP responder did not bind'
udp_exchange "$other_pid" 198.18.0.10 198.18.0.10

# Exact checker must refuse overlapping addresses and routes in non-main tables.
# Do not install the translator pool route until setup has reserved the pool.
ip addr add 192.168.255.100/32 dev lo
if otbr_nat64_setup infra0; then fail 'accepted conflicting interface address'; fi
assert_clean
ip addr del 192.168.255.100/32 dev lo
ip route add table 100 192.168.0.0/16 dev other0
if otbr_nat64_setup infra0; then fail 'accepted overlapping non-main-table route'; fi
assert_clean
ip route del table 100 192.168.0.0/16 dev other0
printf 'PASS: address and all-table route conflicts refused before setup\n'

otbr_nat64_setup infra0
# Simulate the route installed by the translator after the startup reservation.
ip route add 192.168.255.0/24 via 198.18.0.2 dev wpan0
assert_foreign
udp_exchange "$thread_pid" 192.168.255.2 198.18.0.5
return_packets="$(iptables -nvxL "$otbr_nat64_forward_chain" --line-numbers | awk '$1 == 2 {print $2}')"
(( return_packets > 0 )) || fail 'no packet traversed the established-return rule'
nsenter -t "$thread_pid" -n ping -n -c 1 -W 1 -I 192.168.255.2 198.18.0.6
# Negative cases require an observed policy drop, not merely a failed client.
assert_blocked_ping "$thread_pid" 198.18.0.2 198.18.0.6
assert_blocked_ping "$other_pid" 192.168.255.3 198.18.0.6
assert_blocked_ping "$thread_pid" 192.168.255.2 198.18.0.10
assert_blocked_ping "$infra_pid" 198.18.0.6 192.168.255.2
udp_exchange "$other_pid" 198.18.0.10 198.18.0.10
assert_foreign
printf 'PASS: scoped NAT/return traffic, wrong source/interface rejection and unchanged mark-dependent traffic\n'

# Duplicate jumps are historical stale state; cleanup must remove every copy.
iptables -I FORWARD 1 -j "$otbr_nat64_forward_chain"
iptables -t nat -I POSTROUTING 1 -j "$otbr_nat64_masquerade_chain"
otbr_firewall_cleanup
assert_clean
# A new ICMP identifier avoids reusing an established flow from the enabled phase.
assert_blocked_ping "$thread_pid" 192.168.255.2 198.18.0.6
ip route del 192.168.255.0/24 via 198.18.0.2 dev wpan0
# Restart reconciliation precedes re-creating the synthetic translator route.
otbr_firewall_cleanup
otbr_nat64_setup infra0
ip route add 192.168.255.0/24 via 198.18.0.2 dev wpan0
udp_exchange "$thread_pid" 192.168.255.2 198.18.0.5
assert_foreign
# Disabled mode installs no NAT64 rules; full cleanup is the shared stop path.
otbr_firewall_cleanup
assert_clean
assert_blocked_ping "$thread_pid" 192.168.255.2 198.18.0.6
ip route del 192.168.255.0/24 via 198.18.0.2 dev wpan0
udp_exchange "$other_pid" 198.18.0.10 198.18.0.10
assert_clean
printf 'PASS: duplicate cleanup, restart and disabled firewall state; no global conntrack flush\n'
