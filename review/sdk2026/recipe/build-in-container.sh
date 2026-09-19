#!/bin/bash
# Run only inside Dockerfile.sdk2026's pinned AMD64 builder.
set -euo pipefail
: "${CPC_ENCRYPTION:?Set CPC_ENCRYPTION explicitly to ON or OFF; security policy is not inferred}"
case "$CPC_ENCRYPTION" in ON|OFF) ;; *) echo 'CPC_ENCRYPTION must be ON or OFF' >&2; exit 2;; esac
test "$(uname -m)" = x86_64
sdk=/opt/silabs/sdks/simplicity_sdk_2026.6.1
work=/sdk2026-host
out=/sdk2026-install
staged=/sdk2026-upstream-install
jobs=${BUILD_JOBS:-4}
cpc_commit=87f6dbda4eef05e4538589c195099c3daf8f6f6b
mkdir -p "$work" "$out" "$staged"
cd "$work"
git clone --depth 1 --branch v4.9.1 https://github.com/SiliconLabs/cpc-daemon.git cpc-daemon
test "$(git -C cpc-daemon rev-parse HEAD)" = "$cpc_commit"
cmake -S cpc-daemon -B cpc-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_LIBDIR=lib \
  -DENABLE_ENCRYPTION="$CPC_ENCRYPTION"
cmake --build cpc-build -j "$jobs"
cmake --install cpc-build
DESTDIR="$staged/cpc" cmake --install cpc-build
# Copy only runtime artifacts. Upstream config, headers and service files stay
# in the temporary install tree; the add-on rootfs owns startup and config.
install -Dm755 "$staged/cpc/usr/local/bin/cpcd" "$out/usr/local/bin/cpcd"
mkdir -p "$out/usr/local/lib"
cp -a "$staged/cpc/usr/local/lib/"libcpc.so* "$out/usr/local/lib/"
ldconfig

# SLC 6 supports Makefile export for this project; preserve its C18/C++17 flags.
# Explicitly register bundled Python for the JEP template engine. A retained
# SLC configuration can hide this dependency; PATH alone does not register it.
slc signature trust --sdk="$sdk"
slc generate --no-daemon --sdk="$sdk" --tool-path=/opt/silabs/python --with=linux_arch_64,zigbee_x86_64 \
  --project-file="$sdk/zigbee_app/zigbeed/zigbeed.slcp" \
  --destination="$work/zigbeed" --copy-proj-sources --output-type=makefile
make -C zigbeed -f zigbeed.Makefile -j "$jobs" release
install -Dm755 zigbeed/build/release/zigbeed "$out/usr/local/bin/zigbeed"

# Use SDK-paired OTBR and its embedded OpenThread source, not a separate upstream checkout.
cp -a "$sdk/openthread_stack/util/third_party/ot-br-posix" ot-br-posix
cp "$sdk/openthread/platform-abstraction/posix/openthread-core-silabs-posix-config.h" \
  ot-br-posix/third_party/openthread/repo/src/posix/platform/
# These two frontend patches apply to SDK2026.6.1 without fuzz. The -p4
# removes the legacy SDK prefix; relative paths within OTBR are unchanged.
for patch_name in \
  0001-web-generate-commissioning-qr-locally.patch \
  0002-web-lock-frontend-dependencies.patch; do
  patch --batch --fuzz=0 -d ot-br-posix -p4 < "/recipe/patches/$patch_name"
done
# SDK2026 includes RDNSS. Use upstream's separate host/infra sockets instead
# of the legacy SDK global binding override (OpenThread PR13545).
patch --batch --fuzz=0 -d ot-br-posix/third_party/openthread/repo -p1 < /recipe/dns-routing-sdk2026.patch
patch --batch --fuzz=0 -d ot-br-posix -p1 < /recipe/no-console-sdk2026.patch
cmake -S ot-br-posix -B otbr-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_CXX_FLAGS=-DOPENTHREAD_CONFIG_USE_STD_NEW=1 \
  -DOTBR_FEATURE_FLAGS=ON -DOTBR_NAT64=ON -DOTBR_DNS_UPSTREAM_QUERY=ON \
  -DOT_POSIX_NAT64_CIDR=192.168.255.0/24 \
  -DOTBR_OT_DISCOVERY_PROXY=ON -DOTBR_OT_SRP_ADV_PROXY=ON -DOTBR_DNSSD_PLAT=OFF \
  -DOTBR_DNSSD_DISCOVERY_PROXY=OFF -DOTBR_SRP_ADVERTISING_PROXY=OFF \
  -DOTBR_INFRA_IF_NAME=eth0 -DOTBR_MDNS=openthread \
  -DOTBR_DBUS=OFF -DOT_THREAD_VERSION=1.4 -DOT_MULTIPAN_RCP=ON \
  -DCPCD_SOURCE_DIR="$work/cpc-daemon" -DENABLE_ENCRYPTION="$CPC_ENCRYPTION" \
  -DOT_POSIX_RCP_VENDOR_BUS=ON \
  -DOT_POSIX_CONFIG_RCP_VENDOR_DEPS_PACKAGE="$sdk/openthread/platform-abstraction/posix/posix_vendor_rcp.cmake" \
  -DOT_POSIX_CONFIG_RCP_VENDOR_INTERFACE="$sdk/openthread/platform-abstraction/posix/cpc_interface.cpp" \
  -DOT_CLI_VENDOR_EXTENSION="$sdk/openthread/platform-abstraction/posix/posix_vendor_cli.cmake" \
  -DOT_PLATFORM_CONFIG=openthread-core-silabs-posix-config.h -DOT_LINK_RAW=ON \
  -DOTBR_VENDOR_NAME=OpenThread -DOTBR_PRODUCT_NAME="Silicon Labs Multiprotocol" \
  -DOTBR_WEB=ON -DOTBR_BORDER_ROUTING=ON -DOTBR_REST=ON \
  -DOTBR_BACKBONE_ROUTER=ON -DOTBR_DUA_ROUTING=ON
cmake --build otbr-build -j "$jobs"
DESTDIR="$staged/otbr" cmake --install otbr-build
for binary in otbr-agent otbr-web ot-ctl; do
  install -Dm755 "$staged/otbr/usr/sbin/$binary" "$out/usr/sbin/$binary"
done
mkdir -p "$out/usr/share/otbr-web"
cp -a "$staged/otbr/usr/share/otbr-web/frontend" "$out/usr/share/otbr-web/"
# Assert that locked frontend installation includes its local QR implementation.
test -s "$out/usr/share/otbr-web/frontend/index.html"
test -s "$out/usr/share/otbr-web/frontend/res/js/qrcode.js"
mkdir -p "$out/usr/share/sdk2026-build" "$out/etc/iproute2/rt_tables.d"
printf '88 openthread\n' > "$out/etc/iproute2/rt_tables.d/openthread.conf"
printf 'sdk=2026.6.1\ncpc_commit=%s\ncpc_encryption=%s\nmdns=openthread\n' \
  "$cpc_commit" "$CPC_ENCRYPTION" > "$out/usr/share/sdk2026-build/versions.txt"
cp otbr-build/CMakeCache.txt "$out/usr/share/sdk2026-build/otbr-CMakeCache.txt"
cp cpc-build/CMakeCache.txt "$out/usr/share/sdk2026-build/cpc-CMakeCache.txt"
