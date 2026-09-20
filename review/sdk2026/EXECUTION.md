# SDK 2026.6.1 upgrade — current execution record

Updated 2026-09-20 after local post-startup diagnostic staging. Read this file and the saved goal after compression. Historical reports preserve evidence, not current authority. The full previous record is in [the archive](EXECUTION-HISTORY-THROUGH-LIFECYCLE-20260920.md).

## Objective and continuity

Deliver a maintainable SDK2026.6.1 multiprotocol app and SONOFF ZBDongle-E firmware combination that preserves Zigbee and Thread/Matter membership, passes representative production checks and has an acceptable recovery path. No spare dongle is assumed. Successful rollback is not upgrade completion; running a newer SDK is not proof of improved reliability.

The operator wants execution to continue, not another goal-writing exercise. Their earlier description that the goal was paused was not a pause request. Pause only on an explicit request. A stale blocked/paused goal-service status does not override current instructions; the tools cannot resume it. Reconcile against actual instructions, preserve completed work and do not revive superseded approval questions.

## Authority and limits

- Fresh September20 operator approval “unlocked; window approved” covers this single prepared diagnostic and mandatory original restoration. Conservative window14:54–16:24UTC; latest writer stop15:39UTC preserves45minutes recovery. This supersedes the prior12:21–15:21 window. Reuse that authority within its scope; no repeated firmware-only approval question.
- This is not unlimited flashing, binding/unbinding, erasure, bootloader or Secure Engine authority. A new experiment must have a concrete information gain, reviewed artifacts/procedure and a sufficient recovery reserve. Completed trial commands must never be replayed as if unconsumed.
- Only the main agent performs production mutations. Stop the relevant writers, preserve fresh coherent independent backups, use one serial owner and perform the specified restoration. Never interrupt an active upload to meet a deadline or overwrite advanced state with an older backup.
- Offline preparation continues autonomously. Public upstream comments/PR publication retain their separate limits; existing permitted Git pushes and approved registry uploads must not be conflated with unrestricted publication.

## Current work — diagnostic complete; original production restored

The approved one-diagnostic sequence was executed once; its permission is consumed. No additional firmware trial is implied by remaining clock time. Read POST-STARTUP-RESULT-20260920.md and evidence/post-startup-result-20260920.json. Do not replay helper backup/flash actions. The new report supersedes the completed lifecycle checkpoint as current production evidence.

Valid659byte terminal snapshot:299611 completed loops, one completed TX/IRQ, two completed RX callbacks, one received frame rejected for invalid payload checksum. Host request CRCs/length are independently valid; identical query succeeds on original4.6.0 before/after. UART snapshot also records RX overflow/full/data pending. This directs investigation toward receive buffering/DMA handoff rather than a general startup hang. Exact defect and corrective change remain unproved; phase=CPC_ENTER is only a sample.

Original4.6.0 restored15:07:30; both original control replies passed15:08:00. Radio/Z2M started15:08:32/44 (radio interruption257.2seconds), policies restored. Fresh stopped backup identities/key/channel25/Thread dataset match; Zigbee read1, Matter Identify Success, fresh changing ALPSTUGA reports. Temporary tools removed and all113 original package versions equal. At15:13:46UTC after302seconds observation: no newly unavailable HA entities, original four app versions/options/policies verified. No stale host state restored; no binding/erase/bootloader/SE changes.

Private authoritative paths: /home/wsluser/.local/share/ha-recovery/sdk2026-poststartup-20260920 and HA /share/codex-sdk2026-poststartup-20260920. Events govern replay safety. Remote temporary Python is removed: use documented ha-api/SSH ha apps CLI, not helper t.api(). The current staging helper files are consumed. The older lifecycle checkpoint remains in CONNECTION-LIFECYCLE-RESULT-20260920.md.

## Current direction and next actions

The terminal diagnostic delivered the needed discriminator and recovery is complete. Parent owns result/continuity and build/review. Focused source comparison is complete in POST-STARTUP-RECEIVE-ANALYSIS-20260920.md. candidate_boot_failure is implementing a narrow receive diagnostic in a new firmware/receive-snapshot directory, preserving the tested prior artifact. No worker may access the live radio and no additional live trial is authorized.

1. Resolve what the retained USART/DMA state and invalid-payload count imply, compare exact receive descriptor/handoff behavior with passing controls, and check relevant vendor work. Reuse the independent host CRC verification. Do not assume shared hardware CRC: the inspected path uses software CRC.
2. Choose the smallest evidence-supported correction or additional observation. A malformed host query, total startup hang and missing first TX completion no longer fit this instrumented result. Receiver-buffer corruption, dropped bytes/descriptor handoff and validation-input errors remain candidates; do not claim an identified root cause.
3. Compile exact target early, review material deltas, preserve original recovery/capture evidence, and avoid speculative firmware matrices. Any further flash needs a concrete new test approval; the one-diagnostic approval is consumed.
4. Once CPC responsiveness is fixed, return to encrypted binding, network-state compatibility, normal Zigbee/Thread/Matter behavior, restart persistence and the nine-contribution reassessment. No spare/debugger is assumed.

## Evidence and reusable artifacts

- Latest result: [CONNECTION-LIFECYCLE-RESULT-20260920.md](CONNECTION-LIFECYCLE-RESULT-20260920.md), evidence/connection-lifecycle-result-20260920.json. Reviewed procedure and capture tests are in CONNECTION-LIFECYCLE-TRIAL-20260920.md, CONNECTION-LIFECYCLE-REVIEW-20260920.md and firmware/connection-lifecycle/. Eleven offline tests passed; the physical trial validated launch capture.
- Earlier init trace: STARTUP-TRACE-RESULT-20260920.md; all40 checkpoints completed. BROADER-CPC-ANALYSIS-20260920.md and evidence/startup-comparison-20260920.json establish that the original uninstrumented candidate also transmits its startup frame. RESET_WATCHDOG is also seen on successful controls; it does not establish a new watchdog fault.
- Original candidate: firmware/package/output/rcp-sdk2026-application-only.gbl, SHA256 b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50. Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA256 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Full-image source/config/disassembly: firmware/candidate-clean/. Passing crypto control: firmware/cpc-crypto-diagnostic/. Exact SDK retained in stopped sdk2026-cpc-hfxo-package container. Existing instrumentation and pinned build: firmware/startup-trace/. Do not alter evidence artifacts in place.
- Host/token/DNS/key handling work remains useful: recovery/token-schema/RESULT-20260919.md, recovery/thread-state/README.md, dns-tests/README.md, recovery/CONSUMER-COMPATIBILITY.md, recovery/UPSTREAM-REASSESSMENT-20260919.md. Final published app/recovery identities: evidence/final-images-20260919.json and evidence/published-images-20260919.json. Full integration trial/recovery route: TRIAL-PROCEDURE.md; historical approval scope must be checked before binding.
- Live access follows HA repository docs/runbooks/ha-access-and-dashboard-deploy.md and scripts/ha-unlock --check-access. Remote temporary Python is removed; use ha-api and SSH ha apps CLI. Original package inventory must be preserved when temporarily installing the pinned offline flasher. Never install the entire cached APK glob.
- Scope any new availability claim to its actual baseline. Channel25 migration and phone synchronization are complete. Hardware identification and bootloader evidence are already recorded; do not ask for a label photo again.
