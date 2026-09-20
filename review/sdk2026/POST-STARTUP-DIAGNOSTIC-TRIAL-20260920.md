# Post-startup snapshot trial — 2026-09-20

Status: offline build, packaging, host tests and linked review complete; live access/baseline/staging remain before execution. This is a new experiment, not a replay of the completed lifecycle trial. No production changes have occurred for it.

## Purpose and authority

Distinguish reception, transmit completion and continued processing in the full SDK2026.6.1 firmware. The diagnostic accumulates metadata in RAM, stops permanently at its nominal four-second deadline and emits a fixed metadata report. It is not an operating firmware candidate and must always be replaced by the working original after capture.

The operator's current three-hour authorization covers HA configuration and firmware testing, conservatively12:21–15:21UTC September20. No new approval question is required for a properly prepared experiment within this scope. Preserve a45minute recovery reserve: do not begin writer shutdown later than14:36UTC. If preparation is not complete by then, continue offline work; do not rush or revive expired authority. Restoring a trial already underway remains necessary. No binding/unbinding, erase, bootloader/SE changes, candidate host installation or network/channel changes.

## Artifacts and readiness

- Diagnostic application-only firmware: firmware/post-startup-snapshot/package/post-startup-snapshot-sdk2026-application-only.gbl; SHA25676c560b9a0d78bfa9aa2cc8a5555144971434975859d714ff3cb12da16e8bb12. ELF SHA256955146b29036c1ddde18f25d8db4a23622af584358eb0fa3966aa6deb88ca5de. See evidence/post-startup-preparation-20260920.json and POST-STARTUP-DIAGNOSTIC-REVIEW-20260920.md.
- Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl; SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Host: post-startup-snapshot/capture-launch.py and snapshot.py, using the existing pinned connection-lifecycle adapter and flasher1.1.0/serialx1.10.0. Early version query at250ms, at most two attempts, passive capture to6s,8s post-upload observation bound. No late or reopened query.
- Required: fixed schema/CRC and fragmented raw-capture tests; linked SysTick vector/priority, linked hooks, bounded DMA/UART takeover and original security/network configuration review; independent review of material changes.
- Raw captures/backups contain sensitive state and remain in a new protected run directory outside Git. Retain only fixed allowlisted diagnostic metadata and sanitized result evidence in Git.

## Sequence

Reuse the proven original restoration, backup coverage and staging safeguards in CONNECTION-LIFECYCLE-RESULT-20260920.md. Do not execute its old consumed helper actions.

1. Refresh access, unchanged original app/radio baseline and USB identity, current device availability and maintenance status. Verify immutable tools/artifacts and independent recovery access. Create new event paths. Stage only absent APK package names; assert all original113package versions are unchanged. No whole-cache APK glob.
2. Record downtime at first writer stop. Preserve policies; stop radio/Z2M and briefly Core/Matter for fresh coherent backups of actual Z2M data, HA/Thread, Matter and radio. Verify independent copies/coverage byT+8 or restore unchanged and abort before flashing. Restart Core/Matter, leave radio writers stopped.
3. Require the ordinary original4.6.0 version control, one serial owner. Begin one diagnostic upload byT+10 using the existing vendor flash/reset/baud handling and new capture wrapper. No extra image variant, repeat capture or reopened query.
4. Retain raw capture and decode the fixed report if present. No long analysis during downtime. Missing/invalid output is an inconclusive diagnostic, not a reason for another flash.
5. Begin mandatory original restoration byT+15 regardless of diagnostic outcome. Never interrupt an active upload. Preserve latest host state; do not restore stale backups by default. After the established25second settle, verify original4.6.0 responses, then restart original radio/Z2M and restore policies.
6. Verify network identities/channel25/Thread dataset, representative Zigbee non-actuating level read, ALPSTUGA Identify success and fresh changing reports. Compare against the new baseline (known powered-off/intermittent devices are not automatic regressions). Observe five minutes. Remove temporary tools, verify original package versions and save outcome before further analysis.

Target15–25minutes, reserve45. No reset/binding/erase improvisation if restoration fails; preserve evidence and report required intervention. Previously successful restorations reduce uncertainty but do not guarantee recovery.

## Interpretation

Use POST-STARTUP-DIAGNOSTIC-DESIGN-20260920.md. A valid snapshot may distinguish RX driver/core progress, first TX completion and repeated processing. Capture occurs before terminal takeover. Missing output remains ambiguous because interrupt masking, processor faults, stopped clocks, arming errors or diagnostic transport failure can prevent the report. Instrumentation changes timing/layout; responsive instrumented CPC does not establish that the original problem is fixed. Subsequent actions must follow the new evidence.
