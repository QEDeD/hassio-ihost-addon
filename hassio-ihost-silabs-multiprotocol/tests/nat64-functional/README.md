# Pinned DNS/NAT64 functional baseline

This fixture reuses the SDK's existing Dockerfile, simulation build runner and
unmodified test_upstream_dns.py/test_single_border_router.py at commit
 da661283f301b53eec04d1016009e60bc7e34a1f. It requires an ephemeral GitHub-hosted
runner; run.sh refuses a normal workstation. Launch the OTBR NAT64 functional
baseline workflow. No production settings or binaries are changed.

The existing upstream BASE_IMAGE argument selects Ubuntu 22.04 for simulation,
replacing the obsolete Bionic default only in this disposable fixture. Source
semantics and observation waits are retained. Web/REST interfaces are unnecessary
for these CLI tests and are disabled; feature flags, NAT64 and upstream DNS are
explicitly compiled on. The tests explicitly enable their runtime features.
Build caches are checked, and each test must report exactly one passing test
without skips. Tool/package availability and actual execution remain CI gates.

The runner creates privileged containers, synthetic serial PTYs and disposable
Docker bridges. It never receives a physical radio, production data or host
credentials. Builds download public source/packages. Tests use only their
synthetic DNS/IPv4 hosts; the upstream Docker networks are not network-none.
The workflow sends no coverage, artifacts or images elsewhere. Source test
hashes and assertions remain visible in the job log. The ephemeral runner owns
all resulting files and networking state.

These tests prove pinned-source virtual-radio behavior, not CPC transport,
released-image ABI, iHost firewall lifecycle, ARM or physical Zigbee coexistence.
The separate exact-vendor build probe covers CPC compile/link compatibility.
PACKET_VERIFICATION=0 disables decoded packet assertions; existing CLI/socket
assertions still run, and system Wireshark tools provide the runner's mandatory
traffic capture. Protocol waits are unchanged (including NAT64's 330-second wait).
Allow up to 60 minutes for cold builds plus real-time tests.

The baseline DNS host shares the infrastructure link. A passing result does not
resolve cross-interface Supervisor DNS routing. The next bounded adaptation can
reuse this three-node topology with a second backbone_network_id and attach the
BR to that DNS bridge, comparing the default interface-bound resolver against
binding disabled. Establish these unchanged baselines before adding that case.

The disposable checkout normalizes one pinned node.py argument: three sysctls
were passed as a single value to Popen. It now passes each through its own
--sysctl option. Intended settings and test assertions remain unchanged; an exact
source-match assertion prevents silently applying this adaptation elsewhere.
