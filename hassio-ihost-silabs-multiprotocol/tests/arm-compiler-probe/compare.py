"""One translation unit, captured flags; cross GCC substitutes native GCC.
No link, target execution, crypto correctness or full-image claim.
Source command: run 34722484706, job 103630776095, 2026-09-12T22:36:53.
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
subprocess.run(["dpkg-query", "-W", "gcc-14-arm-linux-gnueabihf", "libc6-dev-armhf-cross"], check=True)
for path in [args[-1], sdk + "/ot-br-posix/third_party/openthread/mbedtls-config.h"]:
    print("SOURCE_SHA256", hashlib.sha256(Path(path).read_bytes()).hexdigest(), path, flush=True)
results = {}
for label, extra in [("original", []), ("O1", ["-O1"]), ("O2", ["-O2"])]:
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
assert results["O1"].returncode == 0 and results["O2"].returncode == 0, "Optimization did not resolve this compile"
print("PASS: captured unoptimized ARMv7 translation unit fails; -O1 and -O2 compile. Cross compiler only; no linked/runtime acceptance.")
