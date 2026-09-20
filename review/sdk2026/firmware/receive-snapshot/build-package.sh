#!/usr/bin/env bash
# Offline-only wrapper. Parent must supply the independently reviewed build hash.
set -euo pipefail
: "${EXPECTED_ELF_SHA256:?Set the exact independently verified diagnostic ELF hash}"
export EXPECTED_ELF_SHA256
export ELF_BASENAME=rcp-uart-802154
export GBL_NAME=receive-snapshot-sdk2026-application-only.gbl
exec bash "$(dirname "$0")/../cpc-recovery/build-package.sh"
