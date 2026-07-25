#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"

declare -A chains jumps sets destroy_failures rules
declare -i calls fail_call fail_status delete_calls sleep_calls
declare -i fail_delete fail_chain_delete ipset_list_status
declare -i mock_now_ms command_advance_ms

reset_state()
{
    chains=(["${otbr_forward_ingress_chain}"]=0 ["${otbr_forward_egress_chain}"]=0)
    jumps=(["-o|${otbr_forward_ingress_chain}"]=0 ["-i|${otbr_forward_egress_chain}"]=0)
    sets=()
    destroy_failures=()
    rules=(["${otbr_forward_ingress_chain}"]=0 ["${otbr_forward_egress_chain}"]=0)
    calls=0 fail_call=0 fail_status=1 delete_calls=0 sleep_calls=0
    fail_delete=0 fail_chain_delete=0 ipset_list_status=0
    mock_now_ms=0 command_advance_ms=0
}

ip6tables()
{
    calls=$((calls + 1))
    mock_now_ms=$((mock_now_ms + command_advance_ms))
    (( fail_call == 0 || calls != fail_call )) || return "${fail_status}"
    local -a a=("$@")
    [[ ${a[0]:-} == -w && ${a[1]:-} =~ ^[0-9]+$ ]] || return 2
    (( a[1] >= 1 && a[1] <= otbr_iptables_wait_seconds )) || return 2
    a=("${a[@]:2}")
    local op=${a[0]:-} chain flag key
    case "${op}" in
        -N) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 0 ]] || return 1; chains["${chain}"]=1 ;;
        -I) flag=${a[3]}; chain=${a[6]}; key="${flag}|${chain}"; jumps["${key}"]=$(( ${jumps["${key}"]:-0} + 1 )) ;;
        -A) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 1 ]] || return 1; rules["${chain}"]=$(( ${rules["${chain}"]:-0} + 1 )) ;;
        -C)
            flag=${a[2]}
            chain=${a[5]}
            key="${flag}|${chain}"
            # Match iptables-nft: an absent custom jump target is an
            # operational error rather than an ordinary missing-rule result.
            [[ ${chains["${chain}"]:-0} -eq 1 ]] || return 2
            [[ ${jumps["${key}"]:-0} -gt 0 ]]
            ;;
        -D) flag=${a[2]}; chain=${a[5]}; key="${flag}|${chain}"; delete_calls=$((delete_calls + 1)); (( fail_delete == 0 )) || return 1; [[ ${jumps["${key}"]:-0} -gt 0 ]] || return 1; jumps["${key}"]=$((jumps["${key}"] - 1)) ;;
        -L) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 1 ]] ;;
        -F) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 1 ]] || return 1; rules["${chain}"]=0 ;;
        -X) chain=${a[1]}; (( fail_chain_delete == 0 )) || return 1; [[ ${chains["${chain}"]:-0} -eq 1 ]] || return 1; chains["${chain}"]=0 ;;
        *) return 1 ;;
    esac
}

ipset()
{
    local op=$1 name
    shift
    case "${op}" in
        create) [[ ${1:-} == -exist ]] || return 1; name=${2}; sets["${name}"]=1 ;;
        list)
            (( ipset_list_status == 0 )) || return "${ipset_list_status}"
            [[ ${1:-} == -n ]] || return 2
            for name in "${!sets[@]}"; do
                if [[ ${sets["${name}"]:-0} -eq 1 ]]; then
                    printf '%s\n' "${name}"
                fi
            done
            ;;
        destroy)
            name=${1}
            if [[ ${destroy_failures["${name}"]:-0} -gt 0 ]]; then
                destroy_failures["${name}"]=$((destroy_failures["${name}"] - 1))
                return 1
            fi
            [[ ${sets["${name}"]:-0} -eq 1 ]] || return 1
            sets["${name}"]=0
            ;;
        *) return 1 ;;
    esac
}

sleep()
{
    sleep_calls=$((sleep_calls + 1))
    case "${1:-}" in
        0.1) mock_now_ms=$((mock_now_ms + 100)) ;;
        *) return 2 ;;
    esac
}

