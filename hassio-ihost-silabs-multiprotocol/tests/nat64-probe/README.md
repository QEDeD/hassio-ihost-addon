# Optional NAT64/upstream-DNS build investigation

This is an isolated feasibility probe, not an installable app or production
change. It starts from the pinned released AMD64 runtime, verifies its installed
CPC library/headers, and compiles only OTBR from the exact Silicon Labs SDK
commit. Existing OTBR patches and build flags, including feature flags,
MultiPAN, vendor CPC transport and vendor CLI, are preserved. The only added
capability flags are OTBR_NAT64 and OTBR_DNS_UPSTREAM_QUERY.

SLC, Zigbee, CPC daemon and firmware are not rebuilt. The vendor's
posix_vendor_rcp.cmake supports this installed-CPC route through Findcpc.cmake.
Missing released CPC headers/libraries are a failed gate, not permission to
silently substitute a new library. Hash checks require unchanged CPC/Zigbee.

```sh
docker build --progress=plain -f hassio-ihost-silabs-multiprotocol/tests/nat64-probe/Dockerfile -t otbr-nat64-probe hassio-ihost-silabs-multiprotocol
docker run --rm --network none --cap-drop ALL otbr-nat64-probe
```

Builds download public source/packages. The final container only checks hashes,
loads the rebuilt binaries against the original runtime libraries and prints
version/evidence. It starts no init, radio, discovery or network services, has
no network connectivity, devices, mounts or production data. No image or artifact
is uploaded. The native ot-test-nat64 target comes from the same SDK's OpenThread
source and runs inside the build stage; it is not a physical-radio test.

Success would establish compile/link feasibility and native translator unit
coverage. It would not establish startup defaults, packet forwarding, DNS
reachability, address synthesis, firewall cleanup, ARM, or shared-radio traffic.
The build is deliberately a probe and may expose missing exact-source inputs.

Next gate: reuse the pinned tests/scripts/thread-cert/border_router/internet/
test_upstream_dns.py topology. Its existing DNS server is on the infrastructure
link, so it does not cover Supervisor DNS reached over a different interface.
Exercise that extra route explicitly before selecting the pinned resolver's
UPSTREAM_DNS_BIND_TO_INFRA_NETIF policy. That test requires the existing broader
Thread simulation environment; it is intentionally not recreated here.
