#!/usr/bin/env bash
# Offline application-only packaging; no device access.
set -euo pipefail
export EXPECTED_ELF_SHA256=75c8b8c9989fa95ef9cfdad9622fe4400c159157436f7982f520156d51eee009
export ELF_BASENAME=rcp-uart-802154
export GBL_NAME=startup-trace-sdk2026-application-only.gbl
exec bash "$(dirname "$0")/../cpc-recovery/build-package.sh"
