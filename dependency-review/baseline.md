> Initial investigation snapshot. See [plan-and-results.md](plan-and-results.md)
> for the subsequent review, successful runtime tests and current remaining gates.

# Trixie upgrade: dependency impact investigation

Status: complete first investigation cycle. Full AMD64 PR79 build and installed
image/linkage inventory PASSED in CI34707535921 at77287ce (4m32s).
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34707535921
Production unchanged; startup/radio/ARM acceptance is not claimed.

## Measured result

The original SDK/CPC source versions built successfully with PR79's Debian/package
changes. Acquisition-only adaptations pinned public base images and SLC bytes and
asserted source revisions. The build included generated Zigbee, CPC, vendor OTBR,
web frontend and normal package cleanup. No application source fix was needed.
All five expected application binaries exist; ldd found no missing libraries.
This is PR79 baseline: NAT64/upstream-DNS translator features are OFF, so it does
not establish Trixie compatibility of our optional NAT64/DNS contribution.
This is dynamic-link resolution, not execution of services or physical acceptance.

Exact installed packages: released image220, built Trixie224. All recorded entries
are installed (dpkg status ii). There are161 shared package-name entries with changed
versions,63 added and59 removed entries. Many additions/removals are library ABI
or package-name transitions, not independent added/removed application features.
See trixie-installed-package-diff-34707535921.csv for every entry and
trixie-image-inventories-34707535921.json for base/build inventories and linkage.

| Measured component | Released image | Built Trixie | Concrete overlap |
|---|---|---|---|
| glibc |2.31-13+deb11u13|2.41-12+deb13u4|All five application binaries link to libc|
| libstdc++ |10.2.1-6|14.2.0-19|OTBR, web and Zigbeed link to it|
| Python |3.9.2-3|3.13.5-1|OTBR CMake actually selected /usr/bin/python3,3.13.5|
| Node |12.22.12~dfsg-1~deb11u7|20.19.2+dfsg-1+deb13u2|Web package installation passed; npm was removed from both final images|
| iproute2 |5.10.0-4|6.15.0-1|ip/ss commands used by networking/readiness|
| iptables |1.8.7-1|1.8.11-2|Firewall scripts; runtime/kernel behavior still requires tests|
| ipset |7.10-1|7.22-1+b1|Firewall scripts; same remaining runtime gate|
| socat |1.7.4.1-3|1.8.0.3-1+deb13u1|Zigbee PTY/TCP bridge|
| netcat-openbsd |1.217-3|1.229-1|Both images already contain OpenBSD netcat; PR79 makes selection explicit|
| Debian mbedTLS |libmbedtls12,2.16.9-0.1+deb11u3|libmbedtls21,3.6.6-0.1~deb13u1|Installed, but none of five application ldd outputs uses it; CPC encryption OFF|
| s6-overlay |3.1.6.2|3.2.3.0|Actual /package/admin versions; init behavior must be retested|
| s6 / s6-rc |2.12.0.2 /0.5.4.2|2.15.0.0 /0.6.1.0|Readiness, finish and shutdown semantics|
| HA base release label |2025.06.1|2026.08.0|Separate from Debian; latter release source configures Bashio0.17.5|

The SLC archive includes bundled Python3.10. Successful generation in an image
with system Python3.13 does not establish which interpreter SLC used. OTBR CMake
separately selected system Python3.13, as logged.

The Bashio internal BASHIO_VERSION constant reads0.1.0 in both images; it is not
usable as a release identifier. Bashio0.17.0->0.17.5 is source/base-provenance
attribution, not a successful version-command measurement in this audit.

Material warnings/findings from the actual build:

- GCC14 compiled the intended targets; mDNS emitted enum-conversion and transposed
  calloc-argument warnings, without stopping compilation. No blanket warning bypass
  was added by this audit.
- CMake CMP0167 warning fell back successfully to Boost1.83 discovery. Another
  existing cJSON project-version warning is not a failed configuration.
- Bootstrap tried git submodule update before git existed, then explicitly ignored
  the error. The SDK's supplied sources still built; record this acquisition
  assumption rather than treating the overall green result as a warning-free build.
- Actual npm selection included Angular1.8.3/material1.2.5 rather than the older
  source-lock versions. This confirms the omitted-lockfile consequence. npm also
  reported one moderate and one high vulnerability; advisory applicability and
  runtime exposure have not been assessed, and no automatic npm audit fix was run.
- Actual OTBR newly links libsystemd (absent in the released OTBR linkage), plus
  libnetfilter_queue, libcpc, libdns_sd and
  libprotobuf-lite. DBus OFF does not mean no libsystemd dependency. Web links
  jsoncpp; Zigbeed links libcpc/libstdc++. These observations narrow package use.

## Recommendation and scope

Test a direct Trixie upgrade with CPC4.6.1 and SDK2024.12.1-0 fixed. Investigate
actual failures before changing application releases. Upgrade both compilation
base and HA runtime base. Hold radio firmware and current network state unchanged.
The completed first build covers SLC-generated Zigbee, CPC, vendor OTBR, web
and mDNS; it closes the gap left by our previous OTBR-only probe.

