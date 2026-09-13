# Add opt-in NAT64 and host upstream DNS

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/otbr-nat64-feature-20260912`.
Exact head: `4ff16428e8c8919d2c811f1feb59e07e20e8b766`. Review base: `60d3334daca697a57756b9492cdd6ac6f8f777ec`.
[Exact local diff](diffs/nat64.patch). iHost PR after firewall; coordinate PR78 overlap.

## Final submission text

Add `otbr_nat64`, disabled by default, so compatible Thread clients can reach IPv4 services and forward DNS queries upstream. Ordinary local Matter operation does not require it. The setting is independent of ingress filtering.

This follows the NAT64/DNS direction in [Arno500's PR78](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/78), with the scoped firewall lifecycle as a prerequisite. TREL and unrelated build changes are excluded.

- Reserve 192.168.255.0/24 and reject overlapping interface networks or nondefault routes in any routing table before startup. This cannot detect conflicts introduced later.
- Scope forwarding and masquerading to the Thread interface, pool and selected backbone, permitting established/related return traffic. Preserve unrelated rules, marks and global policies; reconcile owned state on restart or disable.
- Apply the option before readiness, once per agent incarnation. Require CLI Done and reject Error output even with exit zero; failed/timed-out configuration stops startup. Configuration, termination and cleanup are bounded.
- Adapt the host-resolver routing policy accepted in [OpenThread PR13545](https://github.com/openthread/openthread/pull/13545) to the pinned SDK. The old resolver still supports IPv4 nameservers only and has no RDNSS path.

This is not a general DNS64 server: clients must synthesize IPv6 destinations from the advertised NAT64 prefix. After an in-process Thread factory reset, restart the app to reapply the saved option.

Validation includes [historical runtime CI](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34703190978), [vendor configuration/build checks](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34703190972) and a [four-cell DNS interface comparison](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34702011312). These distinguish mocks, isolated IPv4 kernel packet tests, released-s6 fixtures and pinned virtual-radio behavior. Reproducible checks and their exact limits are included in tests/NAT64-VALIDATION.md and the test READMEs.

A separate [combined AMD64 production trial](https://github.com/QEDeD/hassio-ihost-addon/blob/1ab23561d56a711a1293af45c564d045c4941e02/INTEGRATION.md) used a physical Thread plug: a correlated UDP rejection reached an IPv4 collector through NAT64 and a reverse request received a second correlated rejection. Disabling NAT64 on the same candidate stopped that IPv4 response while ordinary IPv6 remained functional. This verifies the bounded UDP exchange, not DNS64, TCP or general Internet access. NAT64 was left disabled.

The combined image evidence is not exact-head CI for this individual branch. Physical ARM radio behavior, host-reboot ordering and forced finish expiry during pending readiness remain unverified. No local trial/recovery tooling is included.

## Operator notes - do not paste

Ready for review against firewall 60d3334; do not open a master-targeted PR containing that prerequisite as if it were NAT64-only. Prefer opening after firewall lands, then resolve the base with a focused diff check. PR78 coordination text is in README.md. Do not claim the UDP test demonstrates arbitrary application traffic.
