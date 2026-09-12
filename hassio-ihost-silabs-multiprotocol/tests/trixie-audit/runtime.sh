#!/bin/bash
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true && ${RUNNER_ENVIRONMENT:-} == github-hosted ]]
audit_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Only disposable fixture copies change. Production source and image are untouched.
# shellcheck source=inputs.sh
source "$audit_dir/inputs.sh"
fixture="$(mktemp -d "$RUNNER_TEMP/trixie-runtime.XXXXXX")"
cp -a audit-fixtures-nat64/hassio-ihost-silabs-multiprotocol "$fixture/nat64"
cp -a audit-fixtures-readiness/hassio-ihost-silabs-multiprotocol "$fixture/readiness"
export fixture
python3 - <<'PY'
import os
from pathlib import Path
root = Path(os.environ['fixture'])
for path in [root/'nat64/tests/s6/Dockerfile', root/'nat64/tests/s6-nat64/Dockerfile', root/'readiness/tests/readiness/Dockerfile']:
    text = path.read_text()
    lines = text.splitlines()
    assert lines[0].startswith('FROM ghcr.io/ihost-open-source-project/')
    lines[0] = 'FROM local/ihost-trixie-audit'
    text = '\n'.join(lines)+'\n'
    assert '/package/admin/s6-overlay-3.1.6.2/' in text
    path.write_text(text.replace('/package/admin/s6-overlay-3.1.6.2/', '/package/admin/s6-overlay-3.2.3.0/'))
PY
cat > "$fixture/nat64/Dockerfile.audit" <<'DOCKER'
FROM local/ihost-trixie-audit
HEALTHCHECK NONE
COPY . /addon
COPY --chmod=0755 tests/kernel/ip6tables-lock-probe /usr/local/libexec/otbr-lock-probe/ip6tables
WORKDIR /addon
ENTRYPOINT ["/bin/bash"]
DOCKER
docker build -f "$fixture/nat64/Dockerfile.audit" -t local/trixie-regressions "$fixture/nat64"
docker run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges     --pids-limit 128 --tmpfs /tmp:rw,nosuid,nodev,size=32m     local/trixie-regressions -c 'set -e; python3 --version; python3 tests/test-otbr-nat64-pool.py; bash tests/test-otbr-firewall.sh; bash tests/test-otbr-nat64.sh'
# Real kernel rules inside an isolated network namespace; no host network/devices.
docker run --rm --network none --read-only --cap-drop ALL --cap-add NET_ADMIN --cap-add NET_RAW     --security-opt no-new-privileges --pids-limit 128     --tmpfs /run:rw,nosuid,nodev,noexec,size=1m --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m     --entrypoint /bin/bash local/trixie-regressions -c     'bash tests/test-otbr-firewall-kernel.sh'
for spec in 'nat64 test-otbr-s6.sh' 'nat64 test-otbr-nat64-s6.sh' 'readiness test-zigbeed-readiness.sh'; do
    read -r tree test_name <<< "$spec"
    timeout 300s bash "$fixture/$tree/tests/$test_name"
done
# Actual utilities and loopback sockets, without a radio or outside connectivity.
for image in local/ihost-trixie-audit "$RELEASE_IMAGE"; do
    query=0
    [[ "$image" != local/ihost-trixie-audit ]] || query=1
    printf 'UTILITY_COMPARISON_IMAGE=%s\n' "$image"
    timeout 60s docker run --rm -i --network none --read-only --cap-drop ALL --cap-add NET_ADMIN --security-opt no-new-privileges \
        --pids-limit 128 --tmpfs /tmp:rw,nosuid,nodev,size=4m --env "AUDIT_CONFIG_QUERY=$query" \
        --entrypoint /bin/bash "$image" < "$audit_dir/utility-probe.sh"
done
# Actual installed Bashio and native web binary, tested against both endpoints.
# Read-only test inputs; no Supervisor, OT control socket, radio or outside route.
for image in local/ihost-trixie-audit "$RELEASE_IMAGE"; do
    printf 'APPLICATION_COMPARISON_IMAGE=%s\n' "$image"
    timeout 90s docker run --rm -i --network none --read-only --cap-drop ALL \
        --security-opt no-new-privileges --pids-limit 128 \
        --tmpfs /tmp:rw,nosuid,nodev,size=16m \
        --entrypoint /bin/bash "$image" < "$audit_dir/bashio-check.sh"
    timeout 45s docker run --rm -i --network none --read-only --cap-drop ALL \
        --security-opt no-new-privileges --pids-limit 128 \
        --tmpfs /tmp:rw,nosuid,nodev,size=16m \
        --entrypoint python3 "$image" < "$audit_dir/web-probe.py"
done

echo 'PASS: isolated Trixie runtime regressions; physical radio and ARM acceptance remain separate'
