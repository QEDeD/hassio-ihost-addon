#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly DOCKERFILE="${ADDON_DIR}/Dockerfile"
readonly BUILD_FILE="${ADDON_DIR}/build.yaml"
readonly RUN_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"
readonly TIMEOUT_FINISH_FILE="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish"
readonly ENABLE_CHECK_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-enable-check.sh"

# The test invokes the shared functions with stateful command mocks. The service
# scripts themselves are checked for syntax and caller-level invariants below.
# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON_SCRIPT}"

declare -A mock_chains
declare -A mock_jump_counts
declare -A mock_sets
declare -A mock_set_destroy_failures
declare -A mock_chain_rule_counts
declare -A mock_ip6_operation_status
declare -A mock_timeout_command_status
declare -a mock_ingress_rules
declare -a mock_egress_rules
declare -a mock_command_log
declare -i mock_ip6_call_count
declare -i mock_fail_ip6_call
declare -i mock_ip6_elapsed_milliseconds
declare -i mock_ipset_destroy_calls
declare -i mock_ipset_create_calls
declare -i mock_ipset_list_status
declare -i mock_fail_ipset_create_call
declare -i mock_ip_link_status
declare -i mock_thread_if_present
declare mock_ip_link_output
declare -i mock_now_milliseconds
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

run_start_script_fixture()
{
    local cleanup_status="$1"
    local setup_status="$2"
    local firewall_config_true="${3:-false}"
    local configured_backbone="${4-}"
    local supervisor_backbone="${5-eth0}"
    local existing_interfaces="${6-eth0}"
    local supervisor_status="${7:-0}"
    local script

    script="$(sed \
        -e 's#^[[:space:]]*\. /etc/s6-overlay/scripts/otbr-agent-common.*$#    :#' \
        -e 's#^mkdir -p /data/thread.*$#:#' \
        -e '\@/tmp/otbr-agent-rest-api@c\:' \
        "${RUN_SCRIPT}")"

    (
        function bashio::api.supervisor() {
            (( supervisor_status == 0 )) || return "${supervisor_status}"
            printf '%s' "${supervisor_backbone}"
        }
        function bashio::addon.ip_address() { printf '::1'; }
        function bashio::addon.port() { :; }
        function bashio::config() {
            case "$1" in
                backbone_interface)
                    printf '%s' "${configured_backbone}"
                    ;;
                otbr_log_level)
                    printf 'notice'
                    ;;
                *)
                    return 2
                    ;;
            esac
        }
        function bashio::config.has_value() {
            [[ "$1" == "backbone_interface" \
                && -n "${configured_backbone}" ]]
        }
        function bashio::config.true() {
            [[ "$1" == "otbr_firewall" \
                && "${firewall_config_true}" == "true" ]]
        }
        function bashio::exit.nok() {
            printf 'EXIT: %s\n' "${1:-startup failed}" >&2
            exit 42
        }
        function bashio::log.info() { :; }
        function bashio::log.warning() { :; }
        function bashio::string.lower() { printf '%s' "$1"; }
        function bashio::var.has_value() { return 1; }
        function ip() {
            [[ "$*" == "link show dev "* ]] || return 2
            [[ " ${existing_interfaces} " == *" ${4:-} "* ]]
        }

        otbr_firewall_cleanup() {
            otbr_test_events+="cleanup;"
            return "${cleanup_status}"
        }
        otbr_firewall_setup() {
            otbr_test_events+="setup:$1;"
            return "${setup_status}"
        }
        exec() {
            otbr_test_events+="exec;"
            otbr_test_exec_args="$*"
        }

        otbr_test_events=""
        otbr_test_exec_args=""

        eval "${script}"
        printf '%s|%s\n' "${otbr_test_events}" "${otbr_test_exec_args}"
    )
}

