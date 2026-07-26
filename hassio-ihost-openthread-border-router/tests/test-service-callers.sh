#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"
readonly FLASHER="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/universal-silabs-flasher-up"
readonly ENABLE_CHECK="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/enable-check.sh"

# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON}"

fail()
{
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

test_cleanup_ownership_helpers()
{
    local claim_status
    local original_claim_file="${otbr_firewall_cleanup_claim_file}"
    local test_claim_file

    test_claim_file="$(mktemp)"
    otbr_firewall_cleanup_claim_file="${test_claim_file}"

    otbr_firewall_cleanup_claim_reset \
        || fail "cleanup claim reset failed"
    [[ ! -e "${test_claim_file}" ]] \
        || fail "cleanup claim reset left a marker"

    otbr_firewall_cleanup_claim_create \
        || fail "cleanup claim creation failed"
    [[ -f "${test_claim_file}" ]] \
        || fail "cleanup claim creation left no marker"

    otbr_firewall_cleanup_claim_consume \
        || fail "cleanup claim consumption failed"
    [[ ! -e "${test_claim_file}" ]] \
        || fail "cleanup claim consumption left a marker"

    if otbr_firewall_cleanup_claim_consume; then
        fail "missing cleanup claim was accepted"
    else
        claim_status=$?
    fi
    [[ ${claim_status} -eq 1 ]] \
        || fail "missing cleanup claim returned ${claim_status}"

    otbr_firewall_cleanup_claim_create
    rm() { return 1; }
    if otbr_firewall_cleanup_claim_consume; then
        fail "unremovable cleanup claim was accepted"
    else
        claim_status=$?
    fi
    unset -f rm
    [[ ${claim_status} -eq 2 ]] \
        || fail "unremovable cleanup claim returned ${claim_status}"
    command rm -f -- "${test_claim_file}"

    declare mock_owner_output=""
    declare -i mock_owner_status=0
    _otbr_now_milliseconds()
    {
        otbr_now_milliseconds=100
    }
    _otbr_run_until()
    {
        [[ "$1" == "1100" ]] || return 98
        shift
        [[ "$*" == "ip -o link show" ]] || return 97
        printf '%s' "${mock_owner_output}"
        return "${mock_owner_status}"
    }

    mock_owner_output=$'1: lo: <LOOPBACK,UP> mtu 65536\n'
    otbr_firewall_cleanup_is_safe \
        || fail "owner probe rejected a clean namespace"

    mock_owner_output=$'1: lo: <LOOPBACK,UP> mtu 65536\n7: upstream-wpan0@if8: <BROADCAST,UP> mtu 1280\n8: wpan00: <BROADCAST,UP> mtu 1280\n'
    otbr_firewall_cleanup_is_safe \
        || fail "owner probe matched a non-exact interface name"

    mock_owner_output=$'7: wpan0@if8: <BROADCAST,UP> mtu 1280\n'
    if otbr_firewall_cleanup_is_safe; then
        fail "owner probe accepted an existing wpan0"
    fi
    [[ "${otbr_cleanup_guard_reason}" == *"managed by another OTBR implementation"* ]] \
        || fail "owner probe did not explain the existing wpan0"

    mock_owner_output=""
    mock_owner_status=2
    if otbr_firewall_cleanup_is_safe; then
        fail "owner probe accepted an interface inspection failure"
    fi
    [[ "${otbr_cleanup_guard_reason}" == "network interfaces could not be inspected" ]] \
        || fail "owner probe did not explain its inspection failure"

    otbr_firewall_cleanup_claim_file="${original_claim_file}"
}

test_cleanup_ownership_helpers

declare caller_firewall_enabled=false
declare caller_nat64_enabled=false
declare caller_configured_backbone=""
declare caller_supervisor_backbone="eth0"
declare caller_existing_interfaces="eth0 br0"
declare caller_local_device="/dev/ttyS4"
declare caller_network_device=""
declare caller_firewall_argument=""
declare caller_nat64_argument=""
declare caller_exec_arguments=""
declare caller_events=""
declare -i caller_cleanup_calls=0
declare -i caller_cleanup_result=0
declare -i caller_cleanup_safe_result=0
declare -i caller_claim_reset_result=0
declare -i caller_claim_create_result=0
declare -i caller_rollback_result=0
declare -i caller_firewall_result=0
declare -i caller_nat64_result=0
declare -i caller_nat64_calls=0
declare -i caller_exec_calls=0
declare -i caller_finish_cleanup_result=0
declare -i caller_finish_claim_result=0

bashio::api.supervisor()
{
    printf '%s\n' "${caller_supervisor_backbone}"
}
bashio::config()
{
    case "$1" in
        backbone_interface) printf '%s\n' "${caller_configured_backbone}" ;;
        device) printf '%s\n' "${caller_local_device}" ;;
        network_device) printf '%s\n' "${caller_network_device}" ;;
        baudrate) printf '460800\n' ;;
        otbr_log_level) printf 'notice\n' ;;
        *) return 2 ;;
    esac
}
bashio::config.has_value()
{
    case "$1" in
        backbone_interface) [[ -n "${caller_configured_backbone}" ]] ;;
        device) [[ -n "${caller_local_device}" ]] ;;
        network_device) [[ -n "${caller_network_device}" ]] ;;
        *) return 2 ;;
    esac
}
bashio::config.true()
{
    case "$1" in
        flow_control) return 1 ;;
        firewall) [[ "${caller_firewall_enabled}" == "true" ]] ;;
        nat64) [[ "${caller_nat64_enabled}" == "true" ]] ;;
        *) return 2 ;;
    esac
}
bashio::config.false() { return 1; }
bashio::string.lower() { printf '%s\n' "$1"; }
bashio::log.info() { :; }
bashio::log.warning() { :; }
bashio::addon.port() { :; }
bashio::addon.ip_address() { printf '::1\n'; }
bashio::var.has_value() { return 1; }
bashio::exit.nok() { return 99; }

