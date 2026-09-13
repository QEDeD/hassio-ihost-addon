# Fix scoped OTBR firewall lifecycle on HAOS 18

Head: QEDeD:codex/otbr-firewall-upstream-20260912 at 60d3334daca697a57756b9492cdd6ac6f8f777ec

[Exact comparison](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/compare/5a8d7dec067f9196ada5879f31f71cbf6d595bff...QEDeD:60d3334daca697a57756b9492cdd6ac6f8f777ec)

### PR body

With OTBR ingress filtering disabled, startup changes the host-wide IPv6 FORWARD policy and invokes ip6tables-legacy, which can prevent startup on HAOS 18. Stale firewall state can also break subsequent starts, while the existing teardown can retry indefinitely.

Create OTBR-owned, wpan0-scoped forwarding chains in both modes while preserving the host policy and existing ingress filtering semantics. Reconcile stale state before startup, roll back partial setup, and bound teardown. An existing-wpan0 guard and startup/finish bookkeeping prevent a refused startup from cleaning another implementation's state. This remains a single-OTBR contract, not cross-process exclusion.

The basic scoped-forwarding change overlaps Arno500's [PR #78](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/78). This focused contribution can serve as its firewall prerequisite, adding lifecycle verification while leaving NAT64, DNS and TREL to separate work. It does not change the binary versions, base image or radio firmware.

Validation:

- [CI at implementation head 27ef047](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34701430704) passed syntax/ShellCheck, mocked lifecycle regressions, isolated kernel rule checks, and released-image s6 shutdown tests.
- Kernel checks verify installation, ordering, cleanup and preservation of unrelated rules under a restrictive policy; they do not send packets. The lock scenario uses a controlled probe rather than native nft contention.
- Released AMD64 s6 tests retain the daemon failure result and prevent restart through cleanup failure, command stall and forced finish expiry after service startup. The expiry fixture enlarges global shutdown grace; it does not prove default-grace timing or forced expiry during pending readiness.
- An earlier overlay implementing the same firewall behavior ran with released binaries on AMD64 HAOS 18.2: filtering-enabled Thread, a controlled same-volume restart, Matter commissioning/OTA and subsequent sensor reports, alongside successful Zigbee reads. This predates the final helper refactors. OTA logs included radio retries and temporary subscription recovery.

Current head 60d3334daca697a57756b9492cdd6ac6f8f777ec additionally keeps mDNS running until OTBR shutdown completes. Positive/negative local s6 ordering tests passed while preserving abnormal-exit reporting; this does not prove the observed production SIGPIPE cause. The [integration evidence](../INTEGRATION.md) records the exact combined image, successful AMD64 production observation/restart and NAT64 UDP comparison, and separately scoped ARM build/linkage/native-web results. The approved group-command replay did not reproduce BUSY; independent review retains the historical finding as unresolved general Zigbee reliability work, without evidence requiring another candidate/baseline switch. These results are not exact-head CI for this individual contribution, physical ARM radio acceptance, or a claim that historical device failures are fixed.

The final scripts were deployed in integration aca557b (image 0.2.3-ordered): the controlled restart recorded OTBR exit 0, firewall cleanup, then mDNS shutdown. This does not establish the original SIGPIPE cause. Host-reboot ordering remains unverified. No local migration/recovery tooling is included.
