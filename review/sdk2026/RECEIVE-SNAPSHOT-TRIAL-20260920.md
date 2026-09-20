# Proposed receive snapshot trial — September 20, 2026

Status: prepared locally; build/parser/package/independent linked review pass. Not uploaded or flashed. The completed prior one-diagnostic approval is consumed; this is a separate proposed experiment.

## Purpose and exact artifacts

Distinguish first-frame corruption/length mismatch from failed no-flow UART/DMA descriptor recovery. The tested snapshot established continued execution, received-frame checksum rejection and receive overflow, but did not locate where the receive sequence went wrong.

- Candidate: firmware/receive-snapshot/package/receive-snapshot-sdk2026-application-only.gbl, SHA2565d2ce0a0de6f2c4e0c0a495f34fc8614862c295877e8367c89ba102551f912dc.
- Mandatory original: recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787.
- Local bundle SHA25658748d1aca4ae92797c6ac3274f6aa0cd3f25bf0f2e4f75f61d26b779011c566; private root /home/wsluser/.local/share/ha-recovery/sdk2026-receive-20260920. Source, package and staging evidence are in evidence/receive-snapshot-*. Read events before actions; never replay completed commands.

The new image changes only receive metadata instrumentation over the tested terminal snapshot. At nominal4seconds it records101words, takes exclusive UART ownership, emits one929byte record, and halts. It is not operational firmware and must always be replaced. Existing application persistence remains possible; host backups do not constitute a raw dongle-NVM restore.

## Proposed bounded sequence

Reuse the proven POST-STARTUP-DIAGNOSTIC-TRIAL-20260920.md sequence with these exact new artifacts and fresh run paths. Do not rerun its consumed helpers. One candidate upload only; no additional variant/retry or reopened query.

1. Confirm approval/time/access and unchanged live baseline, serial identity, maintenance and independent recovery access. Stage/hash-check the new bundle. Install only absent cached packages and verify all original package versions are preserved.
2. At first writer stop, start downtime clock. Stop required writers, make fresh coherent independent radio/Matter/HA/actual-Z2M backups and verify coverage byT+8; otherwise restore unchanged services without flashing. Restart Core/Matter; keep radio/Z2M stopped.
3. Require working original4.6.0 control and one serial owner. Start candidate byT+10; make the existing250ms version query with one retry and bounded6second capture. No extra commands or long analysis during downtime.
4. Begin mandatory original firmware restoration byT+15 regardless of report. Never interrupt an active upload. Keep latest host state; do not restore older archives by default. Wait the established25seconds and require original4.6.0 responses before restarting radio/Z2M and saved policies.
5. Verify identities/key/channel25/Thread dataset, non-actuating Zigbee level read, ALPSTUGA Identify and fresh reports, app settings and baseline-relative availability. Observe five minutes, remove temporary tools, verify original package inventory and save outcome.

Allow15–25minutes for the sequence and checks, with45minutes reserved for recovery. The preceding diagnostic's radio interruption was4m18s; this is evidence, not a guarantee. If approved within the existing window ending16:24UTC, first writer stop must be by15:39UTC; otherwise a fresh window is required. No extra binding/unbind, erase, host-candidate installation, bootloader/SE or channel/network changes. Missing output or instrumentation-created success is inconclusive and does not justify another flash.

## Interpretation

Use first_bad_seen to qualify first-failure fields; driver_length may include the core oversized-frame clamp. Compare first header/payload IF and first-bad IF to order overflow. Resize outcomes plus scalar recovery state and fixed descriptor metadata distinguish exhausted/spill/deferred-recovery possibilities. Timing and allocation effects remain; this trial cannot alone prove long-term reliability or that the underlying bug is fixed.
