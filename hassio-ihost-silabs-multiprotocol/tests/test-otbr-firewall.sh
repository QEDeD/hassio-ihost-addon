#!/bin/bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly COMMON_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly RUN_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"
readonly ENABLE_CHECK_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-enable-check.sh"

# The test invokes the shared functions with stateful command mocks. The service
# scripts themselves are checked for syntax and caller-level invariants below.
# shellcheck disable=SC1090
source "${COMMON_SCRIPT}"

declare -A mock_chains
declare -A mock_jump_counts
declare -A mock_sets
declare -A mock_set_destroy_failures
declare -A mock_chain_rule_counts
declare -a mock_ingress_rules
declare -a mock_egress_rules
declare -a mock_command_log
declare -i mock_ip6_call_count
declare -i mock_fail_ip6_call
declare -i mock_rule_delete_calls
declare -i mock_sleep_calls
declare -i mock_fail_rule_delete
declare -i mock_fail_chain_delete

fail()
{
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq()
{
    local expected="$1"
    local actual="$2"
    local description="$3"

    [[ "${actual}" == "${expected}" ]] \
        || fail "${description}: expected '${expected}', got '${actual}'"
}

assert_contains()
{
    local needle="$1"
    local haystack="$2"
    local description="$3"

    [[ "${haystack}" == *"${needle}"* ]] \
        || fail "${description}: missing '${needle}'"
}

assert_not_contains()
{
    local needle="$1"
    local haystack="$2"
    local description="$3"

    [[ "${haystack}" != *"${needle}"* ]] \
        || fail "${description}: unexpectedly contained '${needle}'"
}

mock_reset()
{
    mock_chains=()
    mock_chains["${otbr_forward_ingress_chain}"]=0
    mock_chains["${otbr_forward_egress_chain}"]=0

    mock_jump_counts=()
    mock_jump_counts["-o|${otbr_forward_ingress_chain}"]=0
    mock_jump_counts["-i|${otbr_forward_egress_chain}"]=0

    mock_sets=()
    mock_set_destroy_failures=()

    mock_chain_rule_counts=()
    mock_chain_rule_counts["${otbr_forward_ingress_chain}"]=0
    mock_chain_rule_counts["${otbr_forward_egress_chain}"]=0

    mock_ingress_rules=()
    mock_egress_rules=()
    mock_command_log=()

    mock_ip6_call_count=0
    mock_fail_ip6_call=0
    mock_rule_delete_calls=0
    mock_sleep_calls=0
    mock_fail_rule_delete=0
    mock_fail_chain_delete=0
}

ip6tables()
{
    mock_command_log+=("ip6tables $*")
    mock_ip6_call_count=$((mock_ip6_call_count + 1))

    if (( mock_fail_ip6_call > 0 \
        && mock_ip6_call_count == mock_fail_ip6_call )); then
        return 1
    fi

    local -a args=("$@")
    if [[ "${args[0]:-}" != "-w" \
        || "${args[1]:-}" != "${otbr_iptables_wait_seconds}" ]]; then
        fail "ip6tables command did not use the configured xtables wait: $*"
    fi
    args=("${args[@]:2}")

    local operation="${args[0]:-}"
    local chain_name
    local interface_flag
    local jump_key
    local rule

    case "${operation}" in
        -N)
            chain_name="${args[1]:-}"
            [[ ${mock_chains["${chain_name}"]:-0} -eq 0 ]] || return 1
            mock_chains["${chain_name}"]=1
            mock_chain_rule_counts["${chain_name}"]=0
            ;;
        -I)
            interface_flag="${args[3]:-}"
            chain_name="${args[6]:-}"
            jump_key="${interface_flag}|${chain_name}"
            mock_jump_counts["${jump_key}"]=$((
                ${mock_jump_counts["${jump_key}"]:-0} + 1
            ))
            ;;
        -A)
            chain_name="${args[1]:-}"
            [[ ${mock_chains["${chain_name}"]:-0} -eq 1 ]] || return 1
            mock_chain_rule_counts["${chain_name}"]=$((
                ${mock_chain_rule_counts["${chain_name}"]:-0} + 1
            ))
            rule="${args[*]:2}"
            if [[ "${chain_name}" == "${otbr_forward_ingress_chain}" ]]; then
                mock_ingress_rules+=("${rule}")
            else
                mock_egress_rules+=("${rule}")
            fi
            ;;
        -C)
            interface_flag="${args[2]:-}"
            chain_name="${args[5]:-}"
            jump_key="${interface_flag}|${chain_name}"
            [[ ${mock_jump_counts["${jump_key}"]:-0} -gt 0 ]]
            ;;
        -D)
            interface_flag="${args[2]:-}"
            chain_name="${args[5]:-}"
            jump_key="${interface_flag}|${chain_name}"
            mock_rule_delete_calls=$((mock_rule_delete_calls + 1))
            (( mock_fail_rule_delete == 0 )) || return 1
            [[ ${mock_jump_counts["${jump_key}"]:-0} -gt 0 ]] || return 1
            mock_jump_counts["${jump_key}"]=$((
                mock_jump_counts["${jump_key}"] - 1
            ))
            ;;
        -L)
            chain_name="${args[1]:-}"
            [[ ${mock_chains["${chain_name}"]:-0} -eq 1 ]]
            ;;
        -F)
            chain_name="${args[1]:-}"
            [[ ${mock_chains["${chain_name}"]:-0} -eq 1 ]] || return 1
            mock_chain_rule_counts["${chain_name}"]=0
            if [[ "${chain_name}" == "${otbr_forward_ingress_chain}" ]]; then
                mock_ingress_rules=()
            else
                mock_egress_rules=()
            fi
            ;;
        -X)
            chain_name="${args[1]:-}"
            (( mock_fail_chain_delete == 0 )) || return 1
            [[ ${mock_chains["${chain_name}"]:-0} -eq 1 ]] || return 1
            mock_chains["${chain_name}"]=0
            ;;
        *)
            fail "unsupported mock ip6tables operation: $*"
            ;;
    esac
}

