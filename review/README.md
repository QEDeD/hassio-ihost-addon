# Submissions for operator approval

The nine exact product branches are unchanged. This package separates final
submission text from operator references and historical evidence. No new push,
message, PR, image publication or production change occurred during preparation.
The full comparison record remains in [RECONCILIATION.md](../RECONCILIATION.md).

## Exact review set

All contributions target iHost-Open-Source-Project/hassio-ihost-addon. Their final
upstream base is master; dependent diffs below exclude the named prerequisite.
Each local patch is an unmodified `git diff --binary --full-index BASE HEAD`.
Full hashes and source branch names are in the linked draft.

| Contribution | Exact diff head / base | Final text | Route |
| --- | --- | --- | --- |
| Firewall lifecycle | [60d3334](diffs/firewall.patch) / `5a8d7de` | [Text](firewall.md) | New iHost PR; first runtime prerequisite |
| Passive Zigbee readiness | [9536ef0](diffs/readiness.patch) / `5a8d7de` | [Text](readiness.md) | Independent iHost PR |
| Local commissioning QR | [e34faa6](diffs/qr.patch) / `5a8d7de` | [Text](qr.md) | Independent iHost PR; credits OpenThread PR3449 |
| Debian Trixie | [7c3e607](diffs/trixie.patch) / `5a8d7de` | [Text](trixie.md) | Offer corrections to PR79; no competing PR by default |
| NAT64 and upstream DNS | [4ff1642](diffs/nat64.patch) / `60d3334` | [Text](nat64.md) | iHost PR after firewall; coordinate PR78 overlap |
| HA app terminology | [84fab10](diffs/terminology.patch) / `5a8d7de` | [Text](terminology.md) | Independent iHost PR; merge after overlapping text changes |
| Verified build inputs | [836c2f9](diffs/build-inputs.patch) / `7c3e607` | [Text](../followup-evidence/proposed-submissions.md#verify-slc-and-mdns-build-inputs-before-extraction) | iHost follow-up after agreed Trixie corrections |
| Frontend lock enforcement | [12eb1fe](diffs/frontend-lock.patch) / `e34faa6` | [Text](../followup-evidence/proposed-submissions.md#enforce-the-reviewed-frontend-lock-in-the-pinned-sdk) | iHost follow-up after QR |
| Supervisor response validation | [7b9937f](diffs/network-response.patch) / `60d3334` | [Text](../followup-evidence/proposed-submissions.md#reject-invalid-supervisor-network-information-before-choosing-a-fallback) | iHost follow-up after firewall |

## Recommended approval and submission sequence

1. Approve the [PR79 coordination comment](trixie.md#final-submission-text), offering
   only the [Release/mbedTLS corrections](diffs/trixie-corrections.patch) and evidence.
   This does not authorize replacing PR79 or adding build-input changes to it.
2. Approve firewall, passive readiness and QR as independent PRs. Offer the PR78
   coordination text below alongside firewall. Terminology can also be submitted
   independently; prefer merging it after conflicting text changes.
3. Approve publication of the three local follow-up branches and their final text.
   Open dependent PRs after their prerequisites land: NAT64 and Supervisor response
   after firewall, frontend lock after QR, build inputs after the agreed Trixie
   corrections. Recheck the resulting focused diff after adapting to actual merge
   commits; do not silently include prerequisite changes in a master-targeted PR.
4. Decide separately whether to send the [frontend direction question](frontend-direction.md).
   It does not block these nine changes and commits to no framework or maintenance work.

The six original heads are already present on QEDeD/hassio-ihost-addon, verified
by remote ref readback on 2026-09-14. The three follow-up heads and this review
package are local only. Publication approval would cover explicitly selected
branch pushes and submissions; merging, releases and production cutover remain
separate. No approval is inferred from preparation.

## Proposed PR78 coordination text

The firewall and NAT64/DNS work overlaps this proposal. Two focused contributions
are prepared: scoped firewall lifecycle first, then opt-in NAT64 and upstream DNS.
They retain credit to Arno500's proposal. The additions include partial-startup
rollback, bounded shutdown/readiness behavior, pool-conflict checks and isolated
packet/DNS tests. A combined AMD64 production trial also verified a bounded UDP
exchange from a physical Thread plug through NAT64, including a reverse exchange
and a disabled comparison; it does not establish TCP or DNS64 support.

The exact comparisons are [firewall](https://github.com/QEDeD/hassio-ihost-addon/compare/5a8d7dec067f9196ada5879f31f71cbf6d595bff...60d3334daca697a57756b9492cdd6ac6f8f777ec)
and [NAT64/DNS](https://github.com/QEDeD/hassio-ihost-addon/compare/60d3334daca697a57756b9492cdd6ac6f8f777ec...4ff16428e8c8919d2c811f1feb59e07e20e8b766).
Would using the firewall contribution as a prerequisite and incorporating the
focused NAT64/DNS changes here reduce review effort? TREL is outside these changes.

## Readiness, evidence and actual gates

- No identified code defect blocks review of the nine focused diffs. The recorded
  independent reconciliation remains applicable because product heads did not change.
- Original six: individual CI/local evidence is identified in each draft; additional
  physical AMD64 and ARM build evidence belongs to the combined/historical sources,
  not automatically to each individual head. The repeated unrelated bulb history
  has been removed from submission text and remains preserved in INTEGRATION.md.
- Follow-ups: build-input rejection tests, npm/CMake/browser checks and 23 actual
  Bashio/curl/jq consumer cases are local evidence. Combined source 97277e9 passed
  AMD64 build, linkage, graph, runtime fixtures and frontend equality. No later
  ARM build or production trial is claimed. Tests are included in the respective
  branch; CI execution after publication may add evidence but is not already green.
- SLC input pinning requires maintainers to possess the reviewed 5.11 archive or
  intentionally validate an updated pin. The mutable vendor URL is not guaranteed
  to serve those bytes. This is an adoption/build prerequisite, not a hidden claim
  of public binary availability; see BUILDING.md in the build-input diff.
- GitHub may require approval to run workflows from a fork; that is an external
  CI gate after submission. Existing PR/manual workflows do not require personal
  branches to exist upstream. Manual virtual-radio checks are intentionally costly;
  do not rerun them solely because unchanged code has been submitted.
- Prerequisite merges and maintainer coordination govern dependent PR sequencing.
  A partial first wave is useful and does not waive the later contributions.
- [Combined-image adoption trial](../followup-evidence/proposed-submissions.md#proposed-production-validation-not-authorized-or-performed):
  concrete product identity and bounded acceptance/recovery plan are recorded.
  Packaging/provenance adaptation, publication and fresh live preflight remain
  prerequisites before cutover; none blocks reviewing the submitted code.

## Preparation verification

On 2026-09-14, iHost master remains 5a8d7de; open PR78 remains 03598f9 and PR79
4c7d63c. PR92 remains closed/unmerged. No newer PR discussion changes the selected
coordination route. RFC3382 remains open and PR3542 remains open at cfb7d47;
frontend direction is still unsettled. These are read-only refreshes.

Patch exports and base ancestry are checked against Git, not inferred from draft
labels. Preparation changes only review/evidence documents. Existing product and
integration branches are preserved. Any publication should use only the approved
product branches, not this integration/review branch or private raw trial data.

A fresh independent reviewer checked the changed submission framing, all ten
patch exports and their ancestry, all nine branch identities, attribution,
evidence limits, sequencing and trial gates. The review identified an omitted
SLC-archive availability caveat in the final public text; it is now included.
No material findings remain. The reviewer did not repeat product audits,
historical suites, remote-status checks or live access. Parent checks confirmed
current remote refs, linked public evidence, retained combined-build records and
local image identity. No unchanged build or production test was repeated.
