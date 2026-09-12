#!/usr/bin/env bash
# Only for a disposable GitHub-hosted runner: upstream uses privileged virtual radios.
set -euo pipefail
if [[ ${GITHUB_ACTIONS:-} != true || ${RUNNER_ENVIRONMENT:-} != github-hosted ]]; then
    echo 'Run this fixture only on its disposable GitHub-hosted CI job.' >&2
    exit 1
fi
sdk_revision=da661283f301b53eec04d1016009e60bc7e34a1f
fixture_dir="$(mktemp -d "${RUNNER_TEMP:?}/otbr-functional.XXXXXX")"
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

export THREAD_VERSION=1.4 VIRTUAL_TIME=0 PACKET_VERIFICATION=0
export REFERENCE_DEVICE=1 BORDER_ROUTING=1 NAT64=1
export MAX_JOBS=2 CI_ENV='' COVERAGE=0 OTBR_COVERAGE=0
export PORT_OFFSET=47 OTBR_DOCKER_IMAGE=otbr-nat64-functional

# BASE_IMAGE is an existing upstream argument. Jammy is a simulation-only base;
# this does not upgrade the iHost image or alter the pinned OTBR/OpenThread source.
# SDK root is required by Silicon Labs' modified COPY paths.
docker build --progress=plain -t "$OTBR_DOCKER_IMAGE" \
    -f "$sdk/util/third_party/ot-br-posix/etc/docker/Dockerfile" \
    --build-arg BASE_IMAGE=ubuntu:22.04 \
    --build-arg INFRA_IF_NAME=eth0 --build-arg BORDER_ROUTING=1 \
    --build-arg BACKBONE_ROUTER=1 --build-arg OT_BACKBONE_CI=1 \
    --build-arg REFERENCE_DEVICE=1 --build-arg NAT64=1 \
    --build-arg NAT64_SERVICE=openthread --build-arg DNS64=1 \
    --build-arg MDNS=mDNSResponder --build-arg WEB_GUI=0 --build-arg REST_API=0 \
    --build-arg 'OTBR_OPTIONS=-DOTBR_FEATURE_FLAGS=ON -DOTBR_NAT64=ON -DOTBR_DNS_UPSTREAM_QUERY=ON -DOTBR_TREL=OFF' \
    "$sdk"

docker run --rm --network none --entrypoint bash "$OTBR_DOCKER_IMAGE" -ec '
    for option in OTBR_FEATURE_FLAGS OTBR_NAT64 OTBR_DNS_UPSTREAM_QUERY; do
        grep -E "^${option}:(BOOL|STRING)=ON$" /app/build/otbr/CMakeCache.txt
    done
'
cd "$ot"
./script/test build

# dumpcap drops DAC-override privileges, so root-run capture needs a root-owned
# writable working directory. Keep the runner-owned log directory for tee.
mkdir "$fixture_dir/logs"
chmod 755 "$fixture_dir"
sudo chown root "$ot"

# Keep the upstream tests and their protocol observation waits unchanged.
# FEATURE_FLAGS defaults are handled by their explicit NAT64/DNS activation.
for case_name in test_upstream_dns test_single_border_router; do
    test_path="tests/scripts/thread-cert/border_router/internet/$case_name.py"
    log="$fixture_dir/logs/$case_name.log"
    sha256sum "$test_path"
    sudo env PATH="$PATH" \
        THREAD_VERSION="$THREAD_VERSION" VIRTUAL_TIME="$VIRTUAL_TIME" \
        PACKET_VERIFICATION="$PACKET_VERIFICATION" REFERENCE_DEVICE=1 \
        BORDER_ROUTING=1 NAT64=1 MAX_JOBS=2 PORT_OFFSET="$PORT_OFFSET" \
        CI_ENV='' COVERAGE=0 OTBR_COVERAGE=0 \
        OTBR_DOCKER_IMAGE="$OTBR_DOCKER_IMAGE" \
        ./script/test cert python3 -u "$test_path" -v 2>&1 | tee "$log"
    # A skipped or undiscovered test must not be counted as functional evidence.
    grep -Eq '^Ran 1 test in ' "$log"
    grep -qx 'OK' "$log"
    if grep -Eiq '(^|[[:space:]])skipped([[:space:]]|=)' "$log"; then exit 1; fi
    printf 'PASS: executed unmodified pinned %s\n' "$case_name"
done
printf 'Both pinned functional baselines passed; cross-interface DNS remains untested.\n'
