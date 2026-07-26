#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly CPCD_CONFIG_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/cpcd-config-up"
readonly CONFIG_FILE="${ADDON_DIR}/config.yaml"
readonly SOCAT_ENABLE_SCRIPT="${ADDON_DIR}/rootfs/etc/s6-overlay/scripts/socat-cpcd-tcp-enable-check.sh"

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

run_cpcd_config_fixture()
{
    local device_present="$1"
    local network_device_present="$2"
    local cpcd_trace_present="${3:-true}"

    (
        function bashio::config.has_value() {
            case "$1" in
                device)
                    [[ "${device_present}" == "true" ]]
                    ;;
                network_device)
                    [[ "${network_device_present}" == "true" ]]
                    ;;
                baudrate|flow_control)
                    return 0
                    ;;
                cpcd_trace)
                    [[ "${cpcd_trace_present}" == "true" ]]
                    ;;
                *)
                    return 1
                    ;;
            esac
        }
        function bashio::config() {
            case "$1" in
                device)
                    [[ "${device_present}" == "true" ]] || return 99
                    printf '/dev/ttyUSB0'
                    ;;
                network_device)
                    [[ "${network_device_present}" == "true" ]] || return 99
                    printf 'radio.example:12345'
                    ;;
                baudrate)
                    printf '115200'
                    ;;
                flow_control)
                    printf 'false'
                    ;;
                cpcd_trace)
                    [[ "${cpcd_trace_present}" == "true" ]] || return 99
                    printf 'false'
                    ;;
            esac
        }
        function bashio::exit.nok() { exit 42; }
        function bashio::log.fatal() { printf 'fatal=%s\n' "$*" >&2; }
        function bashio::log.info() { :; }
        function bashio::var.json() {
            while (( $# > 0 )); do
                printf '%s=%s\n' "$1" "$2"
                shift 2
            done
        }
        function tempio() { cat; }

        # Ignore the container-only interpreter line while exercising the exact
        # production script body with controlled bashio and tempio fixtures.
        eval "$(sed '1d' "${CPCD_CONFIG_SCRIPT}")"
    )
}

run_socat_enable_fixture()
{
    local network_device_present="$1"

    (
        function bashio::config.has_value() {
            [[ "$1" == "network_device" \
                && "${network_device_present}" == "true" ]]
        }
        function bashio::log.info() { :; }
        function touch() { printf '%s\n' "$1"; }

        eval "$(sed '1d' "${SOCAT_ENABLE_SCRIPT}")"
    )
}

generated_config_value()
{
    local name="$1"
    local generated="$2"

    awk -F= -v name="${name}" '$1 == name { print $2 }' <<< "${generated}"
}

test_network_device_without_local_device()
{
    local generated

    generated="$(run_cpcd_config_fixture false true)"
    assert_eq '/tmp/ttyCPC' "$(generated_config_value device "${generated}")" \
        "network-only CPC device"
}

test_local_device_without_network_device()
{
    local generated

    generated="$(run_cpcd_config_fixture true false)"
    assert_eq '/dev/ttyUSB0' "$(generated_config_value device "${generated}")" \
        "local CPC device"
}

test_network_device_takes_precedence()
{
    local generated

    generated="$(run_cpcd_config_fixture true true)"
    assert_eq '/tmp/ttyCPC' "$(generated_config_value device "${generated}")" \
        "network CPC device precedence"
}

test_trace_defaults_to_disabled()
{
    local generated

    generated="$(run_cpcd_config_fixture true false false)"
    assert_eq 'false' \
        "$(generated_config_value cpcd_trace "${generated}")" \
        "missing CPC trace option default"
}

test_device_schema_is_optional()
{
    tr -d '\r' < "${CONFIG_FILE}" | grep -Fqx '  device: null' \
        || fail "default local device must remain null"
    tr -d '\r' < "${CONFIG_FILE}" \
        | grep -Fqx '  device: device(subsystem=tty)?' \
        || fail "local device schema must remain optional"
    tr -d '\r' < "${CONFIG_FILE}" \
        | grep -Fqx '  backbone_interface: null' \
        || fail "backbone interface default must remain optional"
    tr -d '\r' < "${CONFIG_FILE}" \
        | grep -Fqx '  backbone_interface: str?' \
        || fail "backbone interface schema must remain optional"
}

test_missing_device_is_rejected()
{
    local fixture_output
    local fixture_status

    if fixture_output="$(run_cpcd_config_fixture false false 2>&1)"; then
        fail "CPC configuration accepted neither a local nor network device"
    else
        fixture_status=$?
    fi
    assert_eq 42 "${fixture_status}" "missing CPC device status"
    assert_contains 'Neither a local device nor network_device is configured!' \
        "${fixture_output}" "missing CPC device diagnostic"
}

test_network_service_selection()
{
    local fixture_output
    local expected

    fixture_output="$(run_socat_enable_fixture true)"
    expected=$'/etc/s6-overlay/s6-rc.d/user/contents.d/socat-cpcd-tcp\n/etc/s6-overlay/s6-rc.d/cpcd/dependencies.d/socat-cpcd-tcp'
    assert_eq "${expected}" "${fixture_output}" \
        "network CPC proxy service selection"

    fixture_output="$(run_socat_enable_fixture false)"
    assert_eq '' "${fixture_output}" \
        "local CPC mode must not enable the network proxy"
}

main()
{
    bash -n "${CPCD_CONFIG_SCRIPT}"
    bash -n "${SOCAT_ENABLE_SCRIPT}"
    test_device_schema_is_optional
    test_network_device_without_local_device
    test_local_device_without_network_device
    test_network_device_takes_precedence
    test_trace_defaults_to_disabled
    test_missing_device_is_rejected
    test_network_service_selection
    printf 'PASS: CPC device configuration tests\n'
}

main "$@"
