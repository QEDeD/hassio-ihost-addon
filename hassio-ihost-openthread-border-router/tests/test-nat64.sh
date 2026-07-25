#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"

declare -A chains rules
declare -a chain_rules
declare -i calls fail_call fail_status delete_calls fail_delete fail_chain_delete
declare -i mock_now_ms command_advance_ms forward_list_status

reset_state()
{
    chains=(["filter|${otbr_forward_nat64_chain}"]=0)
    rules=()
    chain_rules=()
    calls=0 fail_call=0 fail_status=1 delete_calls=0
    fail_delete=0 fail_chain_delete=0
    mock_now_ms=0 command_advance_ms=0 forward_list_status=0
}

iptables()
{
    calls=$((calls + 1))
    mock_now_ms=$((mock_now_ms + command_advance_ms))
    (( fail_call == 0 || calls != fail_call )) || return "${fail_status}"
    local -a a=("$@")
    [[ ${a[0]:-} == -w && ${a[1]:-} =~ ^[0-9]+$ ]] || return 2
    (( a[1] >= 1 && a[1] <= otbr_iptables_wait_seconds )) || return 2
    a=("${a[@]:2}")
    [[ ${a[0]:-} == -t ]] || return 1
    local table=${a[1]} op=${a[2]} chain=${a[3]} rest key count index prefix
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
        -C)
            rest="${a[*]:4}"
            key="${table}|${chain}|${rest}"
            if [[ "${table}|${chain}|${rest}" \
                == "filter|FORWARD|-j ${otbr_forward_nat64_chain}" ]]; then
                [[ ${chains["filter|${otbr_forward_nat64_chain}"]:-0} -eq 1 ]] \
                    || return 2
            fi
            [[ ${rules["${key}"]:-0} -gt 0 ]]
            ;;
        -D) rest="${a[*]:4}"; key="${table}|${chain}|${rest}"; delete_calls=$((delete_calls + 1)); (( fail_delete == 0 )) || return 1; [[ ${rules["${key}"]:-0} -gt 0 ]] || return 1; rules["${key}"]=$((rules["${key}"] - 1)) ;;
        -L) key="${table}|${chain}"; [[ ${chains["${key}"]:-0} -eq 1 ]] ;;
        -S)
            (( forward_list_status == 0 )) || return "${forward_list_status}"
            [[ ${table} == filter && ${chain} == FORWARD ]] || return 2
            prefix="${table}|${chain}|"
            for key in "${!rules[@]}"; do
                if [[ "${key}" == "${prefix}"* ]]; then
                    rest="${key#"${prefix}"}"
                    count=${rules["${key}"]}
                    for ((index = 0; index < count; index++)); do
                        printf -- '-A FORWARD %s\n' "${rest}"
                    done
                fi
            done
            ;;
        -F) key="${table}|${chain}"; [[ ${chains["${key}"]:-0} -eq 1 ]] || return 1; chain_rules=() ;;
        -X) key="${table}|${chain}"; (( fail_chain_delete == 0 )) || return 1; [[ ${chains["${key}"]:-0} -eq 1 ]] || return 1; chains["${key}"]=0 ;;
        *) return 1 ;;
    esac
}

ip6tables() { return 1; }
ipset() { return 1; }
sleep()
{
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
    [[ ${chains["filter|${otbr_forward_nat64_chain}"]:-0} -eq 0 ]]
    [[ ${rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]:-0} -eq 0 ]]
    [[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 0 ]]
    [[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 0 ]]
}

reset_state
otbr_nat64_cleanup
otbr_nat64_cleanup
assert_clean

