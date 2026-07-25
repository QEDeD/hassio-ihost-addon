#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly COMMON="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/otbr-agent-common"
readonly RUN="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run"
readonly FINISH="${ADDON_DIR}/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish"

# shellcheck source=../rootfs/etc/s6-overlay/scripts/otbr-agent-common
# shellcheck disable=SC1090
source "${COMMON}"

declare caller_firewall_enabled=false
declare caller_nat64_enabled=false
declare caller_firewall_argument=""
declare -i caller_cleanup_calls=0
declare -i caller_cleanup_result=0
declare -i caller_rollback_result=0
declare -i caller_firewall_result=0
declare -i caller_nat64_result=0
declare -i caller_nat64_calls=0
declare -i caller_exec_calls=0
declare -i caller_finish_cleanup_result=0

bashio::api.supervisor() { printf 'eth0\n'; }
bashio::config()
{
    case "$1" in
        device) printf '/dev/ttyS4\n' ;;
        baudrate) printf '460800\n' ;;
        otbr_log_level) printf 'notice\n' ;;
        *) return 2 ;;
    esac
}
bashio::config.has_value() { return 1; }
bashio::config.true()
{
    case "$1" in
        flow_control) return 1 ;;
        firewall) [[ "${caller_firewall_enabled}" == "true" ]] ;;
        nat64) [[ "${caller_nat64_enabled}" == "true" ]] ;;
        *) return 2 ;;
    esac
}
bashio::string.lower() { printf '%s\n' "$1"; }
bashio::log.info() { :; }
bashio::log.warning() { :; }
bashio::addon.port() { :; }
bashio::addon.ip_address() { printf '::1\n'; }
bashio::var.has_value() { return 1; }
bashio::exit.nok() { return 99; }

cat() { printf '1\n'; }
mkdir() { :; }
ln() { :; }
exec()
{
    caller_exec_calls=$((caller_exec_calls + 1))
    return 0
}

otbr_netfilter_cleanup()
{
    [[ $# -eq 0 ]] || return 2
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
    [[ "$1" == eth0 ]] || return 2
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

for caller_firewall_enabled in false true; do
    for caller_nat64_enabled in false true; do
        caller_cleanup_calls=0
        caller_cleanup_result=0
        caller_rollback_result=0
        caller_firewall_argument=""
        caller_firewall_result=0
        caller_nat64_calls=0
        caller_nat64_result=0
        caller_exec_calls=0

        source_run

        [[ ${caller_cleanup_calls} -eq 1 ]]
        [[ "${caller_firewall_argument}" == "${caller_firewall_enabled}" ]]
        [[ ${caller_exec_calls} -eq 1 ]]
        if [[ "${caller_nat64_enabled}" == "true" ]]; then
            [[ ${caller_nat64_calls} -eq 1 ]]
        else
            [[ ${caller_nat64_calls} -eq 0 ]]
        fi
    done
done

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
        caller_finish_cleanup_result=1
        otbr_netfilter_cleanup()
        {
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

caller_output="$(
    (
        caller_finish_cleanup_result=1
        otbr_netfilter_cleanup()
        {
            return "${caller_finish_cleanup_result}"
        }
        source_finish 0 0
    ) 2>&1
)"
[[ "${caller_output}" != *"RECORDED_EXIT="* ]]
[[ "${caller_output}" != *"HALT_CALLED"* ]]

printf 'PASS: standalone OTBR run/finish caller behavior and config matrix\n'
