#!/bin/bash
set -euo pipefail
sdk=/opt/silabs/sdks/simplicity_sdk_2026.6.1
work=/sdk2026-native
mkdir -p "$work"
cd "$work"
if [ ! -d cpc-daemon ]; then
 git clone --branch v4.9.1 --depth 1 https://github.com/SiliconLabs/cpc-daemon.git
fi
test "$(git -C cpc-daemon rev-parse HEAD)" = 87f6dbda4eef05e4538589c195099c3daf8f6f6b
if [ ! -d ot-br-posix ]; then
 cp -a "$sdk/openthread_stack/util/third_party/ot-br-posix" .
fi
cp "$sdk/openthread/platform-abstraction/posix/openthread-core-silabs-posix-config.h" ot-br-posix/third_party/openthread/repo/src/posix/platform/
cmake -S ot-br-posix -B build -G Ninja \
 -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr \
 -DCMAKE_CXX_FLAGS=-DOPENTHREAD_CONFIG_USE_STD_NEW=1 \
 -DOTBR_FEATURE_FLAGS=ON -DOTBR_NAT64=ON -DOTBR_DNS_UPSTREAM_QUERY=ON \
 -DOT_POSIX_NAT64_CIDR=192.168.255.0/24 \
 -DOTBR_OT_DISCOVERY_PROXY=ON -DOTBR_OT_SRP_ADV_PROXY=ON -DOTBR_DNSSD_PLAT=OFF \
 -DOTBR_DNSSD_DISCOVERY_PROXY=OFF -DOTBR_SRP_ADVERTISING_PROXY=OFF \
 -DOTBR_INFRA_IF_NAME=eth0 -DOTBR_MDNS=openthread \
 -DOTBR_DBUS=OFF -DOT_THREAD_VERSION=1.4 -DOT_MULTIPAN_RCP=ON \
 -DCPCD_SOURCE_DIR="$work/cpc-daemon" -DENABLE_ENCRYPTION=FALSE \
 -DOT_POSIX_RCP_VENDOR_BUS=ON \
 -DOT_POSIX_CONFIG_RCP_VENDOR_DEPS_PACKAGE="$sdk/openthread/platform-abstraction/posix/posix_vendor_rcp.cmake" \
 -DOT_POSIX_CONFIG_RCP_VENDOR_INTERFACE="$sdk/openthread/platform-abstraction/posix/cpc_interface.cpp" \
 -DOT_CLI_VENDOR_EXTENSION="$sdk/openthread/platform-abstraction/posix/posix_vendor_cli.cmake" \
 -DOT_PLATFORM_CONFIG=openthread-core-silabs-posix-config.h -DOT_LINK_RAW=ON \
 -DOTBR_WEB=OFF -DOTBR_BORDER_ROUTING=ON -DOTBR_REST=ON \
 -DOTBR_BACKBONE_ROUTER=ON -DOTBR_DUA_ROUTING=ON
cmake --build build -j4
