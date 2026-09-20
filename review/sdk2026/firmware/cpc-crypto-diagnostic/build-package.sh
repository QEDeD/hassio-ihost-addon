#!/usr/bin/env bash
# Offline only. Explicitly pin this diagnostic ELF; reuse all existing package checks.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export EXPECTED_ELF_SHA256=ffdea6681bc996038cd2cdd4f6bdffcb7d294a748dc7b24b17eaff114b6c99a8
export GBL_NAME=cpc-crypto-sdk2026-application-only.gbl
exec bash "$here/../cpc-recovery/build-package.sh"
