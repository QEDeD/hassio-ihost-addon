# Proposed follow-up submissions - local drafts only

These proposals supplement the original six contributions. They have not been
pushed or submitted. Keep the PR79 coordination route; offer the build-input
changes as a separately reviewable follow-up rather than silently enlarging PR79.

## Verify SLC and mDNS build inputs before extraction

Operator reference: destination iHost-Open-Source-Project/hassio-ihost-addon,
master after its prerequisite lands. Source `QEDeD:codex/otbr-build-inputs-20260913`.
Head `836c2f98f1c011b96ed74f5dde0ae22604597260`; review base `7c3e6076e5f84995ac8b881aea4b4f12855a1e10`.
[Exact local diff](../review/diffs/build-inputs.patch). iHost follow-up after agreed Trixie corrections.

### Final submission text

The build copies an SLC archive and then overwrites it from a mutable URL. Its
mDNS bootstrap also disables certificate verification. Retain the reviewed SLC
5.11 archive and verify its checksum before extraction. Fetch the same selected
Apple mDNS release through a pinned commit over verified HTTPS and check its
archive checksum before extraction. Document source provenance and intentional
updates. These content pins are not vendor signatures or full hermetic builds.

Building requires the reviewed SLC 5.11 archive. Its mutable vendor URL may no
longer serve those bytes; a trusted retained copy or deliberately validated pin
update is required. BUILDING.md records the checksum, provenance, update procedure
and Docker regression command. No binary archive or download credential is included.

Validation includes accepted known bytes, rejected incorrect/missing archives,
certificate failure, HTTP failure and matching source entries between the
selected Apple tag and commit archives. The combined AMD64 build and installed
consumer results belong to the follow-up integration, not exact-head CI here.

## Enforce the reviewed frontend lock in the pinned SDK

Operator reference: destination iHost-Open-Source-Project/hassio-ihost-addon,
master after its prerequisite lands. Source `QEDeD:codex/otbr-frontend-inputs-20260913`.
Head `12eb1fe3ed274f209e112837093832cd1f2b14dd`; review base `e34faa674de908f1e208eb71be2f129d7c48636d`.
[Exact local diff](../review/diffs/frontend-lock.patch). iHost follow-up after QR.

### Final submission text