reset_state
otbr_nat64_setup eth0
[[ ${rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]} -eq 1 ]]
[[ ${#chain_rules[@]} -eq 2 ]]
[[ ${chain_rules[0]} == "-m mark --mark ${otbr_fw_mark} -o eth0 -j ACCEPT" ]]
[[ ${chain_rules[1]} == "-m conntrack --ctstate ESTABLISHED,RELATED -i eth0 -o ${thread_if} -j ACCEPT" ]]
# Current setup shares its MARK+MASQUERADE signature with the legacy release.
# The dedicated chain is the discriminator: unrelated broad accepts must
# survive ordinary current-version teardown.
rules["filter|FORWARD|-o docker0 -j ACCEPT"]=1
rules["filter|FORWARD|-i docker0 -j ACCEPT"]=1
otbr_nat64_cleanup
assert_clean
[[ ${rules["filter|FORWARD|-o docker0 -j ACCEPT"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i docker0 -j ACCEPT"]:-0} -eq 1 ]]

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
otbr_nat64_cleanup
assert_clean
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 0 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 0 ]]

reset_state
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-o old0 -j ACCEPT"]=1
rules["filter|FORWARD|-i old0 -j ACCEPT"]=1
otbr_nat64_cleanup wlan0
assert_clean
[[ ${rules["filter|FORWARD|-o old0 -j ACCEPT"]:-0} -eq 0 ]]
[[ ${rules["filter|FORWARD|-i old0 -j ACCEPT"]:-0} -eq 0 ]]

reset_state
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]=1
chains["filter|${otbr_forward_nat64_chain}"]=1
chain_rules=(stale)
otbr_nat64_cleanup
assert_clean
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
# A legacy signature is not permission to delete exact broad rules belonging
# to several interfaces. Preserve the signature and every ambiguous rule.
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
rules["filter|FORWARD|-o docker0 -j ACCEPT"]=1
rules["filter|FORWARD|-i docker0 -j ACCEPT"]=1
if otbr_nat64_cleanup; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-o docker0 -j ACCEPT"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i docker0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
# wpan0 cannot be the old backbone interface and must never be inferred as an
# owned broad legacy rule.
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-o ${thread_if} -j ACCEPT"]=1
if otbr_nat64_cleanup; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-o ${thread_if} -j ACCEPT"]:-0} -eq 1 ]]

reset_state
# A lone broad direction is not the complete version 2.13.0 signature.
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
if otbr_nat64_cleanup; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=1
otbr_nat64_cleanup eth0
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
# A failed legacy migration must preserve its identifying mark/MASQUERADE
# rules, then complete successfully on the next attempt.
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-o eth0 -j ACCEPT"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
fail_delete=1
if otbr_nat64_cleanup eth0; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 1 ]]
fail_delete=0
otbr_nat64_cleanup eth0
assert_clean
[[ ${rules["filter|FORWARD|-o eth0 -j ACCEPT"]:-0} -eq 0 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 0 ]]

reset_state
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
forward_list_status=4
if otbr_nat64_cleanup; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
fail_call=4
if otbr_nat64_setup eth0; then exit 1; fi
assert_clean

reset_state
rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]=$((otbr_cleanup_max_rule_deletes + 1))
chains["filter|${otbr_forward_nat64_chain}"]=1
if otbr_nat64_cleanup; then exit 1; fi
[[ ${delete_calls} -eq ${otbr_cleanup_max_rule_deletes} ]]

reset_state
rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]=1
rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]=1
rules["filter|FORWARD|-i eth0 -j ACCEPT"]=1
fail_call=1
fail_status=4
if otbr_nat64_cleanup; then exit 1; fi
[[ ${rules["mangle|PREROUTING|-i ${thread_if} -j MARK --set-mark ${otbr_fw_mark}"]:-0} -eq 1 ]]
[[ ${rules["nat|POSTROUTING|-m mark --mark ${otbr_fw_mark} -j MASQUERADE"]:-0} -eq 1 ]]
[[ ${rules["filter|FORWARD|-i eth0 -j ACCEPT"]:-0} -eq 1 ]]

reset_state
rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]=10
chains["filter|${otbr_forward_nat64_chain}"]=1
command_advance_ms=1000
if otbr_nat64_cleanup; then exit 1; fi
(( mock_now_ms <= otbr_cleanup_budget_milliseconds + command_advance_ms ))
[[ ${rules["filter|FORWARD|-j ${otbr_forward_nat64_chain}"]} -gt 0 ]]

reset_state
if otbr_nat64_setup ''; then exit 1; else [[ $? -eq 2 ]]; fi

printf 'PASS: standalone OTBR NAT64 lifecycle\n'
