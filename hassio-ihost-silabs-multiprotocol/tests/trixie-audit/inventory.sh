#!/bin/bash
# Read-only image inspection. stdin supplies this script; no host mount or /init.
set -euo pipefail
printf 'OS_IDENTITY\n'
cat /etc/os-release
printf 'DPKG_INVENTORY_BEGIN\n'
dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\t${db:Status-Abbrev}\n' | LC_ALL=C sort
printf 'DPKG_INVENTORY_END\n'
printf 'S6_AND_BASHIO\n'
if [[ -d /package/admin ]]; then find /package/admin -mindepth 1 -maxdepth 1 -print | sort; fi
for directory in /usr/lib/bashio /usr/bin/bashio; do
    if [[ -e "$directory" ]]; then grep -RI -m 1 'BASHIO_VERSION' "$directory" || true; fi
done
version() {
    if command -v "$1" >/dev/null 2>&1; then
        printf 'COMMAND_VERSION %s\n' "$*"
        timeout 10s "$@" 2>&1 || printf 'VERSION_QUERY_NONZERO %s\n' "$1"
    fi
}
version bash --version
version python3 --version
version node --version
version npm --version
version gcc --version
version g++ --version
version cmake --version
version java -version
version openssl version
version curl --version
version ip -V
version ss -V
version iptables --version
version ip6tables --version
version ipset --version
version named -v
version avahi-daemon --version
printf 'TOOL_HASHES_BEGIN\n'
for name in bash python3 node npm gcc g++ cmake java curl ip ss iptables ip6tables ipset socat nc jq; do
    if binary="$(command -v "$name")"; then sha256sum "$binary"; fi
done
printf 'TOOL_HASHES_END\n'
missing=0
for name in otbr-agent ot-ctl otbr-web cpcd zigbeed; do
    if binary="$(command -v "$name")"; then
        printf 'APP_LINKAGE %s\n' "$binary"
        sha256sum "$binary"
        if command -v readelf >/dev/null; then readelf -d "$binary" | grep 'NEEDED' || true; fi
        dependencies="$(ldd "$binary" 2>&1)" || missing=1
        printf '%s\n' "$dependencies"
        if grep -q 'not found' <<< "$dependencies"; then missing=1; fi
    elif [[ ${AUDIT_REQUIRE_APPLICATIONS:-0} == 1 ]]; then
        printf 'MISSING_EXPECTED_APP %s\n' "$name"
        missing=1
    fi
done
exit "$missing"
