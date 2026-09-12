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
