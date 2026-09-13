#!/bin/bash
# Inspect actual cross-build outputs; never execute ARM code or attach a radio.
set -euo pipefail
prefix="/usr/${DEBIAN_CROSS_PREFIX}"
compiler="${DEBIAN_CROSS_PREFIX}-gcc"
readelf="${DEBIAN_CROSS_PREFIX}-readelf"
nm="${DEBIAN_CROSS_PREFIX}-nm"
case "$DEBIAN_ARCH" in
    armhf) machine='ARM';;
    arm64) machine='AArch64';;
    *) echo 'Unexpected architecture'; exit 1;;
esac
printf 'CROSS_COMPILER %s\n' "$DEBIAN_ARCH"
"$compiler" --version
"$compiler" -dumpmachine
"$compiler" -print-sysroot
printf 'CROSS_PACKAGES\n'
dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n' | grep -E 'gcc|g\+\+|libc6|linux-libc|binutils|mbedtls'
zigbee=/usr/src/gecko_sdk/protocol/zigbee/app/projects/zigbeed/output
for binary in "$prefix/bin/cpcd" "$prefix/lib/libcpc.so" "$zigbee/build/debug/zigbeed"; do
    [[ -f "$binary" ]]
    printf 'ARM_ELF %s\n' "$binary"
    sha256sum "$binary"
    "$readelf" -h "$binary"
    "$readelf" -h "$binary" | grep -Eq "Machine: +${machine}$"
    "$readelf" -A "$binary"
    "$readelf" -l "$binary" | grep -E 'interpreter|INTERP' || true
    "$readelf" -V "$binary"
    if [[ "$DEBIAN_ARCH" == armhf ]]; then
        "$readelf" -h "$binary" | grep -q 'ELF32'
        "$readelf" -h "$binary" | grep -q 'hard-float ABI'
    else
        "$readelf" -h "$binary" | grep -q 'ELF64'
    fi
    "$readelf" -d "$binary" | grep NEEDED || true
    printf 'TIME_SYMBOL_REFERENCES %s\n' "$binary"
    "$nm" -D -u "$binary" | grep -Ei 'time|stat|select|poll' || true
done
printf 'CPC_EFFECTIVE_BUILD_SETTINGS\n'
find /audit/cpc-build -name flags.make -exec cat {} \;
grep -E 'CMAKE_(C|CXX)_COMPILER|CMAKE_(C|CXX)_FLAGS|CMAKE_SYSTEM_PROCESSOR' /audit/cpc-build/CMakeCache.txt || true
find /audit/cpc-build -name CMakeSystem.cmake -exec cat {} \;
printf 'ZIGBEE_GENERATED_BUILD_SETTINGS\n'
grep -nE 'C_FLAGS|CFLAGS|CPPFLAGS|TIME_BITS|FILE_OFFSET_BITS|march|mfloat|\.a([[:space:]]|$)' "$zigbee/zigbeed.Makefile" || true
cat "$zigbee/zigbeed.Makefile"
# Target object symbol sizes reveal ABI without executing target binaries.
cat > /tmp/abi.c <<'C'
#include <stddef.h>
#include <sys/types.h>
#include <sys/time.h>
#include <time.h>
unsigned char audit_time_t[sizeof(time_t)];
unsigned char audit_off_t[sizeof(off_t)];
unsigned char audit_timespec[sizeof(struct timespec)];
unsigned char audit_timeval[sizeof(struct timeval)];
unsigned char audit_timespec_align[_Alignof(struct timespec)];
unsigned char audit_timeval_align[_Alignof(struct timeval)];
unsigned char audit_tv_nsec_offset[offsetof(struct timespec, tv_nsec)];
unsigned char audit_tv_usec_offset[offsetof(struct timeval, tv_usec)];
C
for mode in default explicit64; do
    flags=()
    [[ "$mode" != explicit64 ]] || flags=(-D_TIME_BITS=64 -D_FILE_OFFSET_BITS=64)
    "$compiler" -std=gnu99 "${flags[@]}" -c /tmp/abi.c -o "/tmp/abi-$mode.o"
    printf 'ABI_LAYOUT mode=%s architecture=%s (decimal symbol sizes)\n' "$mode" "$DEBIAN_ARCH"
    "$nm" -S --radix=d "/tmp/abi-$mode.o" | grep audit_
    printf 'ABI_MACROS mode=%s\n' "$mode"
    "$compiler" -std=gnu99 "${flags[@]}" -dM -E /tmp/abi.c | grep -E '_TIME_BITS|_FILE_OFFSET_BITS|__TIMESIZE|__USE_TIME_BITS64|__WORDSIZE'
done
printf 'ACTUAL_ZIGBEE_BUILD_COMMANDS\n'
cd "$zigbee"
# GNU make $(file ...) runs during recipe expansion, even with -n.
# Override only its output directory; compilation/link inputs remain unchanged.
mkdir -p /tmp/zigbee-link-audit
make -n -B -f zigbeed.Makefile AR="${DEBIAN_CROSS_PREFIX}-ar" \
    CC="$compiler" LD="$compiler" CXX="${DEBIAN_CROSS_PREFIX}-g++" \
    C_FLAGS='-std=gnu99 -DEMBER_MULTICAST_TABLE_SIZE=16' OUTPUT_DIR=/tmp/zigbee-link-audit debug > /tmp/zigbee-build-commands.txt
cat /tmp/zigbee-build-commands.txt
python3 - <<'PY'
from pathlib import Path
import shlex
archives = set()
for line in Path('/tmp/zigbee-build-commands.txt').read_text().splitlines():
    for token in shlex.split(line):
        if token.endswith('.a'):
            archives.add(str(Path(token).resolve(strict=True)))
assert archives, 'No linked archives resolved; inspect actual linker inputs'
Path('/tmp/linked-archives').write_text('\n'.join(sorted(archives))+'\n')
PY
printf 'ACTUALLY_LINKED_VENDOR_ARCHIVES\n'
while IFS= read -r archive; do
    printf 'ARCHIVE %s\n' "$archive"
    sha256sum "$archive"
    "${DEBIAN_CROSS_PREFIX}-ar" t "$archive"
    "$nm" -A -u "$archive" > /tmp/archive-symbols
    cat /tmp/archive-symbols
    printf 'ARCHIVE_TIME_REFERENCES %s\n' "$archive"
    grep -Ei 'time|stat|select|poll' /tmp/archive-symbols || true
done < /tmp/linked-archives
printf 'PASS: ARM cross-build machine identity and measured ABI; no target runtime or radio acceptance\n'
