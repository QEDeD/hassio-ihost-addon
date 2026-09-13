# Integrated contribution candidate

## Goal and boundaries
Prepare one combined image for isolated validation and an explicitly approved
production trial, while retaining separate upstream PRs. This integration branch
is not an upstream PR or a release. No production deployment is authorized by
this document. The current local app's radio state remains authoritative.

## Source set — 2026-09-13
Upstream master: 5a8d7dec067f9196ada5879f31f71cbf6d595bff.
Fresh upstream branch listing contains master only. Open overlapping PRs remain
78 (03598f9b9c739d0293fa434f6899c1fa1efe5f7d) and
79 (4c7d63cf10ed0cf70f31c64257663c3bdd8b5983). Existing attribution to
Arno500 is retained in the contributions. No upstream submission has occurred.

| Contribution | Integrated source head | Relationship |
| --- | --- | --- |
| Scoped firewall lifecycle | d16cfdf | Independent prerequisite for NAT64 |
| Passive Zigbee TCP readiness | 9536ef0 | Independent |
| Local QR generation | 4969de6 | Independent; no external credential service |
| Debian Trixie and Release compilation | fe47277 | Base/runtime upgrade; SDK and CPC held fixed |
| NAT64/upstream DNS | 8cb2ff9 | Stacked on firewall; default remains disabled |
| HA app terminology | 84fab10 | Shared wording; technical identifiers preserved |

Merge resolutions retained both DNS and QR Dockerfile patch installation steps
and the full NAT64 documentation. Individual contribution branches are unchanged.

## Acceptance sequence
1. Build the combined AMD64 source, record exact commit/image identity and check
   installed linkage. Reuse pinned acquisition checks for the base, SDK, CPC, SLC.
2. Run lifecycle/readiness/firewall/IPv4 packet fixtures using current integrated
   source and the combined runtime, not older contribution checkouts. Exercise
   native web behavior and QR assets extracted from the combined image.
3. Complete architecture-specific ARM image/runtime validation separately. The
   prior isolated Release compiler test is not full ARM acceptance.
4. Review a concrete persistent-app deployment/recovery package preserving
   current state, including state evolved during trial; obtain cutover approval.
5. Trial existing Zigbee/Matter operation with NAT64 disabled, then separately
   validate enabled NAT64 with an appropriate consumer under agreed permissions.
6. Feed findings into individual PR branches, reassemble and retest affected
   behavior, obtain independent final review, and present the complete PR bundle.

## Evidence limitations
No integrated build or production acceptance is yet claimed. Earlier individual
CI runs are evidence for their specified commits/environments only. Synthetic
fixtures substitute services and do not prove real-radio startup. The QR browser
fixture verifies installed assets with synthetic endpoint data. Virtual-radio
NAT64 tests build a separate SDK environment; they are not combined-image tests.
The radio-hang investigation is parked unless recurrence affects this trial.

Production recovery must not rely on the obsolete original app volume or an old
VM snapshot. Raw live logs and credentials remain private and outside this branch.