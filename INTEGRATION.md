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
Combined AMD64 isolated validation passed as recorded below; production acceptance remains pending. Earlier individual
CI runs are evidence for their specified commits/environments only. Synthetic
fixtures substitute services and do not prove real-radio startup. The QR browser
fixture verifies installed assets with synthetic endpoint data. Virtual-radio
NAT64 tests build a separate SDK environment; they are not combined-image tests.
The radio-hang investigation is parked unless recurrence affects this trial.

Production recovery must not rely on the obsolete original app volume or an old
VM snapshot. Raw live logs and credentials remain private and outside this branch.
## Execution status and trial recovery review

At source0999946, local merged firewall/NAT64 lifecycle and all five pool tests
passed. Separate firewall run34747387027 and QR run34747387037 passed; these
retain their documented fixture boundaries. Combined AMD64 run34747387036 passed. ARM run34747479789 uses e28c7aa: product source is identical, with only
ARM build timeout changed from1200 to2700 seconds (job bound85 minutes).
Do not restart either run simply because log observation is unchanged.

Read-only independent review of the existing local-service packaging found:
- Keep the same local app slug, source directory, full options and evolving /data;
  no new app or seed import. Use a distinct-version stopped-app update.
- Existing make_context.py pins the old release plus exactly five overlay files.
  It cannot package the integrated image unchanged; preserve those identity
  safeguards and extend packaging narrowly for the verified combined artifact.
- Retain the local state guard, start/provenance markers and disabled automatic
  discovery. Both candidate and recovery schemas must preserve all existing
  local options and accept otbr_nat64, explicitly false for the initial trial.
- Adapt the existing synthetic same-volume image-switch check to exact candidate
  and recovery images. It must preserve evolving files/nondefault options.
  Stub-init success is not physical-radio or counter-compatibility evidence.
- Existing recovery enforces OTBR off and restores released Zigbee binaries.
  This is a limited Zigbee recovery route, NOT verified full Thread/Matter rollback.
  Resolve the operational rollback scope before cutover approval; do not silently
  substitute Zigbee-only recovery for preservation of both services.
- Generic Supervisor stopped-update/options-persistence evidence already exists;
  reuse it. Verify the actual packaged images and availability on HA, current full
  options, fresh stopped-state backup and exact installed image/version at cutover.
- Keep current state even after trial failure. Never restore the stale original
  app volume or pre-commissioning snapshot. The state guard checks file safety,
  not semantic integrity or monotonic counters. Fixed SDK/CPC versions reduce
  compatibility uncertainty but do not prove downgrade safety.

Before asking for approval, specify the interruption window, exact candidate,
state-preserving recovery actions, normal-operation acceptance, controlled restart
if included, and whether a passing candidate remains running. NAT64 enablement
is a separate test; production deployment and firmware/reset actions are not
implied by this preparation record.
## Combined AMD64 acceptance — completed

Run [34747387036](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34747387036)
at0999946 passed the complete AMD64 build and all isolated checks. Captured local
image ID: sha256:30343d24dfd79334fb3aa326d425b7cea31061af1b23395156727f73c5d285be.
This is the Docker image configuration identity, not a published registry digest.
The runner did not export or publish the image; deployable artifact packaging and
retention remain required. The audit image also retains one test-only config.py.
Do not claim an untested rebuild/wrapper is the identical tested artifact.

The log confirms FIXTURE_SOURCE=current at the exact source head. Tests passed
for merged firewall/NAT64 source behavior, isolated kernel rules and IPv4 packet
forwarding, s6 lifecycle/readiness, socket ownership, actual Bashio and native web.
Controller and browser tests used frontend extracted from the built image: four
viewport/credential-length combinations decoded correctly, hostile text stayed
data, two encoder-failure paths were checked and seven synthetic QR requests made
zero external request attempts. No real radio or production operation was tested.

Local-service fixture preparation d5c156e now requires explicit immutable local
candidate/baseline/recovery image IDs, checks candidate -> baseline -> candidate
with evolved synthetic state and OTBR enabled after first guarded handoff, and
separately checks OTBR-off recovery plus refusal with OTBR enabled. Parent reviewed
the diff. Syntax/argument and mocked-transport checks passed; exact-image container
execution remains pending. Stub-init continuity cannot prove radio counter or
serialized-state compatibility. No production rollback guarantee is claimed.