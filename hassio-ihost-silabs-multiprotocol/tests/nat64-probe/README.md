# Pinned vendor NAT64 build probe

This isolated AMD64 build gate recompiles OTBR from Silicon Labs SDK
`da661283f301b53eec04d1016009e60bc7e34a1f` against the unchanged installed CPC
headers/library of the digest-pinned 1.0.2 release. It does not build the complete
production image, Zigbee, CPC daemon, SLC outputs or firmware.

The probe compares every explicit production Dockerfile CMake flag with its
cache, including the fixed `OT_POSIX_NAT64_CIDR=192.168.255.0/24`. The intentional
exception is an empty `CPCD_SOURCE_DIR`, selecting the installed released CPC
through the vendor's supported Findcpc path. Additional build-only differences
are compile-command export, a probe output directory, building only otbr-agent
and ot-ctl, and a separate pinned simulation unit target. Production WEB/REST,
MultiPAN, vendor transport/CLI, Thread 1.4, FEATURE_FLAGS, NAT64 and upstream-DNS
settings remain aligned. Production SDK patches, including the host-DNS routing
configuration patch, are applied.

Actual resolver/RCP compiler commands are replayed as preprocessors to verify
the fixed pool, enabled feature flags/capabilities and DNS interface binding `0`.
The verifier rejects this macro in raw compiler arguments or C/CXX cache flags;
it must come from the existing generated POSIX configuration header. Compiler
flags are reported without being overwritten or reconstructed. Pinned constructors start the translator/prefix manager/upstream query
disabled, and FEATURE_FLAGS excludes the automatic enable block. Those recorded
source facts do not prove runtime startup or behavior with persisted state.

```sh
docker build --progress=plain \
  -f hassio-ihost-silabs-multiprotocol/tests/nat64-probe/Dockerfile \
  -t otbr-nat64-probe hassio-ihost-silabs-multiprotocol
docker run --rm --network none --cap-drop ALL otbr-nat64-probe
```

The native `ot-test-nat64` target runs during the build. The final stage uses the
original released runtime libraries: CPC/Zigbee hashes must match, rebuilt
binaries must resolve their loader dependencies, and otbr-agent must print its
version. No init, radio, discovery or network service is started. No devices,
host mounts or production data are supplied; no image/artifact is uploaded.

Build-only APT inputs use the official 2026-08-31 signed Debian snapshot because
live Bullseye security package URLs returned 404. Package signatures/hashes stay
verified; metadata expiry is disabled only on the fixed snapshot URLs. This is
not a runtime OS upgrade. The final image remains the exact released digest.

Passing establishes vendor compile/link feasibility, native translator unit
coverage and loader compatibility on AMD64. IPv4 firewall packets, actual
translator connectivity, DNS reachability/synthesis, runtime startup, ARM and
shared-radio behavior require their separate gates. The separate pinned virtual-radio comparison covers same-interface and
cross-interface host DNS with both binding settings; see ../NAT64-VALIDATION.md.