run_finish_script_fixture()
{
    local cleanup_status="$1"
    local run_status="$2"
    local run_signal="$3"
    local script

    script="$(sed \
        -e 's#^[[:space:]]*\. /etc/s6-overlay/scripts/otbr-agent-common.*$#    :#' \
        -e 's#^[[:space:]]*echo "\$e" > /run/s6-linux-init-container-results/exitcode.*$#    otbr_test_written_exitcode="\$e"; otbr_test_events+="exitcode;"#' \
        -e 's#^[[:space:]]*/run/s6/basedir/bin/halt.*$#    otbr_test_halt_called=1; otbr_test_events+="halt;"#' \
        -e 's#^[[:space:]]*exit 125.*$#    otbr_test_finish_status=125#' \
        "${FINISH_SCRIPT}")"

    (
        function bashio::log.info() { :; }
        function bashio::log.warning() { :; }

        otbr_firewall_cleanup() {
            otbr_test_events+="cleanup;"
            return "${cleanup_status}"
        }
        otbr_test_halt_called=0
        otbr_test_written_exitcode=""
        otbr_test_finish_status=0
        otbr_test_events=""
        set -- "${run_status}" "${run_signal}"

        eval "${script}"
        printf '%s|%s|%s|%s\n' \
            "${otbr_test_written_exitcode:-none}" \
            "${otbr_test_halt_called}" \
            "${otbr_test_finish_status}" \
            "${otbr_test_events}"
    )
}

run_disabled_script_fixture()
{
    local guard_status="$1"
    local cleanup_status="$2"
    local script

    script="$(sed \
        -e 's#^[[:space:]]*\. /etc/s6-overlay/scripts/otbr-agent-common.*$#    :#' \
        -e 's#^[[:space:]]*rm /etc/s6-overlay/.*$#    :#' \
        -e 's#^[[:space:]]*bashio::exit.ok.*$#    return 0#' \
        "${ENABLE_CHECK_SCRIPT}")"

    (
        function bashio::config.false() { return 0; }
        function bashio::log.info() { :; }
        function bashio::log.warning() {
            otbr_test_warnings+="$*;"
        }

        otbr_disabled_cleanup_is_safe() {
            otbr_cleanup_guard_reason="fixture guard"
            return "${guard_status}"
        }
        otbr_firewall_cleanup() {
            otbr_test_cleanup_calls=$((otbr_test_cleanup_calls + 1))
            return "${cleanup_status}"
        }

        otbr_test_cleanup_calls=0
        otbr_test_warnings=""

        otbr_test_run_enable_check()
        {
            eval "${script}"
        }

        otbr_test_run_enable_check
        printf '%s|%s\n' \
            "${otbr_test_cleanup_calls}" "${otbr_test_warnings}"
    )
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
    mock_ip6_operation_status=()
    mock_timeout_command_status=()

    mock_chain_rule_counts=()
    mock_chain_rule_counts["${otbr_forward_ingress_chain}"]=0
    mock_chain_rule_counts["${otbr_forward_egress_chain}"]=0

    mock_ingress_rules=()
    mock_egress_rules=()
    mock_command_log=()

    mock_ip6_call_count=0
    mock_fail_ip6_call=0
    mock_ip6_elapsed_milliseconds=0
    mock_ipset_destroy_calls=0
    mock_ipset_create_calls=0
    mock_ipset_list_status=0
    mock_fail_ipset_create_call=0
    mock_ip_link_status=0
    mock_thread_if_present=0
    mock_ip_link_output=""
    mock_now_milliseconds=0
    mock_rule_delete_calls=0
    mock_sleep_calls=0
    mock_fail_rule_delete=0
    mock_fail_chain_delete=0
}