There are four distinct sources of dependency changes:

1. Debian packages change because the base and APT repositories change.
2. Home Assistant base-image additions (s6/Bashio/tempio) may also change with the
   selected image tag. Their versions are not determined by Debian's version.
3. Pinned SDK/CPC and bundled libraries remain fixed unless deliberately changed.
4. Unpinned downloads may change simply because we rebuild. Treat these separately
   so their failures are not misattributed to Trixie.

## Source-based impact map and repository comparison

The CSV trixie-package-comparison-20260912.csv gives exact repository candidates
for68 packages selected for comparison. This includes confirmed installed/build
inputs and investigation candidates, not68 proven required dependencies. Autoconf,
automake, libtool and python3-venv are candidates, not established production needs. Inputs are official Bullseye archive and Trixie main
AMD64 Packages indexes, recorded in trixie-package-candidates-20260912.json.
These are NOT measured installed image versions; security/updates overlays and
image age can alter exact versions. The CI inventory will establish actual inputs.

| Component | Bullseye -> Trixie package family | Where this project uses it | Relevant change and assessment |
|---|---|---|---|
| GCC/G++ |10.2 ->14.2|CPC, generated Zigbee, OTBR and mDNS compilation|GCC14 promotes several invalid-C diagnostics to errors; OTBR also uses -Werror. The identified compile risk did not block the full AMD64 build; ARM remains untested. Fix diagnosed issues individually; do not blanket-disable warnings.|
| glibc/libstdc++ |2.31/10 ->2.41/14|Compiled application and library runtime|Rebuild all copied native components consistently. Loader/linkage/startup checks required; new packages do not establish application compatibility.|
| ARM32 time ABI |Debian libraries migrate to64-bit time_t; our compiled ABI not yet measured|armv7/armhf native components and libraries|Library SONAMEs can stay unchanged despite ABI change. Direct gcc/Make builds do not automatically inherit Debian packaging flags. Inspect _TIME_BITS/_FILE_OFFSET_BITS and sizeof(time_t), rebuild consistently and test ARM independently.|
| CMake |3.18 ->3.31|CPC/OTBR configuration and feature discovery|Pinned project minima remain supported. Boost discovery policy CMP0167 changes modern behavior; unset policy retains old behavior with warning. Compare generated configuration before introducing policy changes.|
| Make/Ninja |4.3/1.10 ->4.4/1.12|Generated Zigbee and OTBR builds|Run actual generated builds; no specific incompatibility or performance benefit established.|
| Python/Jinja/pip |3.9/2.11/20 ->3.13/3.1/25|SLC generation, bundled mbedTLS config.py, optional NAT64 pool helper|Removed Python APIs and generator compatibility need execution checks. Inspected production bootstrap uses APT, not system pip installs: externally-managed Python is not presently a proven blocker.|
| Java |17 ->21|SLC generator only|Current inspected SLC5.11 changelog says it was updated to use Java21. Matching this is useful; does not itself prove SDK generation compatibility.|
| System mbedTLS |2.16,libmbedtls12 ->3.6,libmbedtls21|Installed by Dockerfile; CPC encryption is OFF|CPC's crypto discovery/sources/linking are excluded. OTBR uses SDK-bundled mbedTLS3.6.0. Package replacement is not proof of radio crypto upgrade or a CPC blocker. Inspect all final link inputs before removing apparently unused packages.|
| Node/npm |12/7 ->20/9|Installs web frontend JS/CSS|No webpack pipeline found. Actual issue is omitted committed lockfile in build directory; record installed assets/lock and consider restoring lockfile use separately.|
| Boost |1.74 ->1.83|OTBR web C++ filesystem/system components|Full web target and request handling need checks; OTBR-only compile does not cover it.|
| protobuf/jsoncpp |3.12/1.9.4 ->3.21/1.9.6|Installed by SDK bootstrap; feature-specific code generation/linking|Verify actual generated commands/linked targets, matching generated protobuf with runtime. Do not equate package installation with feature use.|
| iproute2 |5.10 ->6.15|Interface/routes, policy tables, ss readiness check|PR79 switches routing-table definition to rt_tables.d. Test named table lookup and exact ss PID parsing with new utilities.|
| iptables/ipset/nftables |1.8.7/7.10/0.9 ->1.8.11/7.22/1.1|OTBR firewall lifecycle; nft backend exposure|Rerun scoped-rule/packet/cleanup tests. New userspace still uses HAOS kernel; installing Trixie does not supply kernel features.|
| socat/netcat |1.7 ->1.8; PR79 explicitly selects netcat-openbsd|Zigbee PTY/TCP bridge; nc -z -w1 checks the OTBR REST prerequisite|Test actual socat invocation, listener ownership, connect/disconnect and the nc readiness invocation. Inspect actual old/new alternatives; package names alone do not establish the selected nc implementation.|
| Bash/jq/curl/CA |5.1/1.6/7.74/2021 ->5.2/1.7/8.14/2025|Startup/Bashio/config extraction/downloads|Existing shell/config and authenticated-error fixtures are relevant; updated certificates support maintained verified downloads; the pinned mDNS bootstrap uses wget --no-check-certificate, so its download does not benefit until verification is enabled. No need to adopt unrelated new curl features.|
| Avahi/DBus/BIND/rsyslog |0.8/1.12/9.16/8.2102 ->0.8/1.16/9.20/8.2504|Installed by SDK bootstrap, some reference/feature paths|Current OTBR selects mDNSResponder and DBus OFF. Identify surviving packages/services and dynamic dependencies before classifying as runtime needs or removing.|
| readline/ncurses/libnetfilter-queue/CppUTest/git/unzip etc.|Exact revisions in CSV|CLI/build/test/source acquisition|Record resolved versions; validate through the actual compilation/CLI/loader paths. No independent feature work justified merely by version changes.|

