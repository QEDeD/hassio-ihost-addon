#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR
ADDON_DIR="$(cd -- "${TEST_DIR}/.." && pwd)"
readonly ADDON_DIR
readonly BUILD_FILE="${ADDON_DIR}/build.yaml"
readonly OPENTHREAD_RECOVERY_PATCH="${ADDON_DIR}/openthread-patches/0002-spinel-Clear-source-match-tables-before-restoring.patch"
PATCH_TEST_SCRATCH=""

fail()
{
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

read_build_arg()
{
    local key="$1"

    awk -v key="${key}" '$1 == key ":" { print $2; exit }' "${BUILD_FILE}"
}

cleanup()
{
    if [[ -n "${PATCH_TEST_SCRATCH}" ]]; then
        rm -rf -- "${PATCH_TEST_SCRATCH}"
    fi
}

main()
{
    local expected_patch_sha256
    local sdk
    local sdk_revision
    local source_file

    sdk_revision="$(read_build_arg GECKO_SDK_VERSION)"
    expected_patch_sha256="$(
        read_build_arg OPENTHREAD_RECOVERY_PATCH_SHA256
    )"
    [[ -n "${sdk_revision}" ]] \
        || fail "Simplicity SDK revision is not configured"
    [[ "${expected_patch_sha256}" =~ ^[0-9a-f]{64}$ ]] \
        || fail "OpenThread recovery patch SHA-256 is invalid"
    [[ -f "${OPENTHREAD_RECOVERY_PATCH}" ]] \
        || fail "OpenThread recovery patch is missing"

    printf '%s  %s\n' "${expected_patch_sha256}" \
        "${OPENTHREAD_RECOVERY_PATCH}" \
        | sha256sum --check --strict -

    PATCH_TEST_SCRATCH="$(mktemp -d)"
    sdk="${PATCH_TEST_SCRATCH}/simplicity-sdk"
    trap cleanup EXIT

    git init --quiet "${sdk}"
    git -C "${sdk}" remote add origin \
        https://github.com/SiliconLabs/simplicity_sdk.git
    git -C "${sdk}" sparse-checkout init --cone
    git -C "${sdk}" sparse-checkout set \
        util/third_party/openthread/src/lib/spinel
    git -C "${sdk}" fetch --quiet --depth=1 --filter=blob:none \
        origin "refs/tags/${sdk_revision}"
    git -C "${sdk}" checkout --quiet --detach FETCH_HEAD

    git -C "${sdk}" apply --check --whitespace=error-all \
        --directory=util/third_party/openthread \
        "${OPENTHREAD_RECOVERY_PATCH}"
    git -C "${sdk}" apply --whitespace=error-all \
        --directory=util/third_party/openthread \
        "${OPENTHREAD_RECOVERY_PATCH}"

    source_file="${sdk}/util/third_party/openthread/src/lib/spinel/radio_spinel.cpp"
    grep -Fqx '    IgnoreError(ClearSrcMatchShortEntries());' \
        "${source_file}" \
        || fail "short source-match table clear is absent after patching"
    grep -Fqx '    IgnoreError(ClearSrcMatchExtEntries());' \
        "${source_file}" \
        || fail "extended source-match table clear is absent after patching"
    [[ "$(git -C "${sdk}" diff --name-only)" == \
        "util/third_party/openthread/src/lib/spinel/radio_spinel.cpp" ]] \
        || fail "OpenThread recovery patch changed an unexpected file"
    git -C "${sdk}" diff --check

    printf 'PASS: OpenThread recovery patch applies to Simplicity SDK %s\n' \
        "${sdk_revision}"
}

main "$@"
