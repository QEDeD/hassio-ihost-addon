#!/usr/bin/env bash
# OFFLINE ONLY: no device, debug adapter, serial, flash or reset command.
set -euo pipefail
: "${COMMANDER:?Set path to Commander CLI 1v25p0b1995}"
: "${PACKAGE_WORK:?Set a new offline output working directory}"
: "${FIRMWARE_INPUT:?Set directory containing the verified clean ELF and S37}"
: "${PYTHON:?Set Python interpreter path}"
if [[ -e "$PACKAGE_WORK" ]]; then echo 'Refusing existing PACKAGE_WORK' >&2; exit 2; fi
mkdir -p "$PACKAGE_WORK/input" "$PACKAGE_WORK/output"
cp "$FIRMWARE_INPUT/cpc_secondary_vcom_security_device_recovery.out" "$FIRMWARE_INPUT/cpc_secondary_vcom_security_device_recovery.s37" "$PACKAGE_WORK/input/"
echo '780ad48b11ecd28c71e5443b8de704946b040388cde7d9de5eac354877986099  cpc_secondary_vcom_security_device_recovery.out' | (cd "$PACKAGE_WORK/input"; sha256sum -c -)
"$COMMANDER" --version > "$PACKAGE_WORK/output/commander-version.txt"
grep -q 'Simplicity Commander 1v25p0b1995' "$PACKAGE_WORK/output/commander-version.txt"
"$COMMANDER" gbl3 create --help > "$PACKAGE_WORK/output/create-help.txt"
"$COMMANDER" gbl3 parse --help > "$PACKAGE_WORK/output/parse-help.txt"
"$COMMANDER" gbl3 create "$PACKAGE_WORK/output/cpc-recovery-sdk2026-application-only.gbl" --app "$PACKAGE_WORK/input/cpc_secondary_vcom_security_device_recovery.out" > "$PACKAGE_WORK/output/create.log"
"$COMMANDER" gbl3 parse "$PACKAGE_WORK/output/cpc-recovery-sdk2026-application-only.gbl" --app "$PACKAGE_WORK/output/parsed-application.s37" > "$PACKAGE_WORK/output/parse.log"
"$PYTHON" "$(dirname "$0")/verify-package.py" "$PACKAGE_WORK"
