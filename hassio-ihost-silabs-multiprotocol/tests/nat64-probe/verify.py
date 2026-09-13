#!/usr/bin/env python3
"""Build-only source/flag evidence; does not initialize OTBR or a radio."""
import json
import re
import shlex
import subprocess
from pathlib import Path

cache = {}
for line in Path("/probe/CMakeCache.txt").read_text().splitlines():
    match = re.match(r"([^:#/][^:]*):[^=]+=(.*)$", line)
    if match:
        cache[match[1]] = match[2]

# Compare every explicit production CMake flag. The sole intentional input
# difference is installed CPC versus the production source-directory parameter.
production = Path("/probe-production-Dockerfile").read_text()
command = production.split("./script/cmake-build", 1)[1].split("&& cd build/otbr/", 1)[0]
flags = [arg[2:].split("=", 1) for arg in shlex.split(command.replace("\\\n", " ")) if arg.startswith("-D")]
assert len(flags) >= 20, "Production compiler invocation was not parsed"
for name, value in flags:
    if name == "CPCD_SOURCE_DIR":
        assert cache[name] == "", "Probe must use released installed CPC"
        print(f"INTENTIONAL DIFFERENCE: {name}={value} in production; empty installed-CPC selection in probe")
        continue
    assert cache.get(name) == value, (name, value, cache.get(name))
    print(f"ALIGNED: {name}={value}")

entries = json.loads(Path("/probe/compile_commands.json").read_text())

# The DNS override belongs to the existing POSIX header, never raw compiler flags.
# Keep the exact compile commands for preprocessing; do not reconstruct CXXFLAGS.
dns_macro = "OPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF"
for name, value in cache.items():
    if name.startswith(("CMAKE_C_FLAGS", "CMAKE_CXX_FLAGS")):
        assert dns_macro not in value, (name, value)
        print(f"COMPILER FLAGS (no DNS override): {name}={value}")
for entry in entries:
    assert dns_macro not in entry["command"], entry["file"]

def effective_macros(suffix):
    matches = [entry for entry in entries if entry["file"].endswith(suffix)]
    assert len(matches) == 1, (suffix, len(matches))
    entry = matches[0]
    original = shlex.split(entry["command"])
    args = []
    skip = False
    for arg in original:
        if skip:
            skip = False
        elif arg == "-o":
            skip = True
        elif arg != "-c":
            args.append(arg)
    text = subprocess.check_output(args + ["-E", "-dM"], cwd=entry["directory"], text=True)
    return dict(re.findall(r"^#define ([A-Z0-9_]+) (.*)$", text, re.MULTILINE))

posix = effective_macros("/posix/platform/resolver.cpp")
assert posix["OPENTHREAD_POSIX_CONFIG_NAT64_CIDR"] == '"192.168.255.0/24"'
assert posix["OPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF"] == "0"
print("COMPILED: fixed NAT64 pool 192.168.255.0/24; host-configured upstream DNS follows host routing (binding=0)")
rcp = effective_macros("/ncp/rcp_host.cpp")
for macro in ("OTBR_ENABLE_FEATURE_FLAGS", "OTBR_ENABLE_NAT64", "OTBR_ENABLE_DNS_UPSTREAM_QUERY"):
    assert rcp[macro] == "1", (macro, rcp.get(macro))
    print(f"COMPILED: {macro}=1")

# These are pinned source-default facts, not a startup or persisted-state test.
root = Path("/usr/src/openthread/src/core")
def source_evidence(path, fragment):
    text = path.read_text()
    assert fragment in text, (str(path), fragment)
    line = text[:text.index(fragment)].count("\n") + 1
    print(f"SOURCE DEFAULT: {path}:{line}: {fragment}")
source_evidence(root / "net/nat64_translator.cpp", ", mState(State::kStateDisabled)")
source_evidence(root / "border_router/routing_manager.cpp", "RoutingManager::Nat64PrefixManager::Nat64PrefixManager")
routing = (root / "border_router/routing_manager.cpp").read_text().split("RoutingManager::Nat64PrefixManager::Nat64PrefixManager", 1)[1].split("{", 1)[0]
assert ", mEnabled(false)" in routing
print("SOURCE DEFAULT: Nat64PrefixManager initializer has mEnabled(false)")
source_evidence(root / "net/dnssd_server.cpp", ", mEnableUpstreamQuery(false)")
rcp_source = Path("/usr/src/ot-br-posix/src/ncp/rcp_host.cpp").read_text()
auto_enable = rcp_source.split("#if !OTBR_ENABLE_FEATURE_FLAGS", 1)[1].split("#endif // OTBR_ENABLE_FEATURE_FLAGS", 1)[0]
assert "otNat64SetEnabled(mInstance, /* aEnabled */ true);" in auto_enable
assert "otDnssdUpstreamQuerySetEnabled(mInstance, /* aEnabled */ true);" in auto_enable
print("SOURCE DEFAULT: automatic NAT64/DNS enabling is excluded by compiled FEATURE_FLAGS=1")
print("LIMIT: constructor/initialization-source evidence only; no runtime startup or persisted-state proof")