ip6tables()
{
    mock_command_log+=("ip6tables $*")
    mock_ip6_call_count=$((mock_ip6_call_count + 1))

    local -a args=("$@")
    if [[ "${args[0]:-}" != "-w" ]] \
        || ! [[ "${args[1]:-}" =~ ^[1-9][0-9]*$ ]]; then
        fail "ip6tables command did not use the configured xtables wait: $*"
    fi
    local wait_seconds="${args[1]}"
    args=("${args[@]:2}")

    local operation="${args[0]:-}"
    local chain_name
    local interface_flag
    local jump_key
    local rule
    local forced_status

    case "${operation}" in
        -N|-I|-A)
            assert_eq "${otbr_iptables_wait_seconds}" "${wait_seconds}" \
                "setup xtables wait"
            ;;
        *)
            if (( wait_seconds > otbr_cleanup_iptables_wait_seconds )); then
                fail "cleanup xtables wait exceeded its cap: $*"
            fi
            ;;
    esac

    mock_now_milliseconds=$((
        mock_now_milliseconds + mock_ip6_elapsed_milliseconds
    ))

    if (( mock_fail_ip6_call > 0 \
        && mock_ip6_call_count == mock_fail_ip6_call )); then
        return 1
    fi

    forced_status="${mock_ip6_operation_status["${operation}"]:-0}"
    if (( forced_status != 0 )); then
        return "${forced_status}"
    fi

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
            # iptables-nft reports a missing custom jump target as an
            # operational error, not as an ordinary absent-rule result.
            [[ ${mock_chains["${chain_name}"]:-0} -eq 1 ]] || return 2
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
            mock_ipset_create_calls=$((mock_ipset_create_calls + 1))
            if (( mock_fail_ipset_create_call > 0 \
                && mock_ipset_create_calls == mock_fail_ipset_create_call )); then
                return 1
            fi
            mock_sets["${ipset_name}"]=1
            ;;
        list)
            [[ "${1:-}" == "-n" && -z "${2:-}" ]] || return 2
            (( mock_ipset_list_status == 0 )) \
                || return "${mock_ipset_list_status}"
            for ipset_name in "${!mock_sets[@]}"; do
                if [[ ${mock_sets["${ipset_name}"]:-0} -eq 1 ]]; then
                    printf '%s\n' "${ipset_name}"
                fi
            done
            ;;
        destroy)
            ipset_name="${1:-}"
            mock_ipset_destroy_calls=$((mock_ipset_destroy_calls + 1))
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

ip()
{
    [[ "$*" == "-o link show" ]] || return 2
    (( mock_ip_link_status == 0 )) || return "${mock_ip_link_status}"

    if [[ -n "${mock_ip_link_output}" ]]; then
        printf '%s' "${mock_ip_link_output}"
        return
    fi

    printf '1: lo: <LOOPBACK,UP> mtu 65536\n'
    if (( mock_thread_if_present != 0 )); then
        printf '7: %s@if8: <BROADCAST,UP> mtu 1280\n' "${thread_if}"
    fi
}

timeout()
{
    local command_name
    local forced_status
    local kill_grace_duration

    printf -v kill_grace_duration '%d.%03ds' \
        "$((otbr_cleanup_kill_grace_milliseconds / 1000))" \
        "$((otbr_cleanup_kill_grace_milliseconds % 1000))"

    [[ "${1:-}" == "--foreground" ]] || return 2
    shift
    [[ "${1:-}" == "--kill-after=${kill_grace_duration}" ]] || return 2
    shift
    [[ "${1:-}" =~ ^[0-9]+\.[0-9]{3}s$ ]] || return 2
    shift

    command_name="${1:-}"
    forced_status="${mock_timeout_command_status["${command_name}"]:-0}"
    if (( forced_status != 0 )); then
        return "${forced_status}"
    fi

    "$@"
}

_otbr_clock_milliseconds()
{
    REPLY="${mock_now_milliseconds}"
}

