#!/bin/bash
set -euo pipefail
src=/sdk2026-native/ot-br-posix/third_party/openthread/repo
build=/sdk2026-native/discovery-tests
cmake -S "$src" -B "$build" -G Ninja -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DOT_PLATFORM=simulation -DOT_FTD=ON -DOT_MTD=OFF -DOT_RCP=ON -DOT_MDNS=ON -DOT_PLATFORM_DNSSD=ON -DOT_ECDSA=ON -DOT_SERVICE=ON -DOT_BORDER_ROUTER=ON -DOT_BORDER_ROUTING=ON -DOT_SRP_SERVER=ON -DOT_SRP_CLIENT=ON -DOT_DNS_CLIENT=ON -DOT_DNSSD_SERVER=ON -DOT_DNSSD_DISCOVERY_PROXY=ON -DOT_SRP_ADV_PROXY=ON -DCMAKE_CXX_FLAGS="-DOPENTHREAD_CONFIG_PLATFORM_DNSSD_ALLOW_RUN_TIME_SELECTION=1 -DOPENTHREAD_CONFIG_DNS_CLIENT_SERVICE_DISCOVERY_ENABLE=1 -DOPENTHREAD_CONFIG_DNS_CLIENT_DEFAULT_SERVER_ADDRESS_AUTO_SET_ENABLE=1"
cmake --build "$build" --target ot-test-mdns ot-test-dnssd_discovery_proxy ot-test-srp_adv_proxy -j4
for test in mdns dnssd_discovery_proxy srp_adv_proxy; do
 "$build/tests/unit/ot-test-$test" >"$build/$test.log" 2>&1
 if grep -qiE 'not enabled|test is disabled|tests? skipped' "$build/$test.log"; then cat "$build/$test.log"; exit 1; fi
 grep 'All tests passed' "$build/$test.log"
done
