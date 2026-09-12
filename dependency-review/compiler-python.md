> Source-review snapshot. The later test results and current remaining gates are
> recorded in [plan-and-results.md](plan-and-results.md); pending-test language
> below describes the state when this specialist review was written.

# Trixie: compiler, CMake and Python compatibility review

2026-09-12. Bounded source/evidence review; no application edits, builds, CI runs
or production access in this review. CPC remains v4.6.1, SDK remains
`da661283f301b53eec04d1016009e60bc7e34a1f`. Read alongside
[the dependency assessment](baseline.md).

## Result and evidence boundary

[CI 34707535921](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34707535921)
actually compiled CPC, generated Zigbee, vendor OTBR, mDNSResponder and the web
assets/server on AMD64 with GCC 14.2. No application compatibility patch was
needed. The final five binaries have resolved dynamic dependencies. This closes
many hypothesized compile failures; it does not establish service behavior,
ARM ABI compatibility or feature equivalence with the deployed binaries.

PR79 baseline disables NAT64 and upstream-DNS compilation. The optional feature
and its Python pool helper are not covered by that build. SLC's archive includes
Python 3.10, so successful SLC generation in a system-Python-3.13 image does not
identify the interpreter the generator actually executed.

## GCC 11 through 14: applicable changes

- **GCC 11 changed the default C++ dialect to GNU++17.** That is not an automatic
  OTBR/OpenThread dialect upgrade: both pinned CMake sources explicitly select
  C++11; OpenThread also selects C99. CPC explicitly requires C99 with POSIX/GNU
  feature-test definitions, and the logged Zigbee invocation sets `-std=gnu99`.
  Do not add a blanket C++17 migration or compatibility flag. Generated Zigbee
  C++ flags are a remaining evidence detail; its successful AMD64 build already
  exercises the actual generator output. [GCC 11 notes](https://gcc.gnu.org/gcc-11/porting_to.html),
  [OTBR flags](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/CMakeLists.txt),
  [OpenThread dialect](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/openthread/CMakeLists.txt),
  [CPC dialect](https://github.com/SiliconLabs/cpc-daemon/blob/v4.6.1/CMakeLists.txt).
- **GCC 11-13 remove incidental C++ header inclusions; GCC 12 adds library
  deprecation warnings.** These matter because OTBR adds `-Werror`, although its
  web target already suppresses deprecated-declaration diagnostics. The complete
  build, including the web target, found no blocking missing-header/deprecation
  issue in the selected AMD64 paths. That is evidence for those paths, not for
  dormant feature combinations. [GCC 12](https://gcc.gnu.org/gcc-12/porting_to.html),
  [GCC 13](https://gcc.gnu.org/gcc-13/porting_to.html),
  [web target flags](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/web/CMakeLists.txt).
- **GCC 13 changes implicit-move overload resolution; GCC 14 makes invalid-C
  diagnostics errors.** Compile success rules out diagnosed failures in the
  built paths, not every possible behavior change. There is no identified
  application defect justifying a language downgrade. Existing Thread/Zigbee,
  discovery and web behavior tests are the proportionate runtime gate.
  [GCC 13](https://gcc.gnu.org/gcc-13/porting_to.html),
  [GCC 14](https://gcc.gnu.org/gcc-14/porting_to.html).
- **Feature probes deserve separate attention.** GCC 14's stricter checking can
  turn an old configure probe into a false negative. The log shows successful
  CPC warning-option probes, Backtrace discovery and libc-pthread probes for CPC
  and OTBR; no matching failed compiler-test result was found in the inspected
  log. It is not a complete old/new cache comparison. Final OTBR newly links
  libsystemd; distinguish this detected feature change from the earlier optional
  `systemd` package lookup failure. Do not interpret libc absorbing pthread
  symbols as threading being disabled.

Observed mDNS warnings are enum conversion and transposed `calloc` arguments
(log lines 18678-18737). Its existing build flags include `-fwrapv -W -Wall`.
These warnings are not evidence that the audit disabled OTBR's `-Werror`, and do
not alone establish a runtime defect. The two `calloc` argument positions still
represent a product; do not infer incorrect allocation size from this warning
without inspecting that call's types and values.

## CMake: actual migration surface

The old project minima remain accepted by 3.31. The log records legacy cJSON
version-policy/deprecation warnings, but no failed configuration. Boost's
[CMP0167](https://cmake.org/cmake/help/v3.31/policy/CMP0167.html) warning is followed
by successful Boost 1.83 filesystem/system discovery. Leave project policy changes
out until a concrete need is demonstrated; raising minimum versions can activate
additional policies. [CMake 3.31 migration notes](https://cmake.org/cmake/help/v3.31/release/3.31.html).

[CMP0148](https://cmake.org/cmake/help/v3.31/policy/CMP0148.html) removes old Python
finder modules under NEW behavior. The bundled mbedTLS code uses FindPython3 for
CMake >=3.15, so its legacy FindPythonInterp branch is not selected here. The log
explicitly found `/usr/bin/python3` 3.13.5 at line 19774.

CPC handles pre-3.24 warning-as-error support explicitly; 3.31 has the native
CMake mechanism. That is not a reason to force it on or off. Missing pkg-config
in the CPC stage is nonfatal with encryption OFF: crypto discovery is guarded;
Backtrace and Threads still succeeded. [CPC warnings](https://github.com/SiliconLabs/cpc-daemon/blob/v4.6.1/cmake/Warnings.cmake).

**Concrete gap:** bundled mbedTLS runs `scripts/config.py ... get
MBEDTLS_CTR_DRBG_USE_128_BIT_KEY` using execute_process, then only tests whether
its result equals zero to display a warning. A normal missing setting returns 1,
but an unexpected script failure can also be nonzero. Therefore Python discovery
plus successful CMake is weaker than an explicit script behavior check.
[Invocation](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/openthread/third_party/mbedtls/repo/CMakeLists.txt),
[query semantics](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/openthread/third_party/mbedtls/repo/scripts/config.py).

## Python 3.10 through 3.13: applicable API review

The directly inspected production-side config.py imports os, re, argparse and
sys. The optional NAT64 helper imports ipaddress, json, subprocess and sys. No
use of the following removed APIs was identified in those two scripts; this is
not an exhaustive scan of all SDK tooling or the SLC archive.

| Migration | Relevant compatibility filter | Assessment for inspected paths |
|---|---|---|
| [3.10](https://docs.python.org/3.10/whatsnew/3.10.html#removed) | collections ABC aliases and many asyncio loop parameters removed | Neither inspected script uses them. Installed aiohttp does not by itself prove an application asyncio call path. |
| [3.11](https://docs.python.org/3.11/whatsnew/3.11.html#removed) | inspect.getargspec/formatargspec removed | No matching use in these scripts. SLC internals remain a separate interpreter boundary. |
| [3.12](https://docs.python.org/3.12/whatsnew/3.12.html#removed) | distutils/imp and old configparser APIs removed; venv no longer supplies setuptools by default | Neither inspected script imports these modules. Production bootstrap uses APT rather than a system-pip install. Do not add setuptools or disable package-management protection without a demonstrated need. |
| [3.13](https://docs.python.org/3.13/whatsnew/3.13.html#removed-modules-and-apis) | Removed modules include cgi and pipes; ipaddress private/global classification changes | These scripts do not use removed modules. The pool helper uses network parsing/overlaps, not is_private/is_global, so that classification change does not alter its decision rule. |

Python 3.13 can use posix_spawn in more subprocess cases. The helper depends on
checked exit status, captured text and a finite timeout; verify those behaviors
through its existing tests rather than assuming a different process-launch path
is a defect. No Python C-extension compilation path was established for these
two scripts. Debian's installed Python extensions and SLC's bundled environment
must not be treated as one shared ABI.

## Completed checks and smallest remaining gates

Completed evidence: full AMD64 PR79 compilation and final linkage inventory;
logged GCC/Boost/Python discovery; actual warning/probe review; official migration
notes mapped to pinned flags and the two directly relevant Python scripts. This
review did not rerun binaries or tests.

1. On the isolated Trixie build environment, explicitly run pinned config.py with
   a tiny temporary header containing one enabled MBEDTLS_* setting and one
   commented-out setting. Assert `get` returns 0 and 1 respectively and produces
   no traceback. This closes the masked nonzero-result gap without changing code.
2. If combining NAT64, run the existing pool tests under Trixie Python 3.13 and
   real JSON inspection fixtures; rebuild the enabled vendor features and run
   their established functional/lifecycle gates. PR79 baseline did not do this.
3. Preserve compiler commands/cache/generated feature definitions for comparison
   when the next build runs. Examine language dialects, warnings, detected
   libraries and selected features; this is more useful than rebuilding every
   intermediate GCC/Python version.
4. Run the existing isolated service/discovery/web and network regression gates,
   then separately validate ARM. For ARM32 measure _TIME_BITS/_FILE_OFFSET_BITS
   and sizeof(time_t); Debian's library transition does not automatically supply
   flags to direct Make/CMake application builds.

No SDK upgrade, blanket warning relaxation, Python dependency addition or language
standard change is justified by the evidence in this bounded review.
