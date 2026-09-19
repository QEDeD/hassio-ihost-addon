# SDK2026 DNS routing regression

2026-09-19: PASS. The candidate now applies the exact source diff from Stefan Agner's OpenThread commit `82eb4863ade08819cf35c28ff3c8bb9f93a06213` (PR13545), under the existing OpenThread BSD-3-Clause source notices. The legacy SDK's global interface-binding override is omitted only from the SDK2026 recipe. Original contribution patch files/branches are untouched.

`run.py` compiles the **actual complete SDK resolver.cpp and mainloop.cpp**, using retained SDK CMake compilation flags and real SDK headers. It links `test-resolver.cpp` fixtures for message payload/logging and operating-system boundaries. Captured socket/send/bind calls verify routing choice; these are simulated syscalls, not physical packets. The harness asserts RDNSS socket selection and interface name, host IPv4/IPv6 unbound sends, link-local scope, mainloop read/error registration, reply delivery, cancellation and failure cleanup. It also asserts correct fallback after bind or RDNSS socket allocation failure, and host-DNS operation without an infrastructure interface.

The negative control compiles pristine SDK resolver with the previously selected global binding override (0). It must fail the RDNSS binding assertion. Then the exact upstream patch is applied with zero fuzz and policy 1 (the SDK default); all six behavior groups must pass. This catches the actual regression instead of merely verifying the presence of new source text.

The patch's only application adjustment is an automatic -11-line offset in the config documentation hunk; there are no source modifications from upstream. Full revision/author/license and source API were verified through GitHub. Source: https://github.com/openthread/openthread/commit/82eb4863ade08819cf35c28ff3c8bb9f93a06213

## Reproduce without a full image build

Use the retained offline compiler/source snapshot `sha256:f877330a2f4b8f0d497e28f9e0a4f76ba63466438d0b8aaef9da8d202b6a3ecd`. This provides SDK2026.6.1, compiler and `/sdk2026-native/build` CMake/Ninja records. It is test infrastructure, not the candidate image or a new production artifact. From repository root in PowerShell:

```powershell
docker run --name sdk2026-dns-check --network none --detach --entrypoint /bin/sleep sha256:f877330a2f4b8f0d497e28f9e0a4f76ba63466438d0b8aaef9da8d202b6a3ecd infinity
docker cp review/sdk2026/dns-tests sdk2026-dns-check:/tmp/dns-tests
docker cp review/sdk2026/recipe/dns-routing-sdk2026.patch sdk2026-dns-check:/tmp/dns-routing.patch
docker exec sdk2026-dns-check python3 /tmp/dns-tests/run.py /tmp/dns-routing.patch
docker rm -f sdk2026-dns-check
```

Use a fresh unique container name if that name exists. No device mappings, mounts, host networking or production endpoints. Source is copied into a temporary directory and removed on exit. The test explicitly selects macro1 to supersede the retained CMake snapshot's old generated-header override; the **new product recipe** obtains default1 by removing that old patch. A full rebuild must confirm effective generated configuration as well.

`results.txt` records the completed run. Test setup initially corrected a fixture ABI return type and missing logging stubs; final passing results concern the finished harness.

## Remaining build/acceptance work

No candidate image was rebuilt. Rebuild with the existing `CPC_ENCRYPTION=ON` SDK2026 build entry point, record the new immutable image ID, confirm `OPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF` resolves to 1 in the final compiler preprocessor output, and rerun image verification/lifecycle plus relevant API checks for that artifact. Old image `7f610...` and old combined-image tests do not cover the changed binary. Radio/CPC operation, real DNS reachability, physical RDNSS/NAT64 and recovery remain separate acceptance work.
