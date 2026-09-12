#!/bin/bash
# shellcheck disable=SC2317 # Mocks are invoked by sourced/evaluated runtime code.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$root/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
bashio::log.error() { printf '%s\n' "$*" >> "$work/errors"; }
declare -A chains rules jumps
clock=0 cost=0 calls=0 fail_at=0 pool_status=0
_otbr_clock_milliseconds() { REPLY=$clock; }
timeout() {
    [[ ${timeout_status:-0} == 0 ]] || return "$timeout_status"
    while [[ "$1" == -* ]]; do shift; done
    shift
    "$@"
}
python3() { return "$pool_status"; }
ip6_deadline=''
_otbr_remove_forward_jumps() { ip6_deadline="$1"; return 0; }
_otbr_delete_chain_if_exist() { return 0; }
_otbr_list_all_ipsets() { REPLY=''; }

iptables() {
    [[ "$1" == -w ]] || fail 'missing xtables wait'
    shift 2
    [[ "$1" == -t ]] || fail 'missing explicit table'
    local table="$2" operation="$3" chain="$4" key parent target
    shift 4
    key="$table/$chain"
    calls=$((calls + 1)); clock=$((clock + cost))
    if (( fail_at > 0 && calls == fail_at )); then return 4; fi
    case "$operation" in
        -N) [[ ! -v "chains[$key]" ]] || return 1; chains[$key]=1; rules[$key]='';;
        -L) [[ -v "chains[$key]" ]];;
        -A) [[ -v "chains[$key]" ]] || return 1; rules[$key]+="$*"$'\n';;
        -I) shift; [[ "$1" == -j ]] || fail 'unexpected jump'; target="$2"; jumps[$table/$chain/$target]=$(( ${jumps[$table/$chain/$target]:-0}+1 ));;
        -C) target="$2"; (( ${jumps[$table/$chain/$target]:-0} > 0 ));;
        -D) target="$2"; parent="$table/$chain/$target"; (( ${jumps[$parent]:-0} > 0 )) || return 1; jumps[$parent]=$((jumps[$parent]-1));;
        -F) rules[$key]='';;
        -X) unset 'chains[$key]' 'rules[$key]';;
        *) fail "unexpected iptables operation $operation";;
    esac
}
reset() {
    chains=([filter/FOREIGN]=1); rules=([filter/FOREIGN]='foreign rule --mark 0x1001'); jumps=([filter/FORWARD/FOREIGN]=1)
    calls=0 fail_at=0 clock=0 cost=0 pool_status=0
}
clean() { otbr_firewall_cleanup || fail 'cleanup failed'; }
assert_clean() {
    [[ ${#chains[@]} == 1 && ${chains[filter/FOREIGN]} == 1 ]] || fail 'owned chain remained'
    [[ ${rules[filter/FOREIGN]} == 'foreign rule --mark 0x1001' ]] || fail 'foreign rule changed'
    [[ ${jumps[filter/FORWARD/FOREIGN]} == 1 ]] || fail 'foreign jump changed'
}
reset
otbr_nat64_setup eth0 || fail setup
[[ ${rules[filter/OTBR_FORWARD_NAT64]} == *'-i wpan0 -o eth0 -s 192.168.255.0/24 -j ACCEPT'* ]] || fail outbound
[[ ${rules[filter/OTBR_FORWARD_NAT64]} == *'-i eth0 -o wpan0 -d 192.168.255.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT'* ]] || fail return
[[ ${rules[nat/OTBR_NAT64_MASQUERADE]} == '-s 192.168.255.0/24 -o eth0 -j MASQUERADE'$'\n' ]] || fail masquerade
jumps[filter/FORWARD/OTBR_FORWARD_NAT64]=3
jumps[nat/POSTROUTING/OTBR_NAT64_MASQUERADE]=2
clean; assert_clean
# Current option/backbone are not inputs to cleanup; stale state is reconciled.
otbr_nat64_setup eth1 || fail changed_backbone
[[ ${rules[filter/OTBR_FORWARD_NAT64]} != *eth0* ]] || fail stale_backbone
clean; assert_clean
for failure in {1..7}; do
    reset; fail_at=$failure
    if otbr_nat64_setup eth0; then fail "setup failure $failure accepted"; fi
    assert_clean
done
reset; pool_status=1
if otbr_nat64_setup eth0; then fail 'pool inspection failure accepted'; fi
assert_clean
reset; otbr_nat64_setup eth0
fail_at=$((calls + 2))
if otbr_firewall_cleanup; then fail 'failed rule inspection accepted'; fi
[[ ${rules[filter/FOREIGN]} == 'foreign rule --mark 0x1001' ]] || fail 'foreign rule changed on failure'
fail_at=0; clean; assert_clean
reset; otbr_nat64_setup eth0
jumps[filter/FORWARD/OTBR_FORWARD_NAT64]=65
if otbr_firewall_cleanup; then fail 'excess duplicates accepted'; fi
[[ ${jumps[filter/FORWARD/OTBR_FORWARD_NAT64]} == 1 ]] || fail 'deletion cap not enforced'
clean; assert_clean
reset; otbr_nat64_setup eth0
cost=1100
if otbr_firewall_cleanup; then fail 'expired shared cleanup budget accepted'; fi
[[ $ip6_deadline == 4000 ]] || fail 'IPv4 and IPv6 did not share deadline'
[[ $clock -le 4400 ]] || fail 'cleanup continued executing after budget'

# ot-ctl reports CLI errors with exit code zero, so inspect protocol completion.
# shellcheck disable=SC2317 # Invoked indirectly through the timeout mock.
ot-ctl() {
    printf '%s\n' "$*" >> "$work/cli"
    if [[ "$*" == "${cli_error:-}" ]]; then printf 'Error 7: InvalidArgs\n'; else printf 'Done\r\n'; fi
}
clock=0 cost=0 cli_error=''
otbr_nat64_configure false || fail disabled_configuration
[[ $(cat "$work/cli") == $'dns server upstream disable\nnat64 disable' ]] || fail disable_order
: > "$work/cli"
otbr_nat64_configure true || fail enabled_configuration
[[ $(tail -n 2 "$work/cli") == $'nat64 enable\ndns server upstream enable' ]] || fail enable_order
cli_error='dns server upstream enable'
if otbr_nat64_configure true; then fail 'CLI error text accepted'; fi
grep -Fq 'ot-ctl dns server upstream enable: Error 7: InvalidArgs' "$work/errors" || fail 'CLI error diagnostic missing'
[[ $(tail -n 2 "$work/cli") == $'dns server upstream disable\nnat64 disable' ]] || fail failed_config_rollback
ot-ctl() { printf 'partial response\n'; }
if otbr_nat64_configure false; then fail 'missing Done accepted'; fi
grep -Fq 'returned no Done response: partial response' "$work/errors" || fail 'incomplete response diagnostic missing'
timeout_status=124
if otbr_nat64_configure false; then fail 'stalled CLI accepted'; fi
grep -Fq 'failed (status 124)' "$work/errors" || fail 'timeout diagnostic missing'
# Run the actual startup check with only filesystem/socket prerequisites and
# shutdown effects redirected. Configuration remains behind those prerequisites.
# shellcheck disable=SC2016 # Expand paths when the rewritten check is evaluated.
check_script="$(sed \
    -e '\@^\. /etc/s6-overlay/scripts/otbr-agent-common$@d' \
    -e 's@mapfile -t < /tmp/otbr-agent-rest-api@true@' \
    -e 's@\[\[ -S /run/openthread-wpan0.sock \]\]@socket_ready@' \
    -e 's@\[\[ -f /run/otbr-agent-config-failed \]\]@[[ -f "$work/config-failed" ]]@' \
    -e 's@echo 1 > /run/otbr-agent-config-failed@echo 1 > "$work/config-failed"@' \
    -e 's@s6-svc -d /run/service/otbr-agent@touch "$work/service-down"@' \
    -e 's@echo 1 > /run/s6-linux-init-container-results/exitcode@echo 1 > "$work/exitcode"@' \
    -e 's@/run/s6/basedir/bin/halt@touch "$work/halt"@' \
    "$root/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/data/check")"
run_check() (
    local enabled="$1" socket_status="$2" rest_status="$3" configure_status="$4"
    MAPFILE=(::1 8081)
    bashio::config.false() { [[ "$1" == otbr_enable && "$enabled" == false ]]; }
    bashio::config.true() { [[ "$1" == otbr_nat64 ]]; }
    socket_ready() { return "$socket_status"; }
    nc() { return "$rest_status"; }
    otbr_nat64_configure() { echo "$1" >> "$work/configurations"; return "$configure_status"; }
    eval "$check_script"
)
# Disabled OTBR and missing prerequisites make no CLI changes and do not halt.
for state in 'false 0 0 0' 'true 1 0 0' 'true 0 1 0'; do
    read -r -a parameters <<< "$state"
    if run_check "${parameters[@]}"; then fail 'unready service reported ready'; fi
done
[[ ! -e "$work/configurations" && ! -e "$work/halt" ]] || fail 'unready/disabled service configured'
# Each daemon's first successful check configures before signalling readiness.
run_check true 0 0 0 || fail 'first incarnation failed'
run_check true 0 0 0 || fail 'next incarnation failed'
[[ $(wc -l < "$work/configurations") == 2 ]] || fail 'configuration not repeated for next checker'
if run_check true 0 0 1; then fail 'failed configuration reported ready'; fi
[[ $(cat "$work/exitcode") == 1 && -f "$work/halt" && -f "$work/config-failed" && -f "$work/service-down" ]] || fail 'configuration failure did not halt'
if run_check true 0 0 0; then fail 'failed service became ready while stopping'; fi
[[ $(wc -l < "$work/configurations") == 3 ]] || fail 'failed configuration retried while stopping'
grep -Fq 'Could not configure NAT64/upstream DNS; stopping the add-on.' "$work/errors" || fail 'shutdown diagnostic missing'
printf 'PASS: scoped NAT64 lifecycle, bounded CLI configuration and per-start readiness\n'
