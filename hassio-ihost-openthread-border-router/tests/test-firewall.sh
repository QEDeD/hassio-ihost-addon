#!/bin/bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
# shellcheck disable=SC1090
source "${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"

declare -A chains jumps sets destroy_failures rules
declare -i calls fail_call delete_calls sleep_calls fail_delete fail_chain_delete

reset_state()
{
    chains=(["${otbr_forward_ingress_chain}"]=0 ["${otbr_forward_egress_chain}"]=0)
    jumps=(["-o|${otbr_forward_ingress_chain}"]=0 ["-i|${otbr_forward_egress_chain}"]=0)
    sets=()
    destroy_failures=()
    rules=(["${otbr_forward_ingress_chain}"]=0 ["${otbr_forward_egress_chain}"]=0)
    calls=0 fail_call=0 delete_calls=0 sleep_calls=0
    fail_delete=0 fail_chain_delete=0
}

ip6tables()
{
    calls=$((calls + 1))
    (( fail_call == 0 || calls != fail_call )) || return 1
    local -a a=("$@")
    [[ ${a[0]:-} == -w && ${a[1]:-} == "${otbr_iptables_wait_seconds}" ]] || return 1
    a=("${a[@]:2}")
    local op=${a[0]:-} chain flag key
    case "${op}" in
        -N) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 0 ]] || return 1; chains["${chain}"]=1 ;;
        -I) flag=${a[3]}; chain=${a[6]}; key="${flag}|${chain}"; jumps["${key}"]=$(( ${jumps["${key}"]:-0} + 1 )) ;;
        -A) chain=${a[1]}; [[ ${chains["${chain}"]:-0} -eq 1 ]] || return 1; rules["${chain}"]=$(( ${rules["${chain}"]:-0} + 1 )) ;;
        -C) flag=${a[2]}; chain=${a[5]}; key="${flag}|${chain}"; [[ ${jumps["${key}"]:-0} -gt 0 ]] ;;
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
        list) name=${2}; [[ ${sets["${name}"]:-0} -eq 1 ]] ;;
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

sleep() { sleep_calls=$((sleep_calls + 1)); }

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
if otbr_firewall_cleanup; then exit 1; fi
[[ ${delete_calls} -eq ${otbr_cleanup_max_rule_deletes} ]]

reset_state
sets["otbr-ingress-deny-src"]=1
destroy_failures["otbr-ingress-deny-src"]=999
if otbr_firewall_cleanup; then exit 1; fi
[[ ${sleep_calls} -eq $((otbr_ipset_destroy_attempts - 1)) ]]

printf 'PASS: standalone OTBR IPv6 firewall lifecycle\n'
