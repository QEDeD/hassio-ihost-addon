#!/bin/bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
# shellcheck disable=SC1090
source "${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"

declare -A chains rules
declare -a chain_rules
declare -i calls fail_call delete_calls fail_delete fail_chain_delete

reset_state()
{
    chains=(["filter|${otbr_forward_nat64_chain}"]=0)
    rules=()
    chain_rules=()
    calls=0 fail_call=0 delete_calls=0 fail_delete=0 fail_chain_delete=0
}

iptables()
{
    calls=$((calls + 1))
    (( fail_call == 0 || calls != fail_call )) || return 1
    local -a a=("$@")
    [[ ${a[0]:-} == -w && ${a[1]:-} == "${otbr_iptables_wait_seconds}" ]] || return 1
    a=("${a[@]:2}")
    [[ ${a[0]:-} == -t ]] || return 1
    local table=${a[1]} op=${a[2]} chain=${a[3]} rest key
    case "${op}" in
        -N) key="${table}|${chain}"; [[ ${chains["${key}"]:-0} -eq 0 ]] || return 1; chains["${key}"]=1 ;;
        -I|-A)
            [[ ${op} == -I ]] && rest="${a[*]:5}" || rest="${a[*]:4}"
            if [[ ${table} == filter && ${chain} == "${otbr_forward_nat64_chain}" ]]; then
                [[ ${chains["filter|${chain}"]:-0} -eq 1 ]] || return 1
                chain_rules+=("${rest}")
            else
                key="${table}|${chain}|${rest}"
                rules["${key}"]=$(( ${rules["${key}"]:-0} + 1 ))
            fi
            ;;
        -C) rest="${a[*]:4}"; key="${table}|${chain}|${rest}"; [[ ${rules["${key}"]:-0} -gt 0 ]] ;;
        -D) rest="${a[*]:4}"; key="${table}|${chain}|${rest}"; delete_calls=$((delete_calls + 1)); (( fail_delete == 0 )) || return 1; [[ ${rules["${key}"]:-0} -gt 0 ]] || return 1; rules["${key}"]=$((rules["${key}"] - 1)) ;;
        -L) key="${table}|${chain}"; [[ ${chains["${key}"]:-0} -eq 1 ]] ;;
        -F) key="${table}|${chain}"; [[ ${chains["${key}"]:-0} -eq 1 ]] || return 1; chain_rules=() ;;
        -X) key="${table}|${chain}"; (( fail_chain_delete == 0 )) || return 1; [[ ${chains["${key}"]:-0} -eq 1 ]] || return 1; chains["${key}"]=0 ;;
        *) return 1 ;;
    esac
}

ip6tables() { return 1; }
ipset() { return 1; }
sleep() { :; }

assert_clean()
{
    [[ ${chains["filter|${otbr_forward_nat64_chain}"]:-0} -eq 0 ]]
    [[ ${rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]:-0} -eq 0 ]]
    [[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 0 ]]
    [[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 0 ]]
}

reset_state
otbr_nat64_setup eth0
[[ ${rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]} -eq 1 ]]
[[ ${#chain_rules[@]} -eq 2 ]]
[[ ${chain_rules[0]} == "-m mark --mark ${otbr_fw_mark} -o eth0 -j ACCEPT" ]]
[[ ${chain_rules[1]} == "-m conntrack --ctstate ESTABLISHED,RELATED -i eth0 -o ${thread_if} -j ACCEPT" ]]
otbr_nat64_cleanup
assert_clean

reset_state
rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]=3
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=2
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=2
chains["filter|${otbr_forward_nat64_chain}"]=1
chain_rules=(stale)
otbr_nat64_cleanup
assert_clean

reset_state
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=2
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=2
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=2
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=2
otbr_nat64_cleanup eth0
assert_clean
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 0 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 0 ]]

reset_state
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=1
otbr_nat64_cleanup eth0
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
# A failed legacy migration must preserve its identifying mark/MASQUERADE
# rules, then complete successfully on the next attempt.
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
fail_delete=1
if otbr_nat64_cleanup eth0; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
fail_delete=0
otbr_nat64_cleanup eth0
assert_clean
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 0 ]]

reset_state
fail_call=4
if otbr_nat64_setup eth0; then exit 1; fi
assert_clean

reset_state
rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]=$((otbr_cleanup_max_rule_deletes + 1))
if otbr_nat64_cleanup; then exit 1; fi
[[ ${delete_calls} -eq ${otbr_cleanup_max_rule_deletes} ]]

reset_state
if otbr_nat64_setup ''; then exit 1; else [[ $? -eq 2 ]]; fi

printf 'PASS: standalone OTBR NAT64 lifecycle\n'
