#!/usr/bin/env bash
set -euo pipefail
sdk_revision=da661283f301b53eec04d1016009e60bc7e34a1f
mkdir -p /probe
# The released image copied the complete CPC installation, including headers.
# Do not silently substitute a different CPC library or rebuild Zigbee.
test -n "$(find /usr/local -name sl_cpc.h -print -quit)"
test -n "$(find /usr/local -name 'libcpc.so*' -print -quit)"
command -v cpcd
command -v zigbeed
find /usr/local -type f \( -name cpcd -o -name zigbeed -o -name 'libcpc.so*' -o -name sl_cpc.h \) \
    -exec sha256sum {} + > /probe/released-cpc-zigbee.sha256

# Sparse checkout avoids SLC, firmware payloads and Zigbee generation entirely.
git clone --depth 1 --branch v2024.12.1-0 --filter=blob:none --no-checkout https://github.com/SiliconLabs/simplicity_sdk.git /usr/src/sdk
cd /usr/src/sdk
git sparse-checkout init --cone
git sparse-checkout set util/third_party/ot-br-posix util/third_party/openthread protocol/openthread
git checkout --detach "$sdk_revision"
test "$(git rev-parse HEAD)" = "$sdk_revision"
patch -p1 < /probe-patches/0001-Avoid-writing-to-system-console.patch
patch -p1 < /probe-patches/0001-rest-support-deleting-the-dataset.patch
cp -a util/third_party/ot-br-posix /usr/src/ot-br-posix
cp -a util/third_party/openthread /usr/src/openthread
mkdir -p /usr/src/protocol
cp -a protocol/openthread /usr/src/protocol/openthread
cp protocol/openthread/platform-abstraction/posix/openthread-core-silabs-posix-config.h \
    /usr/src/openthread/src/posix/platform/
cd /usr/src/ot-br-posix
ln -s ../../../openthread third_party/openthread/repo
# Reuse pinned source bootstrap for its exact dependency selection.
RELEASE=1 REFERENCE_DEVICE=1 BACKBONE_ROUTER=1 NAT64=1 DNS64=1 ./script/bootstrap

# Match the draft production feature/vendor configuration and fixed pool.
# Empty CPCD_SOURCE_DIR selects the unchanged installed released libcpc.
cmake -S . -B build/probe -GNinja \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr \
    -DOTBR_FEATURE_FLAGS=ON \
    -DOTBR_DNSSD_DISCOVERY_PROXY=ON -DOTBR_SRP_ADVERTISING_PROXY=ON \
    -DOTBR_INFRA_IF_NAME=eth0 -DOTBR_MDNS=mDNSResponder \
    -DOTBR_VERSION= -DOT_PACKAGE_VERSION= -DOTBR_DBUS=OFF \
    -DOT_THREAD_VERSION=1.4 -DOT_MULTIPAN_RCP=ON -DCPCD_SOURCE_DIR= \
    -DOT_POSIX_RCP_VENDOR_BUS=ON \
    -DOT_POSIX_CONFIG_RCP_VENDOR_DEPS_PACKAGE=/usr/src/protocol/openthread/platform-abstraction/posix/posix_vendor_rcp.cmake \
    -DOT_POSIX_CONFIG_RCP_VENDOR_INTERFACE=/usr/src/protocol/openthread/platform-abstraction/posix/cpc_interface.cpp \
    -DOT_CLI_VENDOR_EXTENSION=/usr/src/protocol/openthread/platform-abstraction/posix/posix_vendor_cli.cmake \
    -DOT_PLATFORM_CONFIG=openthread-core-silabs-posix-config.h \
    -DOT_LINK_RAW=1 -DOTBR_VENDOR_NAME=OpenThread \
    '-DOTBR_PRODUCT_NAME=Silicon Labs Multiprotocol' \
    -DOTBR_WEB=ON -DOTBR_BORDER_ROUTING=ON -DOTBR_REST=ON \
    -DOTBR_BACKBONE_ROUTER=ON -DOTBR_DUA_ROUTING=ON \
    -DOTBR_NAT64=ON -DOTBR_DNS_UPSTREAM_QUERY=ON \
    -DOT_POSIX_NAT64_CIDR=192.168.255.0/24
cmake --build build/probe --target otbr-agent ot-ctl --parallel 2
cp build/probe/CMakeCache.txt build/probe/compile_commands.json /probe/
for binary in otbr-agent ot-ctl; do
    mapfile -t paths < <(find build/probe -type f -name "$binary")
    test "${#paths[@]}" -eq 1
    cp "${paths[0]}" "/probe/$binary"
done
grep -E '^Cpc_(LIBRARY|INCLUDE_DIR):' /probe/CMakeCache.txt
grep -q 'OTBR_ENABLE_NAT64=1' /probe/compile_commands.json
grep -q 'OTBR_ENABLE_DNS_UPSTREAM_QUERY=1' /probe/compile_commands.json
python3 /probe-verify.py | tee /probe/build-evidence.txt
nm -C /probe/otbr-agent > /probe/symbols.txt
grep 'otNat64SetEnabled' /probe/symbols.txt
grep 'otDnssdUpstreamQuerySetEnabled' /probe/symbols.txt
sha256sum -c /probe/released-cpc-zigbee.sha256

# Reuse the pinned native unit target, without a new network simulation harness.
cmake -S /usr/src/openthread -B /usr/src/unit-build -GNinja \
    -DOT_PLATFORM=simulation -DBUILD_TESTING=ON -DOT_THREAD_VERSION=1.4 \
    -DOT_BORDER_ROUTER=ON -DOT_BORDER_ROUTING=ON -DOT_NAT64_TRANSLATOR=ON -DOT_NAT64_BORDER_ROUTING=ON
cmake --build /usr/src/unit-build --target ot-test-nat64 --parallel 2
(cd /usr/src/unit-build && ctest --no-tests=error --output-on-failure -R '^ot-test-nat64$' --verbose) | tee /probe/nat64-unit.log
grep -Fq 'All tests passed' /probe/nat64-unit.log
printf 'Compiled exact vendor OTBR with NAT64/upstream DNS; native NAT64 unit test passed.\n' > /probe/result.txt
