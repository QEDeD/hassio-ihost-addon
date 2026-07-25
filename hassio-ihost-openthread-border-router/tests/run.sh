#!/bin/bash
set -euo pipefail

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "${TEST_DIR}/test-firewall.sh"
bash "${TEST_DIR}/test-nat64.sh"
bash "${TEST_DIR}/test-service-invariants.sh"