cat() { printf '1\n'; }
ip()
{
    [[ "$*" == "link show dev "* ]] || return 2
    [[ " ${caller_existing_interfaces} " == *" ${4} "* ]]
}
mkdir() { :; }
ln() { :; }
exec()
{
    caller_exec_calls=$((caller_exec_calls + 1))
    caller_exec_arguments="$*"
    return 0
}

otbr_firewall_cleanup_claim_reset()
{
    caller_events+="claim-reset;"
    return "${caller_claim_reset_result}"
}

otbr_firewall_cleanup_is_safe()
{
    caller_events+="guard;"
    otbr_cleanup_guard_reason="wpan0 may be managed by another OTBR implementation"
    return "${caller_cleanup_safe_result}"
}

otbr_firewall_cleanup_claim_create()
{
    caller_events+="claim-create;"
    return "${caller_claim_create_result}"
}

otbr_firewall_cleanup_claim_consume()
{
    printf 'CLAIM_CONSUMED\n'
    return "${caller_finish_claim_result}"
}

otbr_netfilter_cleanup()
{
    [[ $# -eq 0 ]] || return 2
    caller_events+="cleanup;"
    caller_cleanup_calls=$((caller_cleanup_calls + 1))
    if (( caller_cleanup_calls == 1 )); then
        return "${caller_cleanup_result}"
    fi
    return "${caller_rollback_result}"
}

otbr_firewall_setup()
{
    caller_firewall_argument="$1"
    return "${caller_firewall_result}"
}

otbr_nat64_setup()
{
    caller_nat64_calls=$((caller_nat64_calls + 1))
    caller_nat64_argument="$1"
    return "${caller_nat64_result}"
}

source_run()
{
    # Source a read-only transformed copy so the caller behavior is exercised
    # without requiring the container's absolute common path or writing /tmp.
    # shellcheck disable=SC1090
    source <(
        sed \
            -e 's/\r$//' \
            -e '\@^\. /etc/s6-overlay/scripts/otbr-agent-common$@c\:' \
            -e '\@/tmp/otbr-agent-rest-api@c\:' \
            "${RUN}"
    )
}

source_finish()
{
    # shellcheck disable=SC1090
    source <(
        sed \
            -e 's/\r$//' \
            -e '\@^\. /etc/s6-overlay/scripts/otbr-agent-common$@c\:' \
            -e '\@/run/s6-linux-init-container-results/exitcode@c\    printf "RECORDED_EXIT=%s\\n" "${e}"' \
            -e '\@/run/s6/basedir/bin/halt@c\    printf "HALT_CALLED\\n"' \
            "${FINISH}"
    ) "$1" "$2"
}

source_enable_check()
{
    # Absolute service paths are intercepted by the touch/rm fixtures below.
    # shellcheck disable=SC1090
    source <(sed -e 's/\r$//' "${ENABLE_CHECK}")
}

# A network-only RCP dynamically enables both the socat service and the
# otbr-agent dependency. Without network_device, neither marker is created.
enable_check_output="$(
    (
        bashio::addon.port() { printf 'exposed\n'; }
        bashio::var.has_value() { [[ -n "$1" ]]; }
        bashio::config.has_value() { return 1; }
        touch() { printf 'TOUCH:%s\n' "$*"; }
        rm() { printf 'RM:%s\n' "$*"; }
        source_enable_check
    ) 2>&1
)"
[[ "${enable_check_output}" != *"TOUCH:"* ]]
[[ "${enable_check_output}" != *"RM:"* ]]

enable_check_output="$(
    (
        bashio::addon.port() { printf 'exposed\n'; }
        bashio::var.has_value() { [[ -n "$1" ]]; }
        bashio::config.has_value() { [[ "$1" == "network_device" ]]; }
        touch() { printf 'TOUCH:%s\n' "$*"; }
        rm() { printf 'RM:%s\n' "$*"; }
        source_enable_check
    ) 2>&1
)"
[[ "${enable_check_output}" == *"TOUCH:/etc/s6-overlay/s6-rc.d/user/contents.d/socat-otbr-tcp"* ]]
[[ "${enable_check_output}" == *"TOUCH:/etc/s6-overlay/s6-rc.d/otbr-agent/dependencies.d/socat-otbr-tcp"* ]]
[[ "$(grep -c '^TOUCH:' <<< "${enable_check_output}")" -eq 2 ]]
[[ "${enable_check_output}" != *"RM:"* ]]

