# Reconciled contribution package â€” 2026-09-13

## Outcome and current authority

All nine prepared contributions retain justified value for the actual pinned SDK
and iHost base. No product-code change was justified by this reconciliation.
The corrections are contribution framing, attribution, upstream comparisons and
current authority. Nothing was pushed, posted, published or deployed.

This is the current review index. Earlier INTEGRATION.md and FOLLOWUP.md retain
historical test records; their live-state statements describe those observations,
not a new production check. The original branches and tested artifacts are preserved.
The reconciliation branch is codex/otbr-reconciled-20260913, created from ca9feb1.

## Authoritative comparison points

| Source | Exact revision |
| --- | --- |
| iHost master | 5a8d7dec067f9196ada5879f31f71cbf6d595bff |
| OpenThread Border Router main | de6cc2138b5eaaf074b7d2922d81af965e4a07a0 |
| SDK v2024.12.1-0 actually built | da661283f301b53eec04d1016009e60bc7e34a1f |
| CPC v4.6.1 actually built | a15eb6b608497535dd1c3d9bd8871f6a4865c443 |
| Original integrated product | aca557b6eb851af109a2708f55b5b2668314818f |
| Original reviewed bundle | 1ab23561d56a711a1293af45c564d045c4941e02 |
| Latest locally built combined product | 97277e94873999c79056dea8778b0b4c120e85d5 |
| iHost PR78, open | 03598f9b9c739d0293fa434f6899c1fa1efe5f7d |
| iHost PR79, open | 4c7d63cf10ed0cf70f31c64257663c3bdd8b5983 |
| iHost PR92, closed/unmerged | f02d451808e1aaa8a1751c44efc548c586feaae9 |
| OpenThread merged QR PR3449 | ccabba096c3fea00a756ab89ab1537c902e0d7dc |

Full local IDs and the independently repeated eight-package identity comparison
are retained in [source-reconciliation.json](followup-evidence/source-reconciliation.json).
Refs were resolved through authenticated GitHub commit/PR APIs and local Git.
Consequential findings used source/diffs at those refs. Search results located
candidates; closed status alone was not treated as proof of merging. iHost master
and PR78/79 have not changed from the earlier recorded comparison. Current iHost
has only master; current OpenThread branches are main, openwrt, wpantund/master
and a dependency-update branch. RFC-linked activity and identifiable contributor
branches were inspected in the preceding investigation. No absence claim covers
private work or every fork. Public API is preferred over cached raw web results:
the earlier lockfile conclusion based on those results was stale.

## Disposition of each contribution

| Contribution / unchanged head | Actual gap and upstream comparison | Disposition / draft |
| --- | --- | --- |
| Firewall lifecycle 60d3334 | iHost still has the global-policy/legacy-tool and cleanup behavior. PR78 overlaps but does not supply the scoped lifecycle and shutdown evidence. PR92 is unmerged. Newer OpenThread optional nftables/PF implementations do not replace the old SDK's iptables lifecycle. | Retain refined iHost fix; [draft](review/firewall.md). |
| Passive Zigbee readiness 9536ef0 | iHost still checks daemon liveness without confirming its supervised TCP bridge is listening. Core OpenThread cannot establish readiness of this downstream Zigbee service. | Retain; [draft](review/readiness.md). |
| Local QR e34faa6 | Actual SDK still constructs an external HTTP image request. OpenThread already solved external QR generation in PR3449, using the same encoder. Local implementation adds fixed-template binding, quiet zone/sizing, logging/license handling and scoped tests. | Retain SDK-targeted implementation; correct attribution and novelty claims; [draft](review/qr.md). |
| Trixie 7c3e607 | iHost remains Bullseye. PR79 already supplies the base/package changes. Local additions select actual CMake Release mode and backport the attributed mbedTLS GCC correction. | Retain corrections/evidence for PR79 first; avoid duplicate competing upgrade PR; [draft](review/trixie.md). |
| NAT64/upstream DNS 4ff1642 | PR78 supplies useful feature direction but not the same opt-in startup, pool-conflict and scoped firewall behavior. Host-resolver policy is already upstream in OpenThread PR13545 (82eb4863); fixed SDK still needs its narrow adaptation. | Retain refined PR78 subset and explicit policy-backport attribution; [draft](review/nat64.md). |
| HA app terminology 84fab10 | Current iHost retains old user-facing terminology; no replacing terminology PR found. Stable technical identifiers stay intact. Issue routing accepts both old/new form labels. | Retain; note parser compatibility adjustment, not literally text-only; [draft](review/terminology.md). |
| SLC + mDNS inputs 836c2f9 | iHost still overwrites the supplied SLC archive with a mutable download. SDK and current OTBR both disable mDNS certificate checks and lack the reviewed checksum. Current OTBR uses newer mDNS source and download cleanup improvements, not our SDK's selected version. | Retain grouped iHost build-input protection; no automatic mDNS version update. A direct OTBR submission would need adaptation to its selected release; [draft](followup-evidence/proposed-submissions.md). |
| Frontend lock 12eb1fe | SDK omits its stale lock. Current OTBR already copies the updated v3 lock but runs npm install. All eight package versions/URLs/integrities match the local selection. Local v2 lock supports tested npm7, npm ci enforces it, scripts are disabled. | Retain strict installation/compatibility change; remove claim current OTBR ignores its lock; [draft](followup-evidence/proposed-submissions.md). |
| Supervisor response 7b9937f | Current iHost still filters the API response before choosing eth0 fallback; invalid response can look empty. Supervisor is downstream-specific, not an OpenThread API. | Retain separate raw-response validation and valid-no-primary fallback; [draft](followup-evidence/proposed-submissions.md). |