The pinned SDK CMake omits its lockfile when resolving dependencies. Add a
reviewed lock matching the validated installed assets, copy both manifest and
lock into the build directory, depend on both, and use npm ci --ignore-scripts.
[OpenThread PR3449](https://github.com/openthread/ot-br-posix/pull/3449) already copies an updated v3 lock, but still runs
npm install. The distinct additions here are strict npm ci installation,
--ignore-scripts and the v2 format verified with npm7. All eight package versions,
resolved URLs and integrity values match current OpenThread's selection. This builds on LJspice's upstream QR and lock integration while targeting the
older SDK; current OpenThread does not ignore its lock. Local QR/browser behavior
is preserved. This does not remediate the remaining AngularJS advisories.

Tests cover clean CMake installation, lock-only rebuild, invalid/missing/mismatched
locks, npm7/npm9 compatibility and existing QR browser cases. All ten npm assets
match the previous validated selection. Complete frontend equality in the combined
image is additional integration evidence, not a claim of exact-head full-image CI.
The included tests/qr/README.md documents CMake, lock and browser reproduction;
the existing frontend workflow runs the additional lock checks.

## Reject invalid Supervisor network information before choosing a fallback

Operator reference: destination iHost-Open-Source-Project/hassio-ihost-addon,
master after its prerequisite lands. Source `QEDeD:codex/otbr-network-response-20260913`.
Head `7b9937f3aec10bf4f9e2d6a6dc44654cd131be1d`; review base `60d3334daca697a57756b9492cdd6ac6f8f777ec`.
[Exact local diff](../review/diffs/network-response.patch). iHost follow-up after firewall.

### Final submission text

The filtered Bashio API call can report success after JSON parsing fails, leaving
an empty value that selects eth0. Fetch the raw response with explicit failure
handling and validate its structure separately. Preserve first-primary selection
and the deliberate eth0 fallback for a valid empty/no-primary interface list.
Invalid/API-failure responses stop startup rather than select an unintended
backbone. Standalone OTBR's similar code is outside this contribution.

The original malformed-response behavior was reproduced. Twenty-three corrected
consumer cases pass using real released/Trixie Bashio, curl and jq; the existing
lifecycle fixture also passes. These consumer checks stop before full service
startup. No invalid Supervisor responses were injected into production.
The included tests/README.md documents the isolated Docker command for the
23-case consumer test. Local test success is not a claim of exact-head GitHub CI
or completed live startup acceptance for this follow-up.

## Operator notes - do not paste

### Current upstream relationship for build inputs

Current iHost master remains 5a8d7de and PR79 remains open at 4c7d63c. Both still
have the SLC overwrite behavior. OpenThread de6cc213 and SDK da661283 both disable
mDNS TLS certificate verification. OpenThread PR2877 previously improved download
naming/retry/extraction handling, but did not add these certificate/checksum checks.
OpenThread now selects mDNSResponder-2881.40.18; the SDK selects 1790.80.10. This
SDK patch intentionally keeps the latter. Do not submit its release pin unchanged
against current OpenThread or claim a new mDNS version is included.

### Merge and validation relationship

Keep build inputs, frontend locking and runtime response handling separately
reviewable. Their full combined product source is 97277e9. Dockerfile conflict
resolution preserves all original DNS/QR/mbedTLS patches and both new acquisition
and locking patches. Detailed integration status is in ../FOLLOWUP.md.

## Proposed production validation (not authorized or performed)

Purpose: verify the later Supervisor-response change on the real valid startup path,
then confirm that the latest combined image reconnects both Zigbee and Thread/Matter.
Submission review can proceed with the disclosed local evidence; adoption needs this trial.

Exact product source: `97277e94873999c79056dea8778b0b4c120e85d5`.
Local image: `local/otbr-followup:97277e9`, configuration ID
`sha256:e88abc3658b2079eb168e7222e9b69b6c633d730e0c917bd8e8d9f2b4911c359`.
This is not a registry manifest digest or a prepared Supervisor trial package.
The existing trial-package/prepare.sh expects the older audit-record schema and
image alias; do not point it blindly at this follow-up build or fabricate its records.
Before requesting cutover approval, adapt the existing packaging only as needed,
retain this image as the exact base, and verify the resulting wrapper graph and
state-continuity behavior in isolation. Record the wrapper ID and, after separately
approved publication, its registry digest. No wrapper was built or published here.

Expected disruption: two app interruptions (installation/start and one restart),
estimated 1-3 minutes each if normal; allow about 20-30 minutes for the trial and
observation, excluding packaging/publication. These are estimates, not measured
recovery guarantees. Stop and recover if an app cannot reach expected startup and
Thread attachment within three minutes, or representative devices do not recover
within five minutes. Compare with the pre-trial baseline so known unavailable
devices are not misclassified as new regressions.

Capture fresh pre-trial health/options and the actually installed image digest.
Use that verified working image as the first in-place fallback, with current data.
Historical 0.2.3-ordered digest
`sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107`
is a reference only; confirm current state and availability before selecting it.
On failure, preserve logs, stop the trial, restore the verified prior image/options
in the same app with authoritative current state, and start Zigbee2MQTT after the
radio is ready. Repeat representative reads and the observation window. If that
fails, stop further experiments and escalate; do not reset or reflash the radio.
A stale VM snapshot is not the default recovery source for evolved radio state.


Because network-response handling changes startup behavior, the recommended
approved validation before adopting the new image should verify the real valid response path, normal start and one
controlled restart, then fresh representative Zigbee reads and changing Matter
reports over a ten-minute observation window. Keep NAT64 off and existing network
state intact. Do not deliberately corrupt Supervisor responses on production;
the invalid-response cases belong in isolation. Do not repeat commissioning, OTA,
load switching or the entire earlier NAT64 experiment without new evidence.

Before any cutover, prepare and verify the trial packaging and exact image identity,
confirm current access/options and a usable in-place fallback, and preserve fresh
authoritative radio data plus Zigbee2MQTT's external database directory. Old
snapshots or original app volumes are not assumed safe. Restore normal operation
on a material startup/reconnection failure; investigate from preserved evidence.
Image publication and the concrete cutover need their own explicit approvals.
No production state was read or changed during this preparation; earlier deployment statements are historical.
