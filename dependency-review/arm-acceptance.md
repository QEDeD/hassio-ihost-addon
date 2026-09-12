# Trixie ARM acceptance — 2026-09-13

## Outcome and reviewed plan

Extend the successful AMD64 evidence to the actual ARM build paths while keeping
CPC v4.6.1, SDK v2024.12.1-0 and the checked SLC bytes fixed. No production,
firmware, upstream submission or SDK upgrade is authorized by this audit.

First build the unchanged CPC and generated Zigbee stages for armv7 and aarch64
in parallel on disposable AMD64 GitHub runners. Inspect final-base metadata
without executing it. Measure compiler defaults, time-related structure sizes,
ELF machine/class/hard-float identity, linked dependencies and time symbol
references. Existing pinned acquisition checks remain; the only new Dockerfile
instrumentation retains CPC build metadata in the disposable cross stage.

Independent source review supports this gate before slower complete ARM images:
- The ARMv7 toolchain incorrectly declares aarch64, but explicitly selects the
  arm-linux-gnueabihf compiler. Preserve it for the diagnostic baseline; the pinned
  CPC root CMakeLists has no processor conditional. Zigbee has separate SLC
  selection (linux_arch_32 -> arm32v7; linux_arch_64 -> arm64v8).
- Trixie documents time64 compiler defaults on armhf. Measure actual target
  time_t/off_t/timespec/timeval layout and feature macros rather than assuming
  that a direct Make build retains time32 or reading __TIMESIZE alone.
- CPC's public cpc_timeval_t uses two int fields; it is not itself a libc timeval
  ABI boundary. Prebuilt vendor archives still need examination: a successful
  link alone does not prove that private structures agree with rebuilt callers.

Primary sources:
https://manpages.debian.org/trixie/dpkg-dev/dpkg-buildflags.1.en.html
https://github.com/SiliconLabs/cpc-daemon/blob/a15eb6b608497535dd1c3d9bd8871f6a4865c443/lib/sl_cpc.h
https://www.debian.org/releases/trixie/release-notes/whats-new.html

## Assessment and next decision

Require successful actual cross builds and correct target ELF identities. ABI
layout is measured with object-symbol sizes; ARM code is never executed in this
first gate. Default and explicit time64 layouts are compared. Mixed time symbol
references are a review signal, not automatically an incompatibility.

A failure must be attributed to source, fixture or environment before changing
anything. Stop for a wrong-machine output or unresolved vendor ABI mismatch.
If results are coherent, proceed to complete target-image builds and isolated
loader/application checks; these first stages exclude native OTBR compilation,
final runtime linkage, physical coexistence and HAOS kernel acceptance.

Commands: tests/arm-audit/run.sh armv7 and aarch64 via trixie-arm-audit.yml.
Inputs and runtime bounds are in the scripts. No artifact upload or credentials
are needed; logs contain public source/build metadata only.

## First execution and next cycle

Run34721866430 at02cf539 stopped before compilation: docker cp did not follow
/etc/os-release's symlink. Fixture correction7be6deb uses docker cp -L.
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34721942831 passed both
actual cross builds at7be6deb. Both target images identify as Trixie. All three
inspected artifacts (cpcd, libcpc, zigbeed) match their ARM machine/class; ARMv7
is hard-float. Default and explicit time64 probes both measured time_t/off_t8,
timespec/timeval16, alignments8 and member offsets8 on both architectures.
ARMv7 defines _TIME_BITS64 and _FILE_OFFSET_BITS64 by default; its compiled
binaries reference glibc time64 entry points. The inaccurate CMake processor
label persisted but did not cause wrong-machine binaries in this build.

The first archive search found no archives under output; it did not establish
vendor-archive compatibility. Source/log inspection shows SDK-relative inputs.
Next cycle resolves .a inputs from the actual make dry-run and requires archive
hash/member/symbol inspection rather than silently treating no matches as a pass.
Then it builds the complete unchanged target image (including native OTBR) under
pinned QEMU, with a20-minute build bound, and reuses installed linkage inventory
and no-radio native web probes. This adds no physical-radio or HAOS-kernel claim.
The QEMU registration runs only on disposable hosted runners. No changes to the
operator's Docker installation or production deployment are involved.

### Evidence qualifications from independent review

