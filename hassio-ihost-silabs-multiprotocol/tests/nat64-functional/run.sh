#!/usr/bin/env bash
# Only for a disposable GitHub-hosted runner: upstream uses privileged virtual radios.
set -euo pipefail
if [[ ${GITHUB_ACTIONS:-} != true || ${RUNNER_ENVIRONMENT:-} != github-hosted ]]; then
    echo 'Run this fixture only on its disposable GitHub-hosted CI job.' >&2
    exit 1
fi
fixture_scripts="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
sdk_revision=da661283f301b53eec04d1016009e60bc7e34a1f
# dumpcap drops DAC-override capabilities. Use a traversable scratch hierarchy,
# without changing permissions on GitHub's runner-owned home/work directories.
fixture_dir="$(mktemp -d /tmp/otbr-functional.XXXXXX)"
chmod 755 "$fixture_dir"
sdk="$fixture_dir/sdk"
venv="$fixture_dir/venv"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build git socat python3-dev python3-venv \
    python3-pip python3-setuptools python3-wheel tshark
python3 -m venv "$venv"
export PATH="$venv/bin:$PATH"

git clone --depth 1 --branch v2024.12.1-0 --filter=blob:none --no-checkout \
    https://github.com/SiliconLabs/simplicity_sdk.git "$sdk"
git -C "$sdk" sparse-checkout init --cone
git -C "$sdk" sparse-checkout set util/third_party/ot-br-posix util/third_party/openthread protocol/openthread
git -C "$sdk" checkout --detach "$sdk_revision"
test "$(git -C "$sdk" rev-parse HEAD)" = "$sdk_revision"
ot="$sdk/util/third_party/openthread"
python3 -m pip install -r "$ot/tests/scripts/thread-cert/requirements.txt"
python3 "$fixture_scripts/prepare-cross-interface.py" \
    "$ot/tests/scripts/thread-cert/border_router/internet/test_upstream_dns.py"

# Pinned node.py passes a list directly to Popen, but packs three sysctls into
# one value. Fix only that argv construction in the disposable test checkout.
python3 - "$ot/tests/scripts/thread-cert/node.py" <<'PATCH_NODE'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "'net.ipv6.conf.all.disable_ipv6=0 net.ipv4.conf.all.forwarding=1 net.ipv6.conf.all.forwarding=1'"
new = "'net.ipv6.conf.all.disable_ipv6=0', '--sysctl', 'net.ipv4.conf.all.forwarding=1', '--sysctl', 'net.ipv6.conf.all.forwarding=1'"
assert s.count(old) == 1, 'Pinned runner sysctl argv changed; review adaptation'
p.write_text(s.replace(old, new))
PATCH_NODE

# Packet decoding assertions are disabled for these functional cases, but the
# runner still captures traffic using a fixed directory. Reuse installed tools.
sudo mkdir -p /tmp/thread-wireshark
for tool in dumpcap tshark mergecap; do
    sudo ln -s "$(command -v "$tool")" "/tmp/thread-wireshark/$tool"
done

# Fail cheaply before compilation if the exact capture working directory is not
# usable. Capture only an isolated dummy interface, never runner/Internet traffic.
namei -l "$ot"
sudo chown root "$ot"
sudo ip link add otbr-preflight type dummy
trap 'sudo ip link delete otbr-preflight 2>/dev/null || true' EXIT
sudo ip link set otbr-preflight up
sudo timeout 10 dumpcap -i otbr-preflight -a duration:1 -w "$ot/preflight.pcap"
sudo test -s "$ot/preflight.pcap"
sudo rm "$ot/preflight.pcap"
sudo ip link delete otbr-preflight
trap - EXIT
sudo chown "$(id -u):$(id -g)" "$ot"
printf 'PASS: capture access in exact functional-test directory before build\n'

export THREAD_VERSION=1.4 VIRTUAL_TIME=0 PACKET_VERIFICATION=0
export REFERENCE_DEVICE=1 BORDER_ROUTING=1 NAT64=1
export MAX_JOBS=2 CI_ENV='' COVERAGE=0 OTBR_COVERAGE=0
export PORT_OFFSET=47 OTBR_DOCKER_IMAGE=otbr-nat64-functional

