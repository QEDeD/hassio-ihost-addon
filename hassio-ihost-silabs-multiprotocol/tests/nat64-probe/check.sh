#!/usr/bin/env bash
set -euo pipefail
sha256sum -c /probe/released-cpc-zigbee.sha256
for binary in /probe/otbr-agent /probe/ot-ctl; do
    dependencies="$(ldd "$binary")"
    printf '%s\n' "$dependencies"
    if grep -q 'not found' <<< "$dependencies"; then exit 1; fi
done
/probe/otbr-agent --version
cat /probe/build-evidence.txt /probe/result.txt
printf 'Released-runtime loader check passed; no radio or network service was started.\n'