for caller_firewall_enabled in false true; do
    for caller_nat64_enabled in false true; do
        caller_cleanup_calls=0
        caller_cleanup_result=0
        caller_cleanup_safe_result=0
        caller_claim_reset_result=0
        caller_claim_create_result=0
        caller_rollback_result=0
        caller_events=""
        caller_firewall_argument=""
        caller_firewall_result=0
        caller_nat64_calls=0
        caller_nat64_argument=""
        caller_nat64_result=0
        caller_configured_backbone=""
        caller_supervisor_backbone="eth0"
        caller_local_device="/dev/ttyS4"
        caller_network_device=""
        caller_exec_calls=0
        caller_exec_arguments=""

        source_run

        [[ ${caller_cleanup_calls} -eq 1 ]]
        [[ "${caller_events}" == "claim-reset;guard;claim-create;cleanup;" ]]
        [[ "${caller_firewall_argument}" == "${caller_firewall_enabled}" ]]
        [[ ${caller_exec_calls} -eq 1 ]]
        [[ "${caller_exec_arguments}" == *"spinel+hdlc+uart:///dev/ttyS4?"* ]]
        if [[ "${caller_nat64_enabled}" == "true" ]]; then
            [[ ${caller_nat64_calls} -eq 1 ]]
            [[ "${caller_nat64_argument}" == "eth0" ]]
        else
            [[ ${caller_nat64_calls} -eq 0 ]]
        fi
    done
done

# A failed claim reset must stop before probing or mutating shared state.
set +e
caller_output="$(
    (
        caller_events=""
        caller_cleanup_calls=0
        caller_claim_reset_result=42
        bashio::exit.nok()
        {
            printf 'EXIT=%s\n' "$1"
            printf 'EVENTS=%s CLEANUP_CALLS=%s\n' \
                "${caller_events}" "${caller_cleanup_calls}"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"EVENTS=claim-reset; CLEANUP_CALLS=0"* ]]