build_otbr_simulation() {
    local binding="$1"
    local options='-DOTBR_FEATURE_FLAGS=ON -DOTBR_NAT64=ON -DOTBR_DNS_UPSTREAM_QUERY=ON -DOTBR_TREL=OFF'
    if [[ "$binding" == 0 ]]; then
        options+=' -DCMAKE_CXX_FLAGS=-DOPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF=0'
    fi
    export OTBR_DOCKER_IMAGE="otbr-nat64-functional-dns-$binding"
# BASE_IMAGE is an existing upstream argument. Jammy is a simulation-only base;
# this does not upgrade the iHost image or alter the pinned OTBR/OpenThread source.
# SDK root is required by Silicon Labs' modified COPY paths.
docker build --progress=plain -t "${OTBR_DOCKER_IMAGE}-compiled" \
    -f "$sdk/util/third_party/ot-br-posix/etc/docker/Dockerfile" \
    --build-arg BASE_IMAGE=ubuntu:22.04 \
    --build-arg INFRA_IF_NAME=eth0 --build-arg BORDER_ROUTING=1 \
    --build-arg BACKBONE_ROUTER=1 --build-arg OT_BACKBONE_CI=1 \
    --build-arg REFERENCE_DEVICE=1 --build-arg NAT64=1 \
    --build-arg NAT64_SERVICE=openthread --build-arg DNS64=1 \
    --build-arg MDNS=mDNSResponder --build-arg WEB_GUI=0 --build-arg REST_API=0 \
    --build-arg "OTBR_OPTIONS=$options" \
    "$sdk"

# Jammy packages the SysV service as named; pinned tests still call bind9.
# Supply only a test-image alias so the upstream test source stays unchanged.
docker build --progress=plain -t "$OTBR_DOCKER_IMAGE" - <<DOCKERFILE
FROM ${OTBR_DOCKER_IMAGE}-compiled
RUN test -x /etc/init.d/named && test ! -e /etc/init.d/bind9 && ln -s named /etc/init.d/bind9
DOCKERFILE

docker run --rm --network none --entrypoint bash "$OTBR_DOCKER_IMAGE" -ec '
    for option in OTBR_FEATURE_FLAGS OTBR_NAT64 OTBR_DNS_UPSTREAM_QUERY; do
        grep -E "^${option}:(BOOL|STRING)=ON$" /app/build/otbr/CMakeCache.txt
    done
'
# Inspect the effective resolver macro using its real compiler command. A cache
# variable with a similar name would not prove that the compiler consumed it.
docker run --rm -i --network none --entrypoint python3 "$OTBR_DOCKER_IMAGE" - "$binding" <<'CHECK_MACRO'
import json, shlex, subprocess, sys
from pathlib import Path
entries = json.loads(Path('/app/build/otbr/compile_commands.json').read_text())
entries = [e for e in entries if e['file'].endswith('/posix/platform/resolver.cpp')]
assert len(entries) == 1, 'Expected one upstream resolver compilation'
e = entries[0]
args = shlex.split(e['command'])
filtered = []
skip = False
for arg in args:
    if skip:
        skip = False
    elif arg == '-o':
        skip = True
    elif arg != '-c':
        filtered.append(arg)
output = subprocess.check_output(filtered + ['-E', '-dM'], cwd=e['directory'], text=True)
expected = '#define OPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF ' + sys.argv[1]
assert expected in output.splitlines(), 'Effective DNS binding macro mismatch'
print('PASS: resolver compiler confirms ' + expected)
CHECK_MACRO
}
build_otbr_simulation 1
cd "$ot"
./script/test build

# dumpcap drops DAC-override privileges, so root-run capture needs a root-owned
# writable working directory. Keep the runner-owned log directory for tee.
mkdir "$fixture_dir/logs"
chmod 755 "$fixture_dir"
sudo chown root "$ot"

# Keep the upstream tests and their protocol observation waits unchanged.
# FEATURE_FLAGS defaults are handled by their explicit NAT64/DNS activation.
failed_cases=0
run_case() {
    local case_name="$1" expected_failure="$2" case_failed test_path log

    test_path="tests/scripts/thread-cert/border_router/internet/$case_name.py"
    log="$fixture_dir/logs/$OTBR_DOCKER_IMAGE-$case_name.log"
    sha256sum "$test_path"
    case_failed=false
    if ! sudo env PATH="$PATH" \
        THREAD_VERSION="$THREAD_VERSION" VIRTUAL_TIME="$VIRTUAL_TIME" \
        PACKET_VERIFICATION="$PACKET_VERIFICATION" REFERENCE_DEVICE=1 \
        BORDER_ROUTING=1 NAT64=1 MAX_JOBS=2 PORT_OFFSET="$PORT_OFFSET" \
        CI_ENV='' COVERAGE=0 OTBR_COVERAGE=0 \
        OTBR_DOCKER_IMAGE="$OTBR_DOCKER_IMAGE" OTBR_DNS_EXPECT_FAILURE="$expected_failure" \
        ./script/test cert python3 -u "$test_path" -v 2>&1 | tee "$log"; then
        case_failed=true
    fi
    # A skipped or undiscovered test must not be counted as functional evidence.
    if ! grep -Eq '^Ran 1 test in ' "$log" || ! grep -qx 'OK' "$log" \
        || grep -Eiq '(^|[[:space:]])skipped([[:space:]]|=)' "$log"; then
        case_failed=true
    fi
    if [[ "$case_failed" == true ]]; then
        failed_cases=$((failed_cases + 1))
        printf 'FAIL: %s; continuing independent case\n' "$case_name"
    else
        printf 'PASS: executed %s\n' "$case_name"
    fi
}
run_case test_upstream_dns 0
run_case test_upstream_dns_cross_interface 1
run_case test_single_border_router 0
# Docker reuses unchanged layers; only the resolver binding build flag changes.
build_otbr_simulation 0
run_case test_upstream_dns 0
run_case test_upstream_dns_cross_interface 0
(( failed_cases == 0 )) || exit 1
printf 'PASS: NAT64 baseline and all four DNS interface comparison cells\n'
