# Fix scoped OTBR firewall lifecycle on HAOS 18

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/otbr-firewall-upstream-20260912`.
Exact head: `60d3334daca697a57756b9492cdd6ac6f8f777ec`. Review base: `5a8d7dec067f9196ada5879f31f71cbf6d595bff`.
[Exact local diff](diffs/firewall.patch). New iHost PR; first runtime prerequisite.

## Final submission text

With ingress filtering disabled, OTBR startup changes the host-wide IPv6 FORWARD policy and invokes ip6tables-legacy, which can prevent startup on HAOS 18. Stale firewall state can also break subsequent starts, and teardown can retry indefinitely.

Use OTBR-owned, wpan0-scoped chains in both filtering modes, preserve host policy, reconcile stale state, roll back partial setup and bound cleanup. Startup ownership checks prevent a refused start from cleaning another implementation's state. This remains a single-OTBR contract, not cross-process exclusion. Keep mDNS running until OTBR shutdown completes through an explicit s6 dependency.

The basic forwarding fix overlaps [Arno500's PR78](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/78). This focused contribution supplies the firewall prerequisite and lifecycle tests; it does not include NAT64, DNS, TREL, base-image or radio-firmware upgrades.

Validation:

- [Historical CI at 27ef047](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34701430704): shell checks, mocked lifecycle cases, isolated kernel rules and released-AMD64 s6 failure/shutdown tests. Kernel checks inspect rules without sending packets; lock contention uses a controlled probe.
- The final mDNS edge passed positive/negative local s6 ordering tests and preserved abnormal-exit reporting. In the [combined AMD64 production trial](https://github.com/QEDeD/hassio-ihost-addon/blob/1ab23561d56a711a1293af45c564d045c4941e02/INTEGRATION.md), OTBR exited 0, cleaned up its firewall and then mDNS stopped.
- Combined-image Zigbee/Matter and NAT64 observations supplement these checks; they are not exact-head CI for this branch. Physical ARM behavior, host-reboot ordering and forced finish expiry during pending readiness remain unverified. The mDNS edge does not establish the cause of the previously observed SIGPIPE.

No local migration or recovery tooling is included.

## Operator notes - do not paste

Ready for approval. New PR rather than reopening closed/unmerged PR92. Existing CI/test scope is retained; no repeat build is justified by this text edit. See README.md for exact publication status and dependent contributions.
