# SDK 2026.6.1 upgrade — current execution record

Updated 2026-09-20 after successful bootstrap diagnostic and verified recovery. Read this file and the saved goal after compression. Historical reports preserve evidence, not current authority. The full previous record is in [the archive](EXECUTION-HISTORY-THROUGH-LIFECYCLE-20260920.md).

## Objective and continuity

Deliver a maintainable SDK2026.6.1 multiprotocol app and SONOFF ZBDongle-E firmware combination that preserves Zigbee and Thread/Matter membership, passes representative production checks and has an acceptable recovery path. No spare dongle is assumed. Successful rollback is not upgrade completion; running a newer SDK is not proof of improved reliability.

The operator wants execution to continue, not another goal-writing exercise. Their earlier description that the goal was paused was not a pause request. Pause only on an explicit request. A stale blocked/paused goal-service status does not override current instructions; the tools cannot resume it. Reconcile against actual instructions, preserve completed work and do not revive superseded approval questions.

## Authority and limits

- September20 approvals covered the original diagnostic and then the selected follow-up receive diagnostic, each with mandatory original restoration. Both trials are complete and those permissions are consumed. The historical window was14:54–16:24UTC with latest writer stop15:39UTC; it does not authorize another experiment.
- This is not unlimited flashing, binding/unbinding, erasure, bootloader or Secure Engine authority. A new experiment must have a concrete information gain, reviewed artifacts/procedure and a sufficient recovery reserve. Completed trial commands must never be replayed as if unconsumed.
- Only the main agent performs production mutations. Stop the relevant writers, preserve fresh coherent independent backups, use one serial owner and perform the specified restoration. Never interrupt an active upload to meet a deadline or overwrite advanced state with an older backup.
- Offline preparation continues autonomously. Public upstream comments/PR publication retain their separate limits; existing permitted Git pushes and approved registry uploads must not be conflated with unrestricted publication.

## Current checkpoint — corrected diagnostic passed; production restored

Latest selected `go ahead` approved the exact RXB1 bootstrap trial. It completed once; that permission is now consumed. No replay or extra flash is authorized. Read RECEIVE-BOOTSTRAP-RESULT-20260920.md and evidence/receive-bootstrap-result-20260920.json.

Candidate9b88fe804f87897091fee0a140dc68440ea26c170a36cae706ac38245b5dde60 replied4.9.1 on the first query in8.44ms; no retry needed. Valid929byteRXB1 record:289051 loops, two receive callbacks, one validU-frame, two TX completions, resize2OK/0failed, CRCerrors0, no UART overflow. This supports the initial DMA descriptor correction but is not normal-firmware/full-service qualification or a reliability benchmark.

Original4.6.0 restored16:09:41UTC; original control passed16:10:11. Original radio/Z2M restarted16:11:03/12; interruption285.6seconds. Network identities/key/channel25/Thread dataset match. Zigbee read/Matter Identify pass; fresh changing ALPSTUGA reports. All113 original packages restored and temporary tools removed. After333seconds observation at16:16:48, all original app versions/options/policies/running states pass; no newly unavailable radio entities. Two unrelated Home Connect option switches changed availability while dishwasher stayed connected/running. Logs are not error-free.

Private authoritative events/backups: /home/wsluser/.local/share/ha-recovery/sdk2026-bootstrap-20260920; HA /share/codex-sdk2026-bootstrap-20260920. WSL UTC is the event clock; Windows/tool time differs. Temporary remote Python is removed: use ha-api/SSH CLI, not helper t.api().

## Current direction and next actions

The next artifact is normal non-halting full firmware in firmware/receive-fix with only the RXB1-tested bootstrap driver correction. Original app/configuration/security retained; all diagnostic counters/hooks/SysTick/UART takeover removed. Parent exact-target build and4tests pass; independent source/linked review passes in RECEIVE-FIX-REVIEW-20260920.md. Packaging/record closeout is underway; no production staging or flash.

1. Finish normal candidate package evidence and persist/commit it. Update the concrete full functional trial using existing approved recovery work; avoid another diagnostic matrix. New firmware/full-app cutover requires approval of that concrete scope, not reuse of the consumed one-diagnostic approval.
2. Qualify normal CPC replies without instrumentation, encrypted CPC binding, network preservation/normal Zigbee+Thread/Matter operation, discovery, restart persistence and recovery. Existing wider restart synchronization caveats remain until tested.
3. Reassess the nine prepared contributions as the upgrade qualifies; retain SDK2026.6.1 target. No spare/debugger assumed. Parent owns all live mutations; bounded implementation/review workers have finished.

Earlier trials: RECEIVE-SNAPSHOT-RESULT-20260920.md, POST-STARTUP-RESULT-20260920.md and CONNECTION-LIFECYCLE-RESULT-20260920.md. Historical failures/permissions do not supersede this checkpoint.

## Evidence and reusable artifacts

- Earlier result: [CONNECTION-LIFECYCLE-RESULT-20260920.md](CONNECTION-LIFECYCLE-RESULT-20260920.md), evidence/connection-lifecycle-result-20260920.json. Reviewed procedure and capture tests are in CONNECTION-LIFECYCLE-TRIAL-20260920.md, CONNECTION-LIFECYCLE-REVIEW-20260920.md and firmware/connection-lifecycle/. Eleven offline tests passed; the physical trial validated launch capture.
- Earlier init trace: STARTUP-TRACE-RESULT-20260920.md; all40 checkpoints completed. BROADER-CPC-ANALYSIS-20260920.md and evidence/startup-comparison-20260920.json establish that the original uninstrumented candidate also transmits its startup frame. RESET_WATCHDOG is also seen on successful controls; it does not establish a new watchdog fault.
- Original candidate: firmware/package/output/rcp-sdk2026-application-only.gbl, SHA256 b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50. Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA256 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Full-image source/config/disassembly: firmware/candidate-clean/. Passing crypto control: firmware/cpc-crypto-diagnostic/. Exact SDK retained in stopped sdk2026-cpc-hfxo-package container. Existing instrumentation and pinned build: firmware/startup-trace/. Do not alter evidence artifacts in place.
- Host/token/DNS/key handling work remains useful: recovery/token-schema/RESULT-20260919.md, recovery/thread-state/README.md, dns-tests/README.md, recovery/CONSUMER-COMPATIBILITY.md, recovery/UPSTREAM-REASSESSMENT-20260919.md. Final published app/recovery identities: evidence/final-images-20260919.json and evidence/published-images-20260919.json. Full integration trial/recovery route: TRIAL-PROCEDURE.md; historical approval scope must be checked before binding.
- Live access follows HA repository docs/runbooks/ha-access-and-dashboard-deploy.md and scripts/ha-unlock --check-access. Remote temporary Python is removed; use ha-api and SSH ha apps CLI. Original package inventory must be preserved when temporarily installing the pinned offline flasher. Never install the entire cached APK glob.
- Scope any new availability claim to its actual baseline. Channel25 migration and phone synchronization are complete. Hardware identification and bootloader evidence are already recorded; do not ask for a label photo again.
