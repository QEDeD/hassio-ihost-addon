# SDK 2026.6.1 upgrade — current execution record

Updated 2026-09-20 after follow-up receive diagnostic and verified recovery. Read this file and the saved goal after compression. Historical reports preserve evidence, not current authority. The full previous record is in [the archive](EXECUTION-HISTORY-THROUGH-LIFECYCLE-20260920.md).

## Objective and continuity

Deliver a maintainable SDK2026.6.1 multiprotocol app and SONOFF ZBDongle-E firmware combination that preserves Zigbee and Thread/Matter membership, passes representative production checks and has an acceptable recovery path. No spare dongle is assumed. Successful rollback is not upgrade completion; running a newer SDK is not proof of improved reliability.

The operator wants execution to continue, not another goal-writing exercise. Their earlier description that the goal was paused was not a pause request. Pause only on an explicit request. A stale blocked/paused goal-service status does not override current instructions; the tools cannot resume it. Reconcile against actual instructions, preserve completed work and do not revive superseded approval questions.

## Authority and limits

- September20 approvals covered the original diagnostic and then the selected follow-up receive diagnostic, each with mandatory original restoration. Both trials are complete and those permissions are consumed. The historical window was14:54–16:24UTC with latest writer stop15:39UTC; it does not authorize another experiment.
- This is not unlimited flashing, binding/unbinding, erasure, bootloader or Secure Engine authority. A new experiment must have a concrete information gain, reviewed artifacts/procedure and a sufficient recovery reserve. Completed trial commands must never be replayed as if unconsumed.
- Only the main agent performs production mutations. Stop the relevant writers, preserve fresh coherent independent backups, use one serial owner and perform the specified restoration. Never interrupt an active upload to meet a deadline or overwrite advanced state with an older backup.
- Offline preparation continues autonomously. Public upstream comments/PR publication retain their separate limits; existing permitted Git pushes and approved registry uploads must not be conflated with unrestricted publication.

## Current checkpoint — follow-up receive trial complete; production restored

The operator's selected `continue` explicitly approved the one receive diagnostic and mandatory original restoration. That sequence completed once and its approval is consumed. Do not replay any helper flash/backup command. No additional trial follows from remaining clock time.

Read [RECEIVE-SNAPSHOT-RESULT-20260920.md](RECEIVE-SNAPSHOT-RESULT-20260920.md) and evidence/receive-snapshot-result-20260920.json. Exact candidate5d2ce0a0de6f2c4e0c0a495f34fc8614862c295877e8367c89ba102551f912dc produced a valid929byte RXS1 record:287756 loops, one TX completion, two RX callbacks, one invalid payload CRC, both receive-transfer resize calls failing their received-byte-count check. No overflow flag at first rejection; overflow appeared later. Terminal hardware destination and software descriptor head disagree. This narrows the defect but does not yet prove its cause.

Original4.6.0 restored15:38:31UTC; original control passed15:38:58. Radio/Z2M restarted15:39:41/47; original settings restored. Radio interruption263.3seconds. Network identities/key/channel25/Thread dataset match. Zigbee read and Matter Identify passed; fresh changing ALPSTUGA reports. All113 original packages match and temporary tools are removed. At15:46:13 after382.8seconds observation all four apps/settings passed, with no newly unavailable radio entities. Two dishwasher controls changed availability as its programme started; logs are not claimed error-free.

Private authoritative events: /home/wsluser/.local/share/ha-recovery/sdk2026-receive-20260920; HA /share/codex-sdk2026-receive-20260920. All event times use WSL UTC; Windows/tool clock differs by about7m45s. Use one clock for durations/deadlines, and refresh clocks before any subsequent window. Temporary remote Python is removed; use documented ha-api/SSH CLI, not helper t.api().

## Current direction and next actions

1. Investigate initial DMA descriptor-load ordering: live LINK/DONEIEN edits immediately follow asynchronous LINKLOAD; initial RAM descriptors have linking disabled. Exact linked full firmware reaches edits faster than passing control. A lost LINK edit could explain hardware/software buffer divergence, but no pre-request register capture proves it. Verify vendor synchronization contract and safe descriptor reuse before proposing a correction; no arbitrary delay/CRC change.
2. Parent owns result, continuity and production. Worker candidate_boot_failure is completing bounded source/contract analysis in RECEIVE-DMA-START-ANALYSIS-20260920.md; no worker builds or live mutations. Other reviews are complete; reuse them.
3. Prepare the smallest evidence-supported correction or distinguishing observation, compile exact target and review material deltas. Request further flashing authority only once its concrete artifacts, information gain and recovery procedure are ready. No repeat startup/component matrix without a new discriminator.
4. Once CPC responsiveness is fixed, return to encrypted binding, network-state compatibility, Zigbee/Thread/Matter checks, persistence and nine-contribution reassessment. No spare/debugger assumed.

Earlier completed trials: POST-STARTUP-RESULT-20260920.md and CONNECTION-LIFECYCLE-RESULT-20260920.md. Their historical findings/approvals must not supersede this checkpoint.

## Evidence and reusable artifacts

- Earlier result: [CONNECTION-LIFECYCLE-RESULT-20260920.md](CONNECTION-LIFECYCLE-RESULT-20260920.md), evidence/connection-lifecycle-result-20260920.json. Reviewed procedure and capture tests are in CONNECTION-LIFECYCLE-TRIAL-20260920.md, CONNECTION-LIFECYCLE-REVIEW-20260920.md and firmware/connection-lifecycle/. Eleven offline tests passed; the physical trial validated launch capture.
- Earlier init trace: STARTUP-TRACE-RESULT-20260920.md; all40 checkpoints completed. BROADER-CPC-ANALYSIS-20260920.md and evidence/startup-comparison-20260920.json establish that the original uninstrumented candidate also transmits its startup frame. RESET_WATCHDOG is also seen on successful controls; it does not establish a new watchdog fault.
- Original candidate: firmware/package/output/rcp-sdk2026-application-only.gbl, SHA256 b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50. Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA256 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Full-image source/config/disassembly: firmware/candidate-clean/. Passing crypto control: firmware/cpc-crypto-diagnostic/. Exact SDK retained in stopped sdk2026-cpc-hfxo-package container. Existing instrumentation and pinned build: firmware/startup-trace/. Do not alter evidence artifacts in place.
- Host/token/DNS/key handling work remains useful: recovery/token-schema/RESULT-20260919.md, recovery/thread-state/README.md, dns-tests/README.md, recovery/CONSUMER-COMPATIBILITY.md, recovery/UPSTREAM-REASSESSMENT-20260919.md. Final published app/recovery identities: evidence/final-images-20260919.json and evidence/published-images-20260919.json. Full integration trial/recovery route: TRIAL-PROCEDURE.md; historical approval scope must be checked before binding.
- Live access follows HA repository docs/runbooks/ha-access-and-dashboard-deploy.md and scripts/ha-unlock --check-access. Remote temporary Python is removed; use ha-api and SSH ha apps CLI. Original package inventory must be preserved when temporarily installing the pinned offline flasher. Never install the entire cached APK glob.
- Scope any new availability claim to its actual baseline. Channel25 migration and phone synchronization are complete. Hardware identification and bootloader evidence are already recorded; do not ask for a label photo again.
