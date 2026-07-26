#!/bin/bash
set -euo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR

bash "${TEST_DIR}/test-firewall.sh"
bash "${TEST_DIR}/test-nat64.sh"
bash "${TEST_DIR}/test-service-invariants.sh"
bash "${TEST_DIR}/test-service-callers.sh"