sleep()
{
    local delay_duration

    printf -v delay_duration '%d.%03ds' \
        "$((otbr_ipset_destroy_delay_milliseconds / 1000))" \
        "$((otbr_ipset_destroy_delay_milliseconds % 1000))"
    assert_eq "${delay_duration}" "${1:-}" "ipset retry delay"

    mock_sleep_calls=$((mock_sleep_calls + 1))
    mock_now_milliseconds=$((
        mock_now_milliseconds + otbr_ipset_destroy_delay_milliseconds
    ))
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

assert_setup_jump_positions()
{
    local ingress_jump
    local egress_jump

    ingress_jump="ip6tables -w ${otbr_iptables_wait_seconds} -I FORWARD 1 -o ${thread_if} -j ${otbr_forward_ingress_chain}"
    egress_jump="ip6tables -w ${otbr_iptables_wait_seconds} -I FORWARD 2 -i ${thread_if} -j ${otbr_forward_egress_chain}"

    assert_eq "${ingress_jump}" "${mock_command_log[5]:-}" \
        "ingress FORWARD jump position"
    assert_eq "${egress_jump}" "${mock_command_log[7]:-}" \
        "egress FORWARD jump position"
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
    assert_setup_jump_positions

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
    assert_eq "-m pkttype --pkt-type unicast -i ${thread_if} -j DROP" \
        "${mock_ingress_rules[0]}" "enabled ingress rule 1"
    assert_eq '-m set --match-set otbr-ingress-deny-src src -j DROP' \
        "${mock_ingress_rules[1]}" "enabled ingress rule 2"
    assert_eq '-m set --match-set otbr-ingress-allow-dst dst -j ACCEPT' \
        "${mock_ingress_rules[2]}" "enabled ingress rule 3"
    assert_eq '-m pkttype --pkt-type unicast -j DROP' \
        "${mock_ingress_rules[3]}" "enabled ingress rule 4"
    assert_eq '-j ACCEPT' "${mock_ingress_rules[4]}" \
        "enabled ingress rule 5"
    assert_eq '-j ACCEPT' "${mock_egress_rules[0]}" \
        "enabled egress rule"
    assert_setup_jump_positions
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
    mock_chains["${otbr_forward_ingress_chain}"]=1
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
    mock_chains["${otbr_forward_ingress_chain}"]=1
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

test_busy_ipset_does_not_starve_independent_sets()
{
    local busy_ipset="${otbr_firewall_ipsets[0]}"
    local ipset_name

    mock_reset
    for ipset_name in "${otbr_firewall_ipsets[@]}"; do
        mock_sets["${ipset_name}"]=1
    done
    mock_set_destroy_failures["${busy_ipset}"]=999

    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly succeeded with a persistently busy ipset"
    fi

    assert_eq 1 "${mock_sets["${busy_ipset}"]}" \
        "persistently busy ipset remains"
    for ipset_name in "${otbr_firewall_ipsets[@]:1}"; do
        assert_eq 0 "${mock_sets["${ipset_name}"]}" \
            "${ipset_name} was not starved by the busy ipset"
    done
    assert_eq "$((otbr_ipset_destroy_attempts - 1))" \
        "${mock_sleep_calls}" "busy ipset retry delay count"
}

test_cleanup_probe_statuses_are_preserved()
{
    local status

    mock_reset
    otbr_firewall_cleanup \
        || fail "missing iptables and ipset objects should be a clean state"
    otbr_firewall_cleanup \
        || fail "repeated cleanup of missing objects should remain idempotent"

    for status in 2 3 4; do
        mock_reset
        mock_chains["${otbr_forward_ingress_chain}"]=1
        mock_chains["${otbr_forward_egress_chain}"]=1
        mock_ip6_operation_status["-C"]="${status}"
        if otbr_firewall_cleanup; then
            fail "cleanup ignored ip6tables -C status ${status}"
        fi
    done

    for status in 2 3 4; do
        mock_reset
        mock_ip6_operation_status["-L"]="${status}"
        if otbr_firewall_cleanup; then
            fail "cleanup ignored ip6tables -L status ${status}"
        fi
    done

    for status in 1 2 3 4; do
        mock_reset
        mock_sets["otbr-ingress-deny-src"]=1
        mock_ipset_list_status="${status}"
        if otbr_firewall_cleanup; then
            fail "cleanup ignored all-ipset listing status ${status}"
        fi
        assert_eq 0 "${mock_ipset_destroy_calls}" \
            "ipset destroy calls after an unverified listing"
    done
}

test_cleanup_command_timeouts_are_preserved()
{
    mock_reset
    mock_timeout_command_status["ip6tables"]=124
    if otbr_firewall_cleanup; then
        fail "cleanup ignored a timed-out ip6tables command"
    fi
    assert_eq 0 "${mock_ip6_call_count}" \
        "timed-out ip6tables command execution"

    mock_reset
    mock_sets["otbr-ingress-deny-src"]=1
    mock_timeout_command_status["ipset"]=124
    if otbr_firewall_cleanup; then
        fail "cleanup ignored a timed-out ipset command"
    fi
    assert_eq 0 "${mock_ipset_destroy_calls}" \
        "ipset destroy calls after a timed-out listing"
}

test_cleanup_uses_one_shared_deadline()
{
    mock_reset
    mock_jump_counts["-o|${otbr_forward_ingress_chain}"]=100
    mock_chains["${otbr_forward_ingress_chain}"]=1
    mock_ip6_elapsed_milliseconds=1000

    if otbr_firewall_cleanup; then
        fail "cleanup unexpectedly completed after exhausting its deadline"
    fi

    assert_eq "${otbr_cleanup_budget_milliseconds}" \
        "${mock_now_milliseconds}" "cleanup wall-clock deadline"
    assert_eq 4 "${mock_ip6_call_count}" \
        "commands admitted before the shared deadline"
    assert_eq 0 "${mock_ipset_destroy_calls}" \
        "ipset work after the shared deadline"
}

test_disabled_cleanup_owner_guard()
{
    local fixture_result

    mock_reset
    mock_thread_if_present=1
    if otbr_disabled_cleanup_is_safe; then
        fail "disabled cleanup ignored an existing ${thread_if}"
    fi
    assert_contains "${thread_if} already exists" \
        "${otbr_cleanup_guard_reason}" "foreign-owner guard reason"

    mock_reset
    mock_ip_link_output=$'1: lo: <LOOPBACK,UP> mtu 65536\n7: wpan0: <BROADCAST,UP> mtu 1280\n'
    if otbr_disabled_cleanup_is_safe; then
        fail "disabled cleanup ignored an unqualified ${thread_if} name"
    fi

    mock_reset
    mock_ip_link_output=$'1: lo: <LOOPBACK,UP> mtu 65536\n7: upstream-wpan0@if8: <BROADCAST,UP> mtu 1280\n8: wpan00: <BROADCAST,UP> mtu 1280\n'
    otbr_disabled_cleanup_is_safe \
        || fail "disabled cleanup misidentified a similarly named interface"

    mock_reset
    mock_ip_link_status=4
    if otbr_disabled_cleanup_is_safe; then
        fail "disabled cleanup proceeded after interface inspection failed"
    fi
    assert_contains "could not be inspected" \
        "${otbr_cleanup_guard_reason}" "interface-probe guard reason"

    mock_reset
    otbr_disabled_cleanup_is_safe \
        || fail "disabled cleanup was blocked with no ${thread_if}"

    fixture_result="$(run_disabled_script_fixture 1 0)"
    assert_contains '0|Skipping stale OTBR firewall cleanup' \
        "${fixture_result}" "guarded disabled caller policy"

    fixture_result="$(run_disabled_script_fixture 0 1)"
    assert_contains '1|Could not completely clean up stale OTBR firewall state' \
        "${fixture_result}" "best-effort disabled caller policy"
}

test_service_caller_failure_policies()
{
    local fixture_result
    local fixture_status

    if run_start_script_fixture 1 0 2>/dev/null; then
        fail "run script continued after stale cleanup failed"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" "run cleanup failure policy"

    if run_start_script_fixture 0 1 2>/dev/null; then
        fail "run script continued after firewall setup failed"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" "run setup failure policy"

    fixture_result="$(run_finish_script_fixture 1 7 0)"
    assert_eq '7|1|125|exitcode;halt;cleanup;' "${fixture_result}" \
        "fatal process exit is persisted before cleanup"

    fixture_result="$(run_finish_script_fixture 1 256 15)"
    assert_eq '143|1|125|exitcode;halt;cleanup;' "${fixture_result}" \
        "fatal signal exit is persisted before cleanup"

    fixture_result="$(run_finish_script_fixture 1 0 0)"
    assert_eq 'none|0|0|cleanup;' "${fixture_result}" \
        "successful process exit cleans up and remains restartable"
}

test_service_caller_successful_modes()
{
    local exec_args
    local fixture_result
    local lifecycle_events

    fixture_result="$(run_start_script_fixture 0 0 true)"
    lifecycle_events="${fixture_result%%|*}"
    exec_args="${fixture_result#*|}"
    assert_eq "cleanup;setup:true;exec;" "${lifecycle_events}" \
        "enabled caller lifecycle"
    assert_contains "/usr/sbin/otbr-agent -I wpan0 -B eth0" "${exec_args}" \
        "enabled caller otbr-agent exec"

    fixture_result="$(run_start_script_fixture 0 0 false)"
    lifecycle_events="${fixture_result%%|*}"
    exec_args="${fixture_result#*|}"
    assert_eq "cleanup;setup:false;exec;" "${lifecycle_events}" \
        "disabled caller lifecycle"
    assert_contains "/usr/sbin/otbr-agent -I wpan0 -B eth0" "${exec_args}" \
        "disabled caller otbr-agent exec"
}

test_backbone_interface_selection()
{
    local exec_args
    local fixture_result
    local fixture_status

    fixture_result="$(
        run_start_script_fixture 0 0 false br0 eth0 "eth0 br0" 99
    )"
    exec_args="${fixture_result#*|}"
    assert_contains "/usr/sbin/otbr-agent -I wpan0 -B br0" "${exec_args}" \
        "configured backbone interface"

    if fixture_result="$(
        run_start_script_fixture 0 0 false "" "" "eth0" 2>&1
    )"; then
        fail "startup guessed a backbone interface after empty discovery"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" \
        "missing backbone interface status"
    assert_contains "Configure backbone_interface explicitly" \
        "${fixture_result}" "missing backbone interface diagnostic"
    assert_not_contains "/usr/sbin/otbr-agent" "${fixture_result}" \
        "agent startup after missing backbone discovery"

    if fixture_result="$(
        run_start_script_fixture 0 0 false missing0 eth0 "eth0 br0" 2>&1
    )"; then
        fail "startup accepted a nonexistent configured backbone interface"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" \
        "nonexistent backbone interface status"
    assert_contains "Backbone interface 'missing0' does not exist" \
        "${fixture_result}" "nonexistent backbone interface diagnostic"

    if fixture_result="$(
        run_start_script_fixture 0 0 false "" missing0 "eth0 br0" 2>&1
    )"; then
        fail "startup accepted a nonexistent Supervisor backbone interface"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" \
        "nonexistent Supervisor backbone interface status"
    assert_contains "Backbone interface 'missing0' does not exist" \
        "${fixture_result}" \
        "nonexistent Supervisor backbone interface diagnostic"
}