# A pre-existing wpan0 may belong to Multiprotocol or another OTBR. Fail
# closed before claiming or reconciling any global netfilter state.
set +e
caller_output="$(
    (
        caller_events=""
        caller_cleanup_calls=0
        caller_claim_reset_result=0
        caller_cleanup_safe_result=1
        bashio::exit.nok()
        {
            printf 'EXIT=%s\n' "$1"
            printf 'EVENTS=%s CLEANUP_CALLS=%s\n' \
                "${caller_events}" "${caller_cleanup_calls}"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"managed by another OTBR implementation"* ]]
[[ "${caller_output}" == *"EVENTS=claim-reset;guard; CLEANUP_CALLS=0"* ]]

# If the ownership marker cannot be created, shared state is still unowned and
# must not be touched.
set +e
caller_output="$(
    (
        caller_events=""
        caller_cleanup_calls=0
        caller_claim_reset_result=0
        caller_cleanup_safe_result=0
        caller_claim_create_result=42
        bashio::exit.nok()
        {
            printf 'EVENTS=%s CLEANUP_CALLS=%s\n' \
                "${caller_events}" "${caller_cleanup_calls}"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"EVENTS=claim-reset;guard;claim-create; CLEANUP_CALLS=0"* ]]

# Restore the successful startup ownership fixture.
caller_claim_reset_result=0
caller_cleanup_safe_result=0
caller_claim_create_result=0

# An explicit interface takes precedence over Supervisor discovery and is used
# consistently for NAT64.
caller_cleanup_calls=0
caller_cleanup_result=0
caller_rollback_result=0
caller_firewall_result=0
caller_nat64_enabled=true
caller_nat64_calls=0
caller_nat64_argument=""
caller_nat64_result=0
caller_configured_backbone="br0"
caller_supervisor_backbone=""
caller_exec_calls=0
source_run
[[ ${caller_nat64_calls} -eq 1 ]]
[[ "${caller_nat64_argument}" == "br0" ]]
[[ ${caller_exec_calls} -eq 1 ]]

# Missing discovery must stop startup rather than silently selecting eth0.
set +e
caller_output="$(
    (
        caller_configured_backbone=""
        caller_supervisor_backbone=""
        bashio::exit.nok()
        {
            printf 'EXIT: %s\n' "$1"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"Configure backbone_interface explicitly"* ]]

# A configured name must exist in the host network namespace.
set +e
caller_output="$(
    (
        caller_configured_backbone="missing0"
        caller_supervisor_backbone="eth0"
        bashio::exit.nok()
        {
            printf 'EXIT: %s\n' "$1"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"Backbone interface 'missing0' does not exist"* ]]

# A network RCP is sufficient without a dummy serial device.
caller_cleanup_calls=0
caller_cleanup_result=0
caller_firewall_result=0
caller_nat64_enabled=false
caller_local_device=""
caller_network_device="rcp.example:6638"
caller_configured_backbone="br0"
caller_exec_calls=0
caller_exec_arguments=""
source_run
[[ ${caller_exec_calls} -eq 1 ]]
[[ "${caller_exec_arguments}" == *"spinel+hdlc+uart:///tmp/ttyOTBR?"* ]]

# The network RCP intentionally wins when both fields are populated.
caller_cleanup_calls=0
caller_local_device="/dev/ttyS4"
caller_network_device="rcp.example:6638"
caller_exec_calls=0
caller_exec_arguments=""
source_run
[[ ${caller_exec_calls} -eq 1 ]]
[[ "${caller_exec_arguments}" == *"spinel+hdlc+uart:///tmp/ttyOTBR?"* ]]
[[ "${caller_exec_arguments}" != *"spinel+hdlc+uart:///dev/ttyS4?"* ]]