ipset()
{
    mock_command_log+=("ipset $*")

    local operation="$1"
    shift
    local ipset_name

    case "${operation}" in
        create)
            [[ "${1:-}" == "-exist" ]] || return 1
            ipset_name="${2:-}"
            mock_sets["${ipset_name}"]=1
            ;;
        list)
            ipset_name="${2:-}"
            [[ ${mock_sets["${ipset_name}"]:-0} -eq 1 ]]
            ;;
        destroy)
            ipset_name="${1:-}"
            if [[ ${mock_set_destroy_failures["${ipset_name}"]:-0} -gt 0 ]]; then
                mock_set_destroy_failures["${ipset_name}"]=$((
                    mock_set_destroy_failures["${ipset_name}"] - 1
                ))
                return 1
            fi
            [[ ${mock_sets["${ipset_name}"]:-0} -eq 1 ]] || return 1
            mock_sets["${ipset_name}"]=0
            ;;
        *)
            fail "unsupported mock ipset operation: ${operation} $*"
            ;;
    esac
}

sleep()
{
    mock_sleep_calls=$((mock_sleep_calls + 1))
}

assert_firewall_state_clean()
{
    local ipset_name

    assert_eq 0 "${mock_chains["${otbr_forward_ingress_chain}"]:-0}" \
        "ingress chain cleanup"
    assert_eq 0 "${mock_chains["${otbr_forward_egress_chain}"]:-0}" \
        "egress chain cleanup"
    assert_eq 0 "${mock_jump_counts["-o|${otbr_forward_ingress_chain}"]:-0}" \
        "ingress jump cleanup"
    assert_eq 0 "${mock_jump_counts["-i|${otbr_forward_egress_chain}"]:-0}" \
        "egress jump cleanup"

    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        assert_eq 0 "${mock_sets["${ipset_name}"]:-0}" \
            "${ipset_name} cleanup"
    done
}

test_disabled_setup_is_scoped()
{
    mock_reset
    otbr_firewall_setup false

    assert_eq 1 "${mock_jump_counts["-o|${otbr_forward_ingress_chain}"]}" \
        "disabled ingress jump count"
    assert_eq 1 "${mock_jump_counts["-i|${otbr_forward_egress_chain}"]}" \
        "disabled egress jump count"
    assert_eq 1 "${#mock_ingress_rules[@]}" \
        "disabled ingress rule count"
    assert_eq 1 "${#mock_egress_rules[@]}" \
        "disabled egress rule count"
    assert_eq '-j ACCEPT' "${mock_ingress_rules[0]}" \
        "disabled ingress rule"
    assert_eq '-j ACCEPT' "${mock_egress_rules[0]}" \
        "disabled egress rule"

    local ipset_name
    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        assert_eq 1 "${mock_sets["${ipset_name}"]:-0}" \
            "${ipset_name} creation in disabled mode"
    done

    local commands
    commands="$(printf '%s\n' "${mock_command_log[@]}")"
    assert_not_contains 'ip6tables-legacy' "${commands}" \
        "legacy backend invocation"
    assert_not_contains 'ip6tables -P FORWARD' "${commands}" \
        "global FORWARD policy mutation"
}

test_enabled_setup_preserves_filtering()
{
    mock_reset
    otbr_firewall_setup true

    assert_eq 5 "${#mock_ingress_rules[@]}" \
        "enabled ingress rule count"
    assert_eq 1 "${#mock_egress_rules[@]}" \
        "enabled egress rule count"
    assert_contains '--match-set otbr-ingress-deny-src src -j DROP' \
        "${mock_ingress_rules[*]}" "deny-source filtering rule"
    assert_contains '--match-set otbr-ingress-allow-dst dst -j ACCEPT' \
        "${mock_ingress_rules[*]}" "allow-destination filtering rule"
}

