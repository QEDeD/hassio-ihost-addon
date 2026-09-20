# SDK 2026.6.1 upgrade — current execution record

Updated 2026-09-20 after the completed connection-lifecycle trial. Read this file and the saved goal after compression. Historical reports preserve evidence, not current authority. The full previous record is in [the archive](EXECUTION-HISTORY-THROUGH-LIFECYCLE-20260920.md).

## Objective and continuity

Deliver a maintainable SDK2026.6.1 multiprotocol app and SONOFF ZBDongle-E firmware combination that preserves Zigbee and Thread/Matter membership, passes representative production checks and has an acceptable recovery path. No spare dongle is assumed. Successful rollback is not upgrade completion; running a newer SDK is not proof of improved reliability.

The operator wants execution to continue, not another goal-writing exercise. Their earlier description that the goal was paused was not a pause request. Pause only on an explicit request. A stale blocked/paused goal-service status does not override current instructions; the tools cannot resume it. Reconcile against actual instructions, preserve completed work and do not revive superseded approval questions.

## Authority and limits

- Current September20 testing permission covers HA configuration AND dongle firmware, conservatively recorded 12:21–15:21 UTC. Reuse that authority within its scope; no repeated firmware-only approval question.
- This is not unlimited flashing, binding/unbinding, erasure, bootloader or Secure Engine authority. A new experiment must have a concrete information gain, reviewed artifacts/procedure and a sufficient recovery reserve. Completed trial commands must never be replayed as if unconsumed.
- Only the main agent performs production mutations. Stop the relevant writers, preserve fresh coherent independent backups, use one serial owner and perform the specified restoration. Never interrupt an active upload to meet a deadline or overwrite advanced state with an older backup.
- Offline preparation continues autonomously. Public upstream comments/PR publication retain their separate limits; existing permitted Git pushes and approved registry uploads must not be conflated with unrestricted publication.

## Current work - terminal diagnostic prepared, not flashed

Focused review selected a RAM-counter/phase snapshot after four nominal seconds, followed by exclusive terminal UART output and mandatory original restoration. No continuous UART logging or stacked-PC shim. The first build caught nonexistent MG21 CLKEN0 assumptions; exact vendor CONFIG1 ungated-bus evidence corrected them. Final build/package and independent linked review pass, plus14host/4parser tests. ELF955146b29036c1ddde18f25d8db4a23622af584358eb0fa3966aa6deb88ca5de; GBL76c560b9a0d78bfa9aa2cc8a5555144971434975859d714ff3cb12da16e8bb12. Read POST-STARTUP-DIAGNOSTIC-REVIEW-20260920.md and POST-STARTUP-DIAGNOSTIC-TRIAL-20260920.md; exact files are in firmware/post-startup-snapshot/ and evidence/post-startup-preparation-20260920.json.

HA access relocked; passphrase prompt cancelled and operator unlock requested asynchronously. Offline preparation continued. No live configuration, service or firmware changed. Next: after unlock, verify current authority/time, fresh live baseline/maintenance status, stage exact files and execute the prepared new procedure only with recovery reserve. Latest writer-stop start14:36UTC preserves45minutes before permission ends15:21UTC; do not rush or imply late unlock extends authority. Use new private event paths and fresh coherent backups. The remaining investigation is hardware observation, not another broad plan. All source/review agent assignments are complete.

## Latest production checkpoint - lifecycle trial completed; original production restored

September20 operator clarified the current3hour test authorization includes HA configuration and dongle firmware (recorded12:21–15:21UTC). Do not revive the resolved claim that firmware is excluded. The reviewed one-candidate/mandatory-original sequence has now run once; its completed commands must not be replayed. Broader testing remains bounded by actual scope/time/recovery exclusions, not unlimited flashing or binding/erase/bootloader/SE permission.

Original uninstrumented full candidate emitted its valid startup CPC notification~62ms after RUN, but two requests in each phase (0.251s,30.028s and reopened sequence2) received zero bytes. No parser/transport failure. Closing/reopening is not a necessary cause; first250ms query is already unanswered. RX, first TX completion and sustained processing remain unresolved. Stop component/lifecycle repetitions; next useful preparation is retrievable targeted evidence of those paths using existing vendor diagnostics where practical. No proven root cause or speculative fix.

Fresh independent backups verified13:00:42UTC. Candidate once13:01:37–13:02:45. Mandatory original4.6.0 once13:03:37–13:04:34; control queries pass. Radio/Z2M back13:05:29/38, about5m27s after first writer stop. All7 stopped radio archive files unchanged, identities/key/channel25/Thread dataset equal, Zigbee read1 and Matter Identify Success(0), changing ALPSTUGA reports. All original options/policies restored, temporary tools removed13:08:22, all113 original package versions equal. Final13:11:04UTC check after325seconds: no newly unavailable Zigbee/Matter devices; one mobile_app iPhone camera-motion sensor remains unavailable. Prior intermittent dining-table bulb was already offline in baseline. Do not claim all HA entities match.

