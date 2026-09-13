# Proposed follow-up submissions — local drafts only

These proposals supplement the original six contributions. They have not been
pushed or submitted. Keep the PR79 coordination route; offer the build-input
changes as a separately reviewable follow-up rather than silently enlarging PR79.

## Verify SLC and mDNS build inputs before extraction

Local head: 836c2f9, based on Trixie 7c3e607.

The build copies an SLC archive and then overwrites it from a mutable URL. Its
mDNS bootstrap also disables certificate verification. Retain the reviewed SLC
5.11 archive and verify its checksum before extraction. Fetch the same selected
Apple mDNS release through a pinned commit over verified HTTPS and check its
archive checksum before extraction. Document source provenance and intentional
updates. These content pins are not vendor signatures or full hermetic builds.

Validation includes accepted known bytes, rejected incorrect/missing archives,
certificate failure, HTTP failure and matching source entries between the
selected Apple tag and commit archives. The combined AMD64 build and installed
consumer results belong to the follow-up integration, not exact-head CI here.

## Preserve the tested frontend dependency selection

Local head: 12eb1fe, based on QR e34faa6.

CMake omits the SDK lockfile and resolves dependencies during every build. Add a
reviewed lock matching the validated installed assets, copy both manifest and
lock into the build directory, depend on both, and use npm ci --ignore-scripts.
Keep the local QR encoder and existing browser behavior. This does not remove
all AngularJS advisories; see the separate bounded assessment and limitations.

Tests cover clean CMake installation, lock-only rebuild, invalid/missing/mismatched
locks, npm7/npm9 compatibility and existing QR browser cases. All ten npm assets
match the previous validated selection. Complete frontend equality in the combined
image is additional integration evidence, not a claim of exact-head full-image CI.

## Reject invalid Supervisor network information before choosing a fallback

Local head: 7b9937f, based on firewall 60d3334.

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

## Merge and validation relationship

Keep build inputs, frontend locking and runtime response handling separately
reviewable. Their full combined product source is 97277e9. Dockerfile conflict
resolution preserves all original DNS/QR/mbedTLS patches and both new acquisition
and locking patches. Detailed integration status is in ../FOLLOWUP.md.

## Proposed production validation (not authorized or performed)

Because network-response handling changes startup behavior, an optional approved
follow-up trial should verify the real valid response path, normal start and one
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
The original production deployment remains unchanged.
