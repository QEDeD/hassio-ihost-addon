"""Compare captured no-optimization flags, -O1/-O2, and measured CMake Release.
Cross GCC substitutes native GCC. No link, target execution, crypto correctness
or full-image claim. Source command: run 34722484706, job 103630776095,
2026-09-12T22:36:53.
"""
import hashlib
from pathlib import Path
import shlex
import subprocess

sdk = "/probe/sdk/util/third_party"
command = shlex.split(Path("original-command.txt").read_text())
assert command[0] == "/usr/bin/cc"
args = []
skip = False
for arg in command[1:]:
    if skip:
        skip = False
        continue
    if arg in ("-MT", "-MF", "-o"):
        skip = True
        continue
    if arg == "-MD":
        continue
    arg = arg.replace("/usr/src/ot-br-posix/third_party/openthread/repo", sdk + "/openthread")
    arg = arg.replace("/usr/src/ot-br-posix/third_party/openthread/mbedtls-config.h",
                      sdk + "/ot-br-posix/third_party/openthread/mbedtls-config.h")
    args.append(arg)
assert not any(arg.startswith("-O") for arg in args)
compiler = "arm-linux-gnueabihf-gcc"
subprocess.run([compiler, "--version"], check=True)
subprocess.run(["dpkg-query", "-W", "cmake", "gcc-14-arm-linux-gnueabihf", "libc6-dev-armhf-cross"], check=True)
# Measure GNU Release initialization from installed CMake rather than assume it.
cmake_source = Path("/tmp/release-cmake")
cmake_source.mkdir()
(cmake_source / "CMakeLists.txt").write_text(
    'cmake_minimum_required(VERSION 3.16)\n'
    'project(release_flags C)\n'
    'file(WRITE "${CMAKE_BINARY_DIR}/release-flags" "${CMAKE_C_FLAGS_RELEASE}")\n'
)
subprocess.run(["cmake", "-S", str(cmake_source), "-B", "/tmp/release-build",
                f"-DCMAKE_C_COMPILER={compiler}", "-DCMAKE_BUILD_TYPE=Release"],
               check=True, timeout=60)
release_flags = shlex.split(Path("/tmp/release-build/release-flags").read_text())
print("CMAKE_GNU_RELEASE_FLAGS", shlex.join(release_flags), flush=True)
assert release_flags == ["-O3", "-DNDEBUG"], "Unexpected CMake GNU Release defaults"
for path in [args[-1], sdk + "/ot-br-posix/third_party/openthread/mbedtls-config.h"]:
    print("SOURCE_SHA256", hashlib.sha256(Path(path).read_bytes()).hexdigest(), path, flush=True)
results = {}
for label, extra in [("original", []), ("O1", ["-O1"]), ("O2", ["-O2"]), ("Release", release_flags)]:
    invocation = [compiler, *args, *extra, "-o", f"/tmp/{label}.o"]
    print("COMMAND", shlex.join(invocation), flush=True)
    result = subprocess.run(invocation, capture_output=True, text=True, timeout=60)
    print(result.stdout, result.stderr, sep="", flush=True)
    print(f"RESULT mode={label} exit={result.returncode}", flush=True)
    results[label] = result
    if result.returncode == 0:
        subprocess.run(["arm-linux-gnueabihf-readelf", "-h", f"/tmp/{label}.o"], check=True)
assert results["original"].returncode != 0, "Original failure did not reproduce"
assert "impossible constraints" in results["original"].stderr, "Different baseline failure"
assert all(results[mode].returncode == 0 for mode in ("O1", "O2", "Release")), "Optimized compile failed"
print("PASS: captured unoptimized ARMv7 translation unit fails; -O1, -O2 and measured CMake Release compile. Cross compiler only; no linked/runtime acceptance.")
