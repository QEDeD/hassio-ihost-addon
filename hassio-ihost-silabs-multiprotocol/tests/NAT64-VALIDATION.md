# Optional NAT64 validation

The contribution is default-off and has not been deployed to a physical radio.
The following complementary tests establish different parts of its behavior;
none alone proves a complete production-image or shared-radio deployment.

## Runtime and firewall evidence

[CI 34702234512](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34702234512)
passed at 971e780, including the DNS header change.

- Mock regressions cover all-table pool conflicts, failed inspection, default-route
  allowance, partial rollback, duplicate reconciliation, changed backbone,
  preservation of foreign rules/marks, and the shared IPv4/IPv6 cleanup deadline.
- Isolated kernel tests send actual IPv4 UDP/ICMP packets through the scoped rules
  under FORWARD DROP. They verify masquerading and replies, wrong-source/interface/
  direction rejection, unrelated traffic preservation, overlap refusal and cleanup.
  These are synthetic IPv4 peers, not the OpenThread translator.
- The released AMD64 s6 fixture executes the actual readiness hook and finish path.
  Option on/off and daemon restart apply the expected commands once per incarnation.
  CLI Error text despite exit zero, missing Done and timeouts are separately checked.
  Fatal startup configuration exits the container nonzero without readiness or
  restart, including a daemon ignoring SIGTERM. The fixture stubs radio and CLI
  behavior; it does not prove physical configuration acceptance.

The private otbr-agent/data/check retains socket and REST prerequisites and applies
configuration within eight seconds before readiness. On failure it records the
failure and stops the supervised agent; finish reports permanent failure to release
pending startup before bounded cleanup and shutdown. A three-second kill timeout
bounds ignored SIGTERM. The shared cleanup budget is four seconds. Forced finish
expiry during initial readiness is not covered. No recurring monitor is introduced.

## Compiled translator and DNS evidence

[Pinned vendor probe 34702234482](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34702234482)
passed at 971e780 with the host-DNS header patch. It checks production CMake options with
one intentional installed-CPC path adaptation, effective feature/pool macros,
compile/link and released-runtime loading, native NAT64 tests, and unchanged
CPC/Zigbee hashes. It also proves effective DNS binding zero comes from the header without a
compiler-flag override.

[Virtual-radio baseline 34699696491](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34699696491)
passed the pinned, unmodified upstream DNS and NAT64 tests, including the NAT64
protocol observation waits. These use virtual HDLC radios, not the CPC shared-radio
transport. DNS verifies native AAAA forwarding, not DNS64 synthesis.

The independent interface comparison requires working identical unbound DNS probes
and failed infrastructure-bound probes before comparing actual Thread queries.
Acceptance requires the default binding to reproduce cross-interface failure, the
new binding to resolve it, and both variants to retain same-interface DNS success.
[Comparison 34702011312](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34702011312)
passed all four DNS cells and the unchanged NAT64 baseline. The copied fixture is
reproducible with the manual Pinned OpenThread NAT64 and DNS comparison workflow.
The comparison varies the effective macro through a test-only compiler flag; the
separate vendor probe verifies the production header produces the same setting.

The header policy follows the host-resolver rationale in
[OpenThread PR 13545](https://github.com/openthread/openthread/pull/13545).
The pinned resolver supports IPv4 nameservers, has no RDNSS path, and still requires
an infrastructure interface to exist. This adaptation adds neither IPv6 nameserver
support nor the newer resolver's no-infrastructure-interface behavior.

## Reset and remaining deployment limits

[s6-notifyoncheck](https://skarnet.org/software/s6/s6-notifyoncheck.html) stops checking
after readiness and starts anew for each daemon incarnation. The pinned vendor's
[REST resource](https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/rest/resource.cpp)
uses an in-process reset for DELETE /node. That does not launch another checker.
After an intentional Thread factory reset, restart the add-on to reapply its saved
NAT64/DNS option. No reset monitor is added.

A full add-on image build, ARM compatibility, physical shared-radio NAT64 traffic
and host-reboot ordering remain unverified. Existing successful Matter commissioning
and OTA do not establish this new IPv4 capability. Production acceptance must preserve
current radio state and use a suitable IPv4-only consumer; it is a separate gate
from the isolated evidence above.
