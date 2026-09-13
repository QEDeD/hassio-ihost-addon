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
## Proposed production acceptance (not deployment authorization)

Before approval, identify the deliverable image and its verified delivery route,
confirm the currently installed app/options and establish a fresh stopped-state
backup. Preserve the same local repository app and its evolving data; do not
uninstall, re-pair, flash firmware or restore an older network state.

The proposed baseline trial keeps NAT64 disabled. Capture representative fresh
Zigbee and ALPSTUGA Matter reports before the change, stop the dependent Zigbee
client and app, perform the distinct-version update, and restart them in the
established order. Confirm image/version, service readiness, OTBR attachment and
fresh end-to-end reports rather than relying on process status alone. Exercise a
safe representative read/control where a suitable device is available.

Proposed observation: at least 30 minutes of normal operation, extended if this
fails to include fresh reports from the selected devices. If separately included
in cutover approval, perform one controlled app/client restart and observe fresh
reports for another 10 minutes. These windows test ordinary startup and operation;
they do not establish absence of the previously observed intermittent radio hang.
A passing candidate should remain running only if that is included in approval.

If acceptance fails, stop the trial, retain current data and logs, and use the
baseline wrapper with that same evolved data. Synthetic continuity and fixed
SDK/CPC versions do not prove real radio-state downgrade compatibility. Establish
that recovery limitation explicitly before approval. The OTBR-off recovery image
is only a limited Zigbee fallback, not full Zigbee/Thread recovery.

NAT64 requires a separate enabled/disabled comparison with a Thread consumer that
actually initiates traffic to a controlled IPv4 endpoint. ALPSTUGA sensor reports
alone cannot demonstrate translation. Consumer availability and the specific
permitted traffic remain to be established; do not waive this requirement by
substituting synthetic packet tests for production acceptance.
Delivery review: the installed `local_codex_ihost_otbr_focused` identifier is the
expected local-repository prefix of config slug `codex_ihost_otbr_focused`.
Existing staging uses `/addons/codex_ihost_otbr_focused`, store reload and the
prefixed installed identifier for update. This preserves the same app; no slug
change is needed. The remaining delivery constraint is the integrated base image:
HA cannot resolve a tag held only in WSL Docker. Use a pullable immutable image
(subject to publication permission), or build the combined source on HA. Do not
assume copying a Docker save archive into the build context imports its layers.
## Retained local candidate — 2026-09-13

Clean Linux checkout `2d811ea0b59901570cd5bac64587de53510ac99c` passed the complete
AMD64 build and immutable-image linkage inventory. Base image configuration ID:
`sha256:31b170b2faf9824990d0c582fadf14c9f62c4b593fe1ae07d0789fc763962156`.
Unlike the earlier ephemeral CI image, this image is retained in local Docker.

Helper `391bb7c56e01ef34ae5ae0b8cd259f31fdb7d6d0` built these exact wrappers:
- Candidate: `sha256:97f8753b3f04fc4da59dc732337d8df45971f5a8635711a5c6fd520240d66f09`
- Baseline: `sha256:d9cf8a40c57f667d23052373e2b7f48d19b1965d6d71b657f0cd704d2cac6a46`
- Limited recovery: `sha256:718431866692b4a06c59457ad66209a60808a8d330680db17fb37cf6a48f6cf3`

All three complete installed s6 graphs compiled without starting services.
The exact-image synthetic switch rehearsal passed: evolved radio files and full
options survived candidate/baseline/candidate switches; OTBR-off recovery worked
and OTBR-on recovery was refused. Five stub starts occurred; normal radio init
was never executed. This does not prove real-radio downgrade compatibility.
Candidate runtime/browser acceptance remains pending. No image was published or
deployed. Local evidence is retained under `/tmp/otbr-local-build.1KZZGI`.