Existing QR code was independently implemented; no literal cherry-pick of PR3449
has occurred. Credit LJspice's upstream resolution explicitly without inventing
code ancestry. Upstream-equivalent functionality can be useful as a downstream
backport, while additional improvements should be described separately.

## Frontend/backend boundary

A new upstream frontend is not a drop-in replacement for this SDK. Current main
uses /api/node, /api/actions, /api/devices and /api/diagnostics, whereas the bundled
frontend uses older /node and /diagnostics routes. Dynamic REST configuration needs
/get_rest_api_info plus web-server changes. The newer ePSKc panel needs additional
web routes and ba ephemeralkey CLI operations, including generate-tap.
The QR change continues using the existing get_qrcode/EUI-64 contract and needs
none of those newer capabilities. Lock enforcement is likewise a build change.

Preserve those boundaries. Do not copy current app.js wholesale, upgrade SDK/CPC/
firmware, or add a compatibility framework to import unrelated newer panels.

## Verification and evidence transfer

The current reconciliation changes documentation only. Product source remains
97277e9. Local Git comparison against that source must show only the listed review
and evidence documents. Consequently a new image build or repeated production
trial would not establish additional behavior from these edits.

Retained records were inspected at /tmp/otbr-followup-build-20260913:
source.json identifies 97277e9 and the unchanged Dockerfile; build-result.json
records exit 0 in 293.929 seconds; graph-result.json records exit 0; runtime-result.txt
records 0; frontend-comparison.json records 21 equal files. The existing local image
was inspected and still has ID
sha256:e88abc3658b2079eb168e7222e9b69b6c633d730e0c917bd8e8d9f2b4911c359.
These are inherited exact-product results, not new builds or production acceptance.
The runtime suite uses isolated service/network fixtures, not physical radio tests.

The latest combined source has AMD64 build/runtime evidence. Earlier physical
Zigbee/Matter/NAT64 and ARM build evidence covers the original bundle and remains
qualified in the historical record. Do not apply that acceptance automatically
to the later Supervisor/build-input/lock follow-ups. If adopting the latter image,
the bounded startup/restart production proposal remains unexecuted and requires
its own approval. No invalid API responses need testing on production.

## Independent review and completion checks

Frontend and runtime comparison workers found no justified product-code correction.
A separate final reviewer is checking the complete disposition and evidence package.
Final review and local commit verification remain pending until recorded below.

## Submission sequence and unresolved decisions

Use the original six plus three follow-up boundaries. Offer Trixie corrections
and evidence to PR79 rather than silently replacing it. Submit firewall before
its NAT64/Supervisor dependents; retain frontend-lock relationship to the QR
adaptation, and build-input relationship to Trixie. Merge terminology where it
causes least textual conflict. Evidence does not require combining all changes
into a single maintainer-facing PR.

AngularJS replacement remains a separately scoped decision. RFC3382 is open;
PR3542 (head cfb7d470a7bba23e4823bf3e31c99d3a73662b56) is an unmerged SSE proposal
using the existing server library, not settled uWebSockets architecture. No public
framework preference was established. [Prepared maintainer discussion](review/frontend-direction.md)
asks only remaining questions. It has not been posted and does not block the
existing contributions. SDK upgrades, TREL, radio-hang work and unrelated HA/network
changes remain outside scope. Publication, maintainer contact and production
changes require operator approval; local reconciliation does not grant it.