timeout()
{
    [[ ${1:-} == --foreground ]] || return 2
    shift
    [[ ${1:-} == --kill-after=* ]] || return 2
    shift
    shift
    "$@"
}

_otbr_now_milliseconds()
{
    otbr_now_milliseconds="${mock_now_ms}"
}

assert_clean()
{
    local name
    [[ ${chains["${otbr_forward_ingress_chain}"]:-0} -eq 0 ]]
    [[ ${chains["${otbr_forward_egress_chain}"]:-0} -eq 0 ]]
    [[ ${jumps["-o|${otbr_forward_ingress_chain}"]:-0} -eq 0 ]]
    [[ ${jumps["-i|${otbr_forward_egress_chain}"]:-0} -eq 0 ]]
    for name in "${otbr_firewall_ipsets[@]}"; do
        [[ ${sets["${name}"]:-0} -eq 0 ]]
    done
}

reset_state
otbr_firewall_cleanup
otbr_firewall_cleanup
assert_clean

for mode in false true; do
    reset_state
    otbr_firewall_setup "${mode}"
    [[ ${rules["${otbr_forward_ingress_chain}"]} -eq $([[ ${mode} == true ]] && echo 5 || echo 1) ]]
    [[ ${rules["${otbr_forward_egress_chain}"]} -eq 1 ]]
    [[ ${jumps["-o|${otbr_forward_ingress_chain}"]} -eq 1 ]]
    [[ ${jumps["-i|${otbr_forward_egress_chain}"]} -eq 1 ]]
    otbr_firewall_cleanup
    assert_clean
done

reset_state
jumps["-o|${otbr_forward_ingress_chain}"]=3
jumps["-i|${otbr_forward_egress_chain}"]=2
chains["${otbr_forward_ingress_chain}"]=1
chains["${otbr_forward_egress_chain}"]=1
for name in "${otbr_firewall_ipsets[@]}"; do sets["${name}"]=1; done
destroy_failures["otbr-ingress-deny-src"]=2
otbr_firewall_cleanup
[[ ${sleep_calls} -eq 2 ]]
assert_clean

reset_state
fail_call=3
if otbr_firewall_setup true; then exit 1; fi
assert_clean

reset_state
jumps["-o|${otbr_forward_ingress_chain}"]=$((otbr_cleanup_max_rule_deletes + 1))
chains["${otbr_forward_ingress_chain}"]=1
if otbr_firewall_cleanup; then exit 1; fi
[[ ${delete_calls} -eq ${otbr_cleanup_max_rule_deletes} ]]

reset_state
sets["otbr-ingress-deny-src"]=1
destroy_failures["otbr-ingress-deny-src"]=999
if otbr_firewall_cleanup; then exit 1; fi
[[ ${sleep_calls} -eq $((otbr_ipset_destroy_attempts - 1)) ]]

reset_state
fail_call=1
fail_status=4
if otbr_firewall_cleanup; then exit 1; fi

reset_state
sets["otbr-ingress-deny-src"]=1
ipset_list_status=2
if otbr_firewall_cleanup; then exit 1; fi
[[ ${sets["otbr-ingress-deny-src"]} -eq 1 ]]

reset_state
sets["otbr-ingress-deny-src-extra"]=1
otbr_firewall_cleanup
[[ ${sets["otbr-ingress-deny-src-extra"]} -eq 1 ]]

reset_state
for name in "${otbr_firewall_ipsets[@]}"; do
    sets["${name}"]=1
    destroy_failures["${name}"]=999
done
if otbr_firewall_cleanup; then exit 1; fi
(( mock_now_ms <= otbr_cleanup_budget_milliseconds ))
(( sleep_calls < 4 * (otbr_ipset_destroy_attempts - 1) ))

reset_state
jumps["-o|${otbr_forward_ingress_chain}"]=10
chains["${otbr_forward_ingress_chain}"]=1
command_advance_ms=1000
if otbr_firewall_cleanup; then exit 1; fi
(( mock_now_ms <= otbr_cleanup_budget_milliseconds + command_advance_ms ))
[[ ${jumps["-o|${otbr_forward_ingress_chain}"]} -gt 0 ]]

printf 'PASS: standalone OTBR IPv6 firewall lifecycle\n'