test_finish_timeout_has_cleanup_headroom()
{
    local finish_timeout_milliseconds

    finish_timeout_milliseconds="$(
        tr -d '[:space:]' < "${TIMEOUT_FINISH_FILE}"
    )"
    [[ "${finish_timeout_milliseconds}" =~ ^[1-9][0-9]*$ ]] \
        || fail "timeout-finish must contain positive milliseconds"

    if (( otbr_cleanup_budget_milliseconds \
        + otbr_cleanup_kill_grace_milliseconds \
        + otbr_cleanup_finish_headroom_milliseconds \
        >= finish_timeout_milliseconds )); then
        fail "cleanup budget and kill grace do not leave finish headroom"
    fi
}

test_setup_failure_rolls_back_partial_state()
{
    local firewall_enabled
    local ip6_setup_calls
    local setup_call

    mock_reset
    if otbr_firewall_setup invalid; then
        fail "setup unexpectedly accepted an invalid firewall mode"
    else
        assert_eq 2 "$?" "invalid firewall mode return code"
    fi
    assert_firewall_state_clean

    for firewall_enabled in false true; do
        for ((setup_call = 1; setup_call <= ${#otbr_firewall_ipsets[@]}; setup_call++)); do
            mock_reset
            mock_fail_ipset_create_call="${setup_call}"
            if otbr_firewall_setup "${firewall_enabled}"; then
                fail "setup unexpectedly succeeded after ipset failure ${setup_call} in ${firewall_enabled} mode"
            fi
            assert_firewall_state_clean
        done

        if [[ "${firewall_enabled}" == "true" ]]; then
            ip6_setup_calls=10
        else
            ip6_setup_calls=6
        fi

        for ((setup_call = 1; setup_call <= ip6_setup_calls; setup_call++)); do
            mock_reset
            mock_fail_ip6_call="${setup_call}"
            if otbr_firewall_setup "${firewall_enabled}"; then
                fail "setup unexpectedly succeeded after ip6tables failure ${setup_call} in ${firewall_enabled} mode"
            fi
            assert_firewall_state_clean
        done
    done
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
    grep -q 'otbr_disabled_cleanup_is_safe' "${ENABLE_CHECK_SCRIPT}" \
        || fail "disabled OTBR path does not guard a possible foreign owner"
    [[ -f "${TIMEOUT_FINISH_FILE}" ]] \
        || fail "otbr-agent has no explicit finish timeout"
    grep -qE 'unzip[[:space:]]+-q[[:space:]]+slc_cli_linux\.zip' \
        "${DOCKERFILE}" \
        || fail "SLC extraction must remain quiet enough for CI logs"
    grep -qE '^  SLC_CLI_SHA256: [0-9a-f]{64}$' "${BUILD_FILE}" \
        || fail "SLC archive checksum must be a lowercase SHA-256"
    grep -qE 'sha256sum[[:space:]]+--check[[:space:]]+--strict' \
        "${DOCKERFILE}" \
        || fail "SLC archive must be verified before extraction"
    grep -Fq 'io.hass.version="${BUILD_VERSION}"' "${DOCKERFILE}" \
        || fail "image version label must use BUILD_VERSION"
    grep -Fq 'io.hass.type="app"' "${DOCKERFILE}" \
        || fail "image type label must identify a Home Assistant app"
    grep -Fq 'io.hass.arch="${BUILD_ARCH}"' "${DOCKERFILE}" \
        || fail "image architecture label must use BUILD_ARCH"
    grep -Fq 'org.opencontainers.image.version="${BUILD_VERSION}"' \
        "${DOCKERFILE}" \
        || fail "OCI image version label must use BUILD_VERSION"
    grep -Fq \
        'org.opencontainers.image.source="https://github.com/iHost-Open-Source-Project/hassio-ihost-addon"' \
        "${DOCKERFILE}" \
        || fail "OCI image source label must identify the upstream repository"
    grep -Fq 'org.opencontainers.image.revision="${BUILD_COMMIT}"' \
        "${DOCKERFILE}" \
        || fail "OCI image revision label must use BUILD_COMMIT"
}

main()
{
    test_disabled_setup_is_scoped
    test_enabled_setup_preserves_filtering
    test_cleanup_removes_duplicate_state
    test_cleanup_failures_are_bounded
    test_busy_ipset_does_not_starve_independent_sets
    test_cleanup_probe_statuses_are_preserved
    test_cleanup_command_timeouts_are_preserved
    test_cleanup_uses_one_shared_deadline
    test_disabled_cleanup_owner_guard
    test_service_caller_failure_policies
    test_service_caller_successful_modes
    test_backbone_interface_selection
    test_finish_timeout_has_cleanup_headroom
    test_setup_failure_rolls_back_partial_state
    test_restart_and_mode_transitions
    test_service_script_invariants
    printf 'PASS: OTBR firewall lifecycle tests\n'
}

main "$@"