# Neither input is an actionable RCP configuration.
set +e
caller_output="$(
    (
        caller_local_device=""
        caller_network_device=""
        bashio::exit.nok()
        {
            printf 'EXIT: %s\n' "$1"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
[[ "${caller_output}" == *"Set either device (serial) or network_device"* ]]

# Network mode must exit before the flasher attempts to read a local device.
flasher_output="$(
    (
        bashio::config()
        {
            if [[ "$1" == "device" ]]; then
                printf 'DEVICE_WAS_READ\n' >&2
                return 1
            fi
            return 2
        }
        bashio::config.has_value() { [[ "$1" == "network_device" ]]; }
        bashio::config.false() { return 1; }
        bashio::log.info() { printf 'LOG: %s\n' "$*"; }
        # shellcheck disable=SC1090
        source <(sed -e 's/\r$//' "${FLASHER}")
    ) 2>&1
)"
[[ "${flasher_output}" == *"Network device is selected, skipping firmware flashing"* ]]
[[ "${flasher_output}" != *"DEVICE_WAS_READ"* ]]

# Restore the ordinary local-only fixture for the remaining error-path tests.
caller_local_device="/dev/ttyS4"
caller_network_device=""

set +e
caller_output="$(
    (
        caller_cleanup_calls=0
        caller_cleanup_result=1
        bashio::exit.nok() { exit 42; }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]

set +e
caller_output="$(
    (
        caller_cleanup_calls=0
        caller_cleanup_result=0
        caller_firewall_result=1
        bashio::exit.nok() { exit 42; }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]

set +e
caller_output="$(
    (
        caller_cleanup_calls=0
        caller_cleanup_result=0
        caller_rollback_result=1
        caller_firewall_result=0
        caller_firewall_enabled=true
        caller_nat64_enabled=true
        caller_nat64_result=1
        bashio::exit.nok()
        {
            printf 'EXIT_CLEANUP_CALLS=%s\n' "${caller_cleanup_calls}"
            exit 42
        }
        source_run
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 42 ]]
grep -q '^EXIT_CLEANUP_CALLS=2$' <<< "${caller_output}"

set +e
caller_output="$(
    (
        caller_finish_claim_result=0
        caller_finish_cleanup_result=1
        otbr_netfilter_cleanup()
        {
            printf 'CLEANUP_CALLED\n'
            return "${caller_finish_cleanup_result}"
        }
        source_finish 7 0
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 125 ]]
grep -q '^RECORDED_EXIT=7$' <<< "${caller_output}"
grep -q '^HALT_CALLED$' <<< "${caller_output}"
[[ "${caller_output}" == *$'RECORDED_EXIT=7\nHALT_CALLED\nCLAIM_CONSUMED\nCLEANUP_CALLED'* ]]

set +e
caller_output="$(
    (
        caller_finish_claim_result=0
        caller_finish_cleanup_result=0
        otbr_netfilter_cleanup()
        {
            printf 'CLEANUP_CALLED\n'
            return "${caller_finish_cleanup_result}"
        }
        source_finish 256 15
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 125 ]]
[[ "${caller_output}" == *$'RECORDED_EXIT=143\nHALT_CALLED\nCLAIM_CONSUMED\nCLEANUP_CALLED'* ]]

caller_output="$(
    (
        caller_finish_claim_result=0
        caller_finish_cleanup_result=1
        otbr_netfilter_cleanup()
        {
            printf 'CLEANUP_CALLED\n'
            return "${caller_finish_cleanup_result}"
        }
        source_finish 0 0
    ) 2>&1
)"
[[ "${caller_output}" != *"RECORDED_EXIT="* ]]
[[ "${caller_output}" != *"HALT_CALLED"* ]]
[[ "${caller_output}" == $'CLAIM_CONSUMED\nCLEANUP_CALLED' ]]

# Missing or unconsumable claims mean startup never established teardown
# ownership. Both normal and fatal finishes must leave global state untouched.
caller_output="$(
    (
        caller_finish_claim_result=1
        otbr_netfilter_cleanup()
        {
            printf 'CLEANUP_CALLED\n'
            return 0
        }
        source_finish 0 0
    ) 2>&1
)"
[[ "${caller_output}" == "CLAIM_CONSUMED" ]]

set +e
caller_output="$(
    (
        caller_finish_claim_result=2
        otbr_netfilter_cleanup()
        {
            printf 'CLEANUP_CALLED\n'
            return 0
        }
        source_finish 7 0
    ) 2>&1
)"
caller_status=$?
set -e
[[ ${caller_status} -eq 125 ]]
[[ "${caller_output}" == *$'RECORDED_EXIT=7\nHALT_CALLED\nCLAIM_CONSUMED'* ]]
[[ "${caller_output}" != *"CLEANUP_CALLED"* ]]

printf 'PASS: standalone OTBR run/finish caller behavior and config matrix\n'
