#!/usr/bin/env bash
# Offline only. Explicitly pin this diagnostic ELF; reuse all existing package checks.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export EXPECTED_ELF_SHA256=fa14fd55f8e16ef6729572eb4d1dbc63c0b17762b6da640bf34352cbb4f3f913
export GBL_NAME=cpc-hfxo-sdk2026-application-only.gbl
exec bash "$here/../cpc-recovery/build-package.sh"
