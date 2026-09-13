# AngularJS options investigation — 2026-09-13

## Outcome and scope

Recommendation: retain the prepared contributions, and evaluate the free maintained
fork before choosing a rewrite. No dependency change, production test, publication,
vendor contact or upstream message was performed. This investigation corrects the
earlier implication that only a paid distribution or rewrite offered a plausible
route. A candidate exists; its suitability is not yet established.

## Investigation performed

1. Reused the ten-advisory assessment and inspected the exact locked frontend.
2. Checked current OpenThread frontend dependencies and searched for replacement work.
3. Compared commercial support, a public fork, migration examples and removal.
4. Inspected a concrete fork fix, regression test, release metadata and CI/build scripts.
5. Compared total maintenance and compatibility costs and defined the next decision test.

The installed frontend has 892 lines of app.js, 435 of index.html and 79 of the join
 dialog (1,406 including comments/whitespace, excluding libraries/CSS). Seven panels
cover status, joining/forming networks, prefix changes, commissioning and topology.
Endpoints include available_network, get_properties, get_qrcode, join_network,
form_network, add_prefix, delete_prefix and commission. Topology additionally uses
explicit HTTP to hostname:8081 for node/diagnostics. Preserve or deliberately resolve
that existing routing behavior; a framework change alone does not fix it. No live
failure or new exploitable Angular path was established in this investigation.

[OpenThread main package.json](https://raw.githubusercontent.com/openthread/ot-br-posix/main/src/web/web-service/frontend/package.json)
still lists AngularJS and Angular Material. The bounded search did not locate a
ready upstream replacement; this is not an exhaustive review of every fork/branch.

## Options

| Path | Benefit | Cost / qualification | Disposition |
| --- | --- | --- | --- |
| Retain current locked assets | No new behavior risk; prepared work proceeds | Known advisories remain; existing bounded reachability assessment is not proof of safety | Interim baseline |
| Free maintained fork | Potential fixes with little application rewriting | Must verify actual delivered patches, modules, browser behavior and maintenance quality | Best next bounded evaluation |
| Commercial maintained distribution | Vendor patch/support relationship; less application rewriting | Recurring cost; public-build access, redistribution and Material coverage need confirmation | Fallback if contractual support is wanted |
| Replace AngularJS with plain JS or a maintained small framework | Removes this legacy framework; simplifies future ownership if well executed | All forms/dialogs/accessibility/error states need parity; topology/QR/API behavior preserved | Longer-term alternative if fork unsuitable |
| Backport selected fixes ourselves | Precise local diff | We become framework patch maintainers and must track future advisories | Only for a demonstrated narrow gap, not default |
| Remove/disable web interface | Stops serving AngularJS if actually disabled | Loses Thread administration/diagnostics; HA feature parity was not established | Only after proving the interface unnecessary |

Plain browser APIs could suit the small page, but require explicit state and
accessible controls. A small maintained framework could reduce that hand-written
logic at the cost of another dependency/build lifecycle. Modern Angular is a
replacement framework, not a version bump of AngularJS. A dual-framework runtime
is unlikely to repay its complexity for this page. Framework selection should
follow a representative prototype and maintainer preference, not popularity.

## Free fork: useful new evidence and limits

[Brickhouse AngularJS fork](https://github.com/brickhouse-tech/angular.js) publishes
@brickhouse-tech/angular-lts. Public npm metadata inspected: latest 1.10.4,
2026-07-28, gitHead 02748f7ec62a75753dcd5ceddd73c61d48e8190b; first package
publication 2026-02-17. Metadata declares MIT and provides integrity and provenance
references. Those references were observed, not cryptographically verified here.

The [SCE patch](https://github.com/brickhouse-tech/angular.js/commit/59df2bacbbd99eb5496adb12a542b516eccc68d7)
changes regex anchoring to group alternatives and includes allowed/denied URL tests.
That is substantive source evidence, not merely an audit-score claim. It does not
prove all ten advisories are fixed in the npm bytes we would deliver.

The [inspected CI](https://github.com/brickhouse-tech/angular.js/blob/02748f7ec62a75753dcd5ceddd73c61d48e8190b/.github/workflows/ci.yml)
builds and checks files/patch markers; it does not explicitly run browser security
regressions. The build script compiles/minifies modules, not those regressions.
README version references are inconsistent with latest metadata. These are reasons
to verify independently, not proof the patches are wrong. Do not equate a renamed
package's clean npm audit with remediation. Core plus animate/aria/messages and
Material interoperability must be checked; merely swapping angular.min.js is not
sufficient evidence. No fork package was installed or executed during this review.

## Commercial alternative

[HeroDevs AngularJS NES](https://www.herodevs.com/support/nes-angularjs) offers a
commercial maintained replacement and an Essentials option covering Angular Material.
The vendor advertises compatibility; it is not our test result. We have not obtained
a quote or confirmed terms permitting our publicly distributed images and anonymous
contributor builds. Those are adoption gates, not an assertion redistribution is
forbidden. Do not use a competing vendor's price comparison as a quote.

## What comparable projects teach us

[Grafana's migration guide](https://grafana.com/developers/plugin-tools/migration-guides/angular-react/)
recommends a separate branch/new plugin skeleton and moving components incrementally.
Its [removal announcement](https://grafana.com/blog/angularjs-support-will-be-removed-in-grafana-12-what-you-need-to-know/)
describes staged deprecation and removal. Applicable lesson: inventory behavior and
provide tested replacements before removal. Grafana's plugin ecosystem and multi-year
transition do not justify copying that scale into this seven-panel interface.

[Portainer release notes](https://docs.portainer.io/release-notes) record individual
screens and sections migrating to React. Applicable lesson: validate by user workflow
and retain backend contracts. They do not establish that React is our optimal choice.

## Next smallest useful action and stopping conditions

A separate scratch evaluation of exact fork 1.10.4:

1. Verify package integrity/provenance and compare delivered core/companion modules
   with the claimed source. Map each relevant advisory to actual changes/tests.
2. Execute the behavioral regressions for relevant fixes on delivered code; verify
   failing controls where feasible. Reject marker-only or audit-name evidence.
3. Substitute only the candidate frontend dependencies in a scratch build. Exercise
   all seven panels with synthetic API responses, including dialog cancellation,
   error recovery, malicious strings, keyboard use and existing QR no-external-request
   cases. Preserve topology/D3 and APIs; do not upgrade unrelated libraries.
4. Compare benefit, compatibility and maintenance confidence. Recommend adoption
   only if evidence supports it; otherwise compare one representative replacement
   screen using plain JS versus a small framework. No production needed at this stage.

Indicative estimates, not commitments: fork evaluation 4–12 agent-hours, 0.5–2 hours
of tool runtime (partly overlapping), 15–30 minutes of operator review. Main uncertainty
is whether delivered modules and security tests are reproducible. Stop early on a
material provenance/coverage defect rather than repairing an entire framework.
A full replacement is roughly 2–5 engineering days plus operator acceptance time;
accessibility, topology and missing full-page tests dominate uncertainty. Vendor or
upstream responses add unbounded external waiting and should not block existing PRs.

No decision or user input is required to understand these findings. Adoption,
commercial commitments or a full rewrite remain separate decisions. The prepared
product at 97277e9 and its test acceptance have not changed.
