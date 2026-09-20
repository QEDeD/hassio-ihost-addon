# Proposed connection-lifecycle diagnostic — 2026-09-20

**Approved and executed once September20:** Diagnostic received no replies in any phase; original production restored and closeout verified. See CONNECTION-LIFECYCLE-RESULT-20260920.md. This procedure is retained evidence, not an instruction to repeat.

**Approval history:** operator clarified the current3hour permission covers HA configuration and firmware flashing. Execute this reviewed sequence once with mandatory restoration. The preparation-only wording below is historical, not a remaining approval gate.

## Authority and objective

Operator approved investigation and HA configuration testing for three hours, recorded from12:21UTC through15:21UTC on September20. This is preparation authority, including relevant bounded HA configuration checks; it is not interpreted as lifting the expressly retained firmware-flashing approval boundary. No new upload/reset/service stop has occurred. Obtain approval of this concrete single-window procedure before flashing. No spare assumed.

Distinguish immediate CPC responsiveness, responsiveness after30seconds on the same connection, and responsiveness after closing/reopening. Reuse existing uninstrumented full SDK firmware; mandatory original firmware restoration follows regardless of outcome. No candidate host, binding/unbind, network command, channel change, clock tuning, bootloader/SE update, erase, extra firmware variant or additional diagnostic cycle.

## Exact artifacts

Paths relative to review/sdk2026:

- Candidate `firmware/package/output/rcp-sdk2026-application-only.gbl`, SHA256 `b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50`.
- Mandatory original `recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl`, SHA256 `40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787`.
- Adapter `firmware/connection-lifecycle/{lifecycle.py,capture-launch.py,probe-reopened.py}`; exact hashes in `evidence/connection-lifecycle-preparation-20260920.json`.
- Existing pinned flasher1.1.0/serialx1.10.0 offline bundle and original app0.2.3-ordered options/image. No firmware rebuild.

## Ordered procedure and limits

Reuse backup coverage, ownership controls, ordinary flash arguments and cleanup from STARTUP-TRACE-TRIAL-20260920.md, with the following complete sequence. Historical approvals for earlier image sequences remain consumed.

1. Refresh access, app/firmware baseline, known USB by-id, device availability, maintenance coordination, tool/image hashes and independent recovery access. Stage reviewed files under a fresh protected run directory, preserve original113-package inventory and app policies, and verify adapter source guards with --help. No secrets in Git.
2. Start downtime record when first writer stops. Apply established manual-boot/watchdog protections, stop radio/Z2M; briefly stop Core/Matter for coherent backups covering actual Z2M data, HA/Thread, Matter and radio state. Verify independent copies and coverage byT+8, otherwise abort before flash and restore original services/policies. Restart Core/Matter; keep radio writers stopped.
3. Require ordinary old4.6.0 CPC version control before candidate upload. Failure aborts the candidate window. Use one owner and no concurrent reader.
4. Begin exactly one candidate upload byT+10 using established vendor flash/reset/baud/DEBUG arguments, replacing only its CLI entry point with the reviewed capture-launch.py. Observe query0 early and query1 at30s without closing. No long analysis during downtime. A failed upload/capture or uncertain ownership proceeds to original restoration; do not repeat.
5. After successful CLI exit/release, run probe-reopened.py once against the same by-id. Query2 has at most two attempts. Skip if recovery time is tight. Record raw byte evidence and structured phase results; no binding even if every query succeeds.
6. Begin mandatory original4.6.0 upload byT+15, using unmodified pinned flasher. Never interrupt an active upload to meet a deadline. Preserve latest stopped host stores if it does not delay rollback; never replace them with stale backups. After established25s settling, require original version responses, then restart unchanged original radio/Z2M and policies.
7. Verify preserved identities/channel25/Thread dataset, non-actuating Zigbee level read, ALPSTUGA Identify15s result and fresh changing reports. Compare availability; permit one non-actuating read of a newly unavailable device under prior closeout practice. Observe five minutes. Remove temporary tools and verify every original package version. Persist evidence and execution record before closeout.

Target15–25minutes; reserve45minutes. If the approved3hour configuration-testing window expires, do not begin a new mutation or trial; restoring an already started test to the approved baseline remains necessary. If rollback fails, preserve evidence and stop beyond-scope changes; physical intervention or replacement could be needed. Earlier repeated successful restoration reduces uncertainty but does not guarantee recovery or replace a spare. No unbounded retries, erase or extra reset experiment.

## Interpreting results

- Early reply then pre-close silence: time-dependent behavior under these queries.
- Pre-close reply then reopened silence: transition-related behavior; line effects versus host transport effects still need discrimination.
- Silence at all phases: focus RX arrival, TX completion and continued processing; no proof which failed.
- Only later replies: delayed readiness is possible.
- Replies throughout: original failure not reproduced; queries themselves change activity, so do not claim a fix or authorize further integration.

The early query changes the previously idle interval. The test cannot prove behavior of a completely passive startup, nor independently measure electrical lines or interrupt delivery. Existing historical passive captures remain controls; no extra flash cycle is added to manufacture a perfect counterfactual.