test_cleanup_removes_duplicate_state()
{
    local ipset_name

    mock_reset
    mock_jump_counts["-o|${otbr_forward_ingress_chain}"]=3
    mock_jump_counts["-i|${otbr_forward_egress_chain}"]=2
    mock_chains["${otbr_forward_ingress_chain}"]=1
    mock_chains["${otbr_forward_egress_chain}"]=1
    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        mock_sets["${ipset_name}"]=1
    done

    mock_set_destroy_failures["otbr-ingress-deny-src"]=2
    otbr_firewall_cleanup

    assert_eq 2 "${mock_sleep_calls}" "transient ipset retry count"
    assert_firewall_state_clean
}

test_cleanup_failures_are_bounded()
{
    mock_reset
    mock_jump_counts["-o|${otbr_forward_ingress_chain}"]=1
    mock_fail_rule_delete=1
    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly succeeded with an undeletable jump"
    fi
    assert_eq 1 "${mock_rule_delete_calls}" \
        "undeletable jump attempt count"

    mock_reset
    mock_sets["otbr-ingress-deny-src"]=1
    mock_set_destroy_failures["otbr-ingress-deny-src"]=999
    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly succeeded with a persistent ipset reference"
    fi
    assert_eq "$((otbr_ipset_destroy_attempts - 1))" \
        "${mock_sleep_calls}" "persistent ipset retry delay count"

    mock_reset
    mock_jump_counts["-o|${otbr_forward_ingress_chain}"]=$((
        otbr_cleanup_max_rule_deletes + 1
    ))
    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly accepted excessive duplicate jumps"
    fi
    assert_eq "${otbr_cleanup_max_rule_deletes}" \
        "${mock_rule_delete_calls}" "duplicate jump deletion bound"

    mock_reset
    mock_chains["${otbr_forward_ingress_chain}"]=1
    mock_fail_chain_delete=1
    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly succeeded with an undeletable chain"
    fi
    assert_eq 1 "${mock_chains["${otbr_forward_ingress_chain}"]}" \
        "undeletable chain remains visible for the next reconciliation attempt"
}

test_setup_failure_rolls_back_partial_state()
{
    mock_reset
    if otbr_firewall_setup invalid; then
        fail "setup unexpectedly accepted an invalid firewall mode"
    else
        assert_eq 2 "$?" "invalid firewall mode return code"
    fi
    assert_firewall_state_clean

    mock_reset
    # Four ipset calls precede ip6tables. Fail creating the egress chain after
    # the ingress chain and jump have already been installed.
    mock_fail_ip6_call=3
    if otbr_firewall_setup true; then
        fail "setup unexpectedly succeeded after an injected ip6tables failure"
    fi
    assert_firewall_state_clean
}

test_restart_and_mode_transitions()
{
    mock_reset
    otbr_firewall_setup true
    otbr_firewall_cleanup
    otbr_firewall_setup false
    assert_eq 1 "${#mock_ingress_rules[@]}" \
        "enabled-to-disabled ingress rule replacement"
    otbr_firewall_cleanup
    assert_firewall_state_clean

    otbr_firewall_setup false
    otbr_firewall_cleanup
    otbr_firewall_setup true
    assert_eq 5 "${#mock_ingress_rules[@]}" \
        "disabled-to-enabled ingress rule replacement"
    otbr_firewall_cleanup
    assert_firewall_state_clean
}

test_service_script_invariants()
{
    local file
    for file in "${COMMON_SCRIPT}" "${RUN_SCRIPT}" \
        "${FINISH_SCRIPT}" "${ENABLE_CHECK_SCRIPT}"; do
        bash -n "${file}"
    done

    if grep -RqsE 'ip6tables-legacy|ip6tables[[:space:]]+-P[[:space:]]+FORWARD' \
        "${COMMON_SCRIPT}" "${RUN_SCRIPT}" "${FINISH_SCRIPT}" \
        "${ENABLE_CHECK_SCRIPT}"; then
        fail "obsolete legacy or host-wide FORWARD policy command remains"
    fi

    local cleanup_line
    local setup_line
    cleanup_line="$(grep -n 'otbr_firewall_cleanup' "${RUN_SCRIPT}" \
        | head -n 1 | cut -d: -f1)"
    setup_line="$(grep -n 'otbr_firewall_setup' "${RUN_SCRIPT}" \
        | head -n 1 | cut -d: -f1)"
    (( cleanup_line < setup_line )) \
        || fail "startup cleanup must precede firewall setup"

    grep -q 'otbr_firewall_cleanup' "${FINISH_SCRIPT}" \
        || fail "finish script does not invoke shared cleanup"
    grep -q 'otbr_firewall_cleanup' "${ENABLE_CHECK_SCRIPT}" \
        || fail "disabled OTBR path does not invoke shared cleanup"
}

main()
{
    test_disabled_setup_is_scoped
    test_enabled_setup_preserves_filtering
    test_cleanup_removes_duplicate_state
    test_cleanup_failures_are_bounded
    test_setup_failure_rolls_back_partial_state
    test_restart_and_mode_transitions
    test_service_script_invariants
    printf 'PASS: OTBR firewall lifecycle tests\n'
}

main "$@"