## Non-Debian inputs

- CPC stays v4.6.1. SDK stays da661283f301b53eec04d1016009e60bc7e34a1f.
- Bundled OTBR/OpenThread/mbedTLS do not become current upstream versions through
  a Debian upgrade. mDNSResponder1790.80.10 is separately downloaded/built (tls=no).
- Released image evidence has s6-overlay3.1.6.2 and Bashio0.17.0. Current HA base
  source6a3ff4c defaults to s6-overlay3.2.3.0/Bashio0.17.5/tempio2026.07.0, but the
  exact target image must be inspected before treating these as installed versions.
- s6-overlay3.2 removed its default startup timeout; HA base explicitly configures
  timeout behavior. New s6/s6-rc still require our real readiness/shutdown tests.
- Bashio changes include config API error handling and log output handling; verify
  missing/config-error responses and log capture, not just bash syntax.
- SLC is an unversioned download. The inspected public archive is5.11.0.0,
  SHA2565fc88e5f7e3a782a9181716bf173285d4794ea6d2282dde0c992179e3ab955f8.
  Public input URL: https://www.silabs.com/documents/login/software/slc_cli_linux.zip .
  Archive source: slc_cli/changelog identifies5.11.0.0 and says the tool was
  updated to use Java21. Older installation documentation still says Java17+;
  actual generation on21 remains the gate, rather than inferring compatibility.
  Pin/record it for the comparison; previous deployed generator version is unknown.
- Frontend source lockfile exists with exact pins, but pinned CMake copies only
  package.json then runs npm install. Thus an out-of-source build omits those pins.
  This is verified source behavior; generated dependency selection remains a build gate.

## Useful opportunities, kept proportionate

1. Restore maintained Debian package inputs and eliminate the archive workaround
   from the normal build. This is the primary benefit, without claiming every
   bundled application library receives Debian security fixes.
2. Pin the exact image digests and SLC input used for validation so failures can
   be reproduced. Pinning needs an update process; it is not automatic maintenance.
3. Check whether fixing frontend lockfile use provides a small independent
   reproducibility improvement. Do not silently roll back assets to old pins.
4. Check whether the pinned mDNS download can use certificate verification; it
   currently disables verification, so a newer CA bundle alone does not help it.
5. Verify whether crypto/reference/build packages are unused in the final image;
   remove only those demonstrated unnecessary, as a separate change if worthwhile.
6. Keep the existing network/lifecycle regression tests, rerunning them against
   the actual upgraded init and utilities. This reuses evidence rather than creating
   a parallel test framework.

## Next gates

1. Run existing readiness/firewall/shutdown tests against the actual newer init and
   utilities, then isolated application/web smoke tests. Successful compilation
   does not prove these behaviors. Also build/test the combined firewall/readiness
   changes and optional NAT64/DNS configuration before claiming their compatibility.
2. Build arm64/armv7 with matching Trixie tools, measuring ARM32 time ABI flags and
   sizes. Do not reuse old precompiled radio-host binaries in the new runtime.
3. Assess the observed frontend advisories and lockfile behavior before choosing
   a targeted asset fix; do not broaden this into a frontend rewrite by default.
4. After isolated gates, prepare a current-radio-state-preserving live coexistence
   trial under the applicable approval. No production trial was made here.

Continue with PR79 rather than inventing a competing OS-upgrade patch. No current
build evidence requires upgrading the SDK/CPC source versions. Pinning acquisition
and reducing proven unused packages are optional separate improvements, not silent
requirements for changing Debian versions.

## Primary evidence

- https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/79
- https://github.com/home-assistant/docker-base/blob/6a3ff4c10f6ed8564a092c33051024a1b1042ee2/debian/Dockerfile
- https://gcc.gnu.org/gcc-14/porting_to.html
- https://www.debian.org/releases/trixie/release-notes/whats-new.en.html
- https://cmake.org/cmake/help/v3.31/policy/CMP0167.html
- https://docs.python.org/3.13/whatsnew/3.13.html
- https://github.com/SiliconLabs/cpc-daemon/blob/v4.6.1/CMakeLists.txt
- https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/script/bootstrap
- https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/web/web-service/frontend/CMakeLists.txt
- https://github.com/just-containers/s6-overlay/releases/tag/v3.2.0.0
- https://github.com/hassio-addons/bashio/compare/v0.17.0...v0.17.5
