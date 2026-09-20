# Upstream contribution reassessment during full SDK2026 qualification

September20. This supplements the attribution/source comparison in UPSTREAM-REASSESSMENT-20260919.md. No new upstream publication is authorized by the production deployment. Full functional acceptance and controlled app restart passed; see ../FULL-FUNCTIONAL-RESULT-20260920.md.

| Prepared contribution | Current disposition | Evidence / remaining boundary |
|---|---|---|
| Firewall lifecycle | Retain | SDK2026 OTBR starts and existing Matter traffic works. Controlled stop/restart passed; do not claim proof of every firewall scenario. |
| Passive Zigbee readiness | Retain | Same bridge endpoint serves existing Z2M, EZSP19 negotiation and explicit device read pass. No need for a new active readiness probe. |
| Local QR | Retain adapted SDK patch | Vendor frontend still needs credential-local generation per prior source review. Commissioning/QR is not retested merely because network upgrade succeeds. |
| Trixie | Retain SDK build route | Candidate host runs with vendor host binaries. Legacy PR79 coordination stays useful for legacy target. Old mbedTLS workaround remains unnecessary in this successful SDK build, not universally obsolete. |
| NAT64 / upstream DNS | Retain opt-in NAT64 and adapted merged DNS policy | Production NAT64 remains false; ordinary Matter success does not validate NAT64 on new SDK. Existing actual-source DNS tests remain relevant; no unrelated DNS experiment added. |
| HA app terminology | Retain independently | SDK change does not supersede user-facing terminology correction or stable identifiers. |
| SLC / mDNS inputs | Adapted or superseded in candidate | Pinned vendor builder replaces old archive workflow; native OpenThread mDNS removes external daemon/download patch in candidate. Preserve legacy safeguards where original target still needs them. |
| Frontend lock | Retain adapted path | Reproducible npm ci remains useful. Firmware success neither resolves AngularJS advisories nor justifies frontend rewrite. |
| Supervisor response validation | Retain | Downstream Supervisor interface contract still applies, including current candidate normal startup. |

Additional material finding: the CPC no-flow UART initial DMA descriptor correction is necessary for this particular SDK2026/ZBDongle-E build. Its normal application now passes physical CPC query, one encrypted binding, Zigbee request/response and Matter reports/command and controlled app restart. Upstream suitability needs a narrowly scoped vendor issue/patch with attribution and hardware evidence; deployment authority alone does not authorize posting it. Existing broader DMA-stop synchronization limitation is not silently bundled into that correction.

Retained recovery-only firmware still lacks this driver correction and is excluded from this trial. Do not advertise it as a qualified recovery artifact. A future corrected recovery build is a separate narrow preparation item if it materially improves recovery; no speculative repeated firmware exercise is required for this successful normal path.