The passing cross run used GCC 14.2.0 (Debian cross package14.2.0-19cross1),
target glibc headers/libraries2.41-11cross1, binutils2.44-3 and target kernel
headers6.12.38-1cross1. The AMD64 build-host glibc was2.41-12+deb13u4; that is
not the target sysroot version. All six artifact machine/class checks passed.
The ABI object probes measure normal compiler/header defaults, not every
translation unit's effective definitions or all vendor-private structures.

ARMv7 zigbeed imports __clock_gettime64, __fstat64_time64 and __select64 alongside
legacy time@GLIBC_2.4. This is a provenance question, not proof of corruption.
Rebuilt system-timer.c keeps timespec local and returns a uint32_t tick; CPC's
public timeout structure likewise does not expose libc time_t. Complete archive
caller attribution remains necessary before claiming that mixed symbols are safe.

Run34722291698 at2601cff rebuilt both cross targets successfully, then failed
inside the enhanced inspection: GNU make's $(file ...) writes a linker response
file even with -n, and the source filesystem was deliberately read-only. Fixture
correction2b43feb redirects only OUTPUT_DIR to writable /tmp during the dry run.
Independent full-image checks now execute even if static inspection fails, and
the aggregate job retains the inspection failure. No application semantic change
was made in response to either fixture error.

## Complete-image run and independent archive review

Run [34722484706](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34722484706)
at 2b43feb passed both cross builds and both archive probes. Each target links
15 distinct SDK archives, all from release_singlenetwork directories.
ARMv7 libzigbee-pro-stack.a has SHA256
8ae420936a2ebdc9080f021ff5719c409a1d45726229bfaa7615750d212e3cc8;
its lower-mac-spinel.c.o imports legacy time. The public SDK tree has no source
for that object. This identifies a possible 2038 limitation, not a demonstrated
caller/callee ABI mismatch. The same object on AArch64 imports native 64-bit time.
Do not claim private ABI compatibility from the successful links.

Complete target images did not pass:
- ARMv7: native GCC 14.2.0 failed in bundled mbedTLS bignum_core.c,
  mbedtls_mpi_core_mla, with an inline-assembly register-constraint error through
  bn_mul.h:785. The failing command has no optimization flag. This is a real
  build blocker in the unchanged build path, not a probe failure.
- AArch64: compilation reached OTBR step 314/529 before the 1200-second bound
  expired (exit 124). No compiler failure was established for this target.
- Neither reached final-image linkage inventory or the no-radio native web probe.

Next bounded experiment: reproduce only the failing ARMv7 translation unit
using the pinned SDK and Trixie cross compiler, then compare baseline, -O1 and
-O2. An optimization explanation is a hypothesis until that comparison runs.
Native-versus-cross compiler differences must remain explicit. Avoid another
complete ARMv7 build until this cheaper experiment resolves the blocker.
For AArch64, consider a native runner or a longer bounded build after the
ARMv7 result; do not interpret the timeout as either success or incompatibility.

## Isolated compiler comparison and candidate correction

Run [34723768432](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34723768432)
at c60fd34 reproduced the original inline-assembly register-constraint failure
using captured flags and the pinned SDK with Trixie ARM cross GCC14.2.0. Both
-O1 and -O2 compiled that same translation unit into ARM ELF32 objects. The
parent independently inspected the test and CI evidence. No SDK update or
assembly rewrite was needed for this limited result.

Candidate406e53c adds only -DCMAKE_BUILD_TYPE=Release to the actual OTBR build
invocation. The pinned cmake-build script passes these arguments to CMake.
Previously RELEASE=1 was scoped to bootstrap and did not select the subsequent
CMake build type. Release also defines NDEBUG and changes optimization across
OTBR; full-image and runtime tests remain required, including AMD64 regression
checks. Do not treat the one-file compiler result as full crypto or radio validation.

The extended probe measures the installed CMake GNU Release flags before testing
them against the same translation unit. Broad image CI was deliberately skipped
for this commit; only the focused workflow was manually dispatched. The next
release gate is complete ARMv7/AArch64 images and fresh AMD64 regression checks,
followed by existing isolated runtime tests. Production remains on its previous
image; the observed physical radio hang is a separate unresolved issue.
Run34723961919 stopped in test setup because the lean probe image lacked make.
Probe-only correction8b84404 adds that build tool. The corrected run
[34724039273](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34724039273)
passed: installed CMake measured -O3 -DNDEBUG; baseline failed with the expected
register-constraint diagnostic; -O1, -O2 and Release all compiled. This validates
the narrow candidate correction, with the full-image gates above still open.