Read CONNECTION-LIFECYCLE-RESULT-20260920.md and evidence/connection-lifecycle-result-20260920.json. Private authoritative events/logs/backups /home/wsluser/.local/share/ha-recovery/sdk2026-lifecycle-20260920 and HA /share/codex-sdk2026-lifecycle-20260920. Read events before any action. Remote temporary Python removed: t.api no longer works; use documented ha-api and SSH ha apps info --raw-json for current read-only state.

Staging lesson: whole cached APK glob upgraded3 SSH libraries before downtime; standard SSH app restart restored exact original image/packages. Correct installation selects only11 package names absent from apk info, then asserts original-version subset. Cleanup restores113 exactly. Do not repeat the glob. Independent review corrected host parser/loss attribution before execution;11 offline tests passed. No workers currently assigned. SDK upgrade remains incomplete; this trial's recovery is complete.


## Current direction and next actions

The operator asked whether another reflection is useful. The answer is a bounded diagnostic-design review, not a restart of the broad upgrade investigation. The lifecycle hypothesis is now tested; a repeat would add downtime without a new discriminator.

1. Choose a retrievable, low-perturbation diagnostic distinguishing request reception, first transmit completion and sustained firmware processing. Prefer existing SDK counters/hooks. Vendor counters require debugger access; the CPC journal needs an output transport. Neither alone solves retrieval on this dongle. Existing startup UART markers cannot simply be extended into active CPC: they require idle DMA/no pending TX IRQ and clear their own completion flag.
2. Compare practical retrieval alternatives and their blind spots. Do not prescribe a compiler/IRQ/DMA change as a fix without evidence. Source audit has already checked vectors, masks, DMA allocation and UART routing without finding a demonstrated defect; do not repeat it broadly.
3. Implement the chosen narrow diagnostic and reuse the pinned builder, strict application-only packaging, launch capture and mandatory original restoration. Verify observable output and interference/failure handling offline; obtain a fresh focused review before hardware.
4. Execute only when the concrete test is ready within valid authority and enough recovery time remains. Otherwise continue preparation without rushing a flash or pausing the goal. Use new trial paths/event records, fresh baseline/backups and exact artifact identities.
5. Interpret results against passing controls. Once CPC responsiveness is fixed, return to encrypted binding, network-state compatibility, normal Zigbee/Thread/Matter behavior, restart persistence and the nine-contribution reassessment.

Assignments complete: candidate_boot_failure implemented the bounded diagnostic; review_terminal_snapshot independently reviewed design, source and linked artifact. Main agent owns integration and all live actions. No live diagnostic is running. Steps1-3 above are now complete for the first terminal snapshot; proceed from step4 and the current-work checkpoint.

## Evidence and reusable artifacts

- Latest result: [CONNECTION-LIFECYCLE-RESULT-20260920.md](CONNECTION-LIFECYCLE-RESULT-20260920.md), evidence/connection-lifecycle-result-20260920.json. Reviewed procedure and capture tests are in CONNECTION-LIFECYCLE-TRIAL-20260920.md, CONNECTION-LIFECYCLE-REVIEW-20260920.md and firmware/connection-lifecycle/. Eleven offline tests passed; the physical trial validated launch capture.
- Earlier init trace: STARTUP-TRACE-RESULT-20260920.md; all40 checkpoints completed. BROADER-CPC-ANALYSIS-20260920.md and evidence/startup-comparison-20260920.json establish that the original uninstrumented candidate also transmits its startup frame. RESET_WATCHDOG is also seen on successful controls; it does not establish a new watchdog fault.
- Original candidate: firmware/package/output/rcp-sdk2026-application-only.gbl, SHA256 b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50. Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA256 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Full-image source/config/disassembly: firmware/candidate-clean/. Passing crypto control: firmware/cpc-crypto-diagnostic/. Exact SDK retained in stopped sdk2026-cpc-hfxo-package container. Existing instrumentation and pinned build: firmware/startup-trace/. Do not alter evidence artifacts in place.
- Host/token/DNS/key handling work remains useful: recovery/token-schema/RESULT-20260919.md, recovery/thread-state/README.md, dns-tests/README.md, recovery/CONSUMER-COMPATIBILITY.md, recovery/UPSTREAM-REASSESSMENT-20260919.md. Final published app/recovery identities: evidence/final-images-20260919.json and evidence/published-images-20260919.json. Full integration trial/recovery route: TRIAL-PROCEDURE.md; historical approval scope must be checked before binding.
- Live access follows HA repository docs/runbooks/ha-access-and-dashboard-deploy.md and scripts/ha-unlock --check-access. Remote temporary Python is removed; use ha-api and SSH ha apps CLI. Original package inventory must be preserved when temporarily installing the pinned offline flasher. Never install the entire cached APK glob.
- Scope any new availability claim to its actual baseline. Channel25 migration and phone synchronization are complete. Hardware identification and bootloader evidence are already recorded; do not ask for a label photo again.
