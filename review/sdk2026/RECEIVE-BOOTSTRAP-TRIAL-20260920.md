# Receive bootstrap candidate — proposed bounded trial

Status: approved and executed once; diagnostic passed and original production restored. Permission consumed; do not replay. See RECEIVE-BOOTSTRAP-RESULT-20260920.md.

## Question and scope

Does preparing the initial receive descriptor before DMA loads it restore CPC replies and remove the measured buffer-accounting failures? The candidate changes the initial no-flow receive descriptor setup while preserving the tested receive counters and four-second terminal capture. It is a diagnostic that halts, so original firmware restoration is mandatory even if it succeeds.

Candidate: firmware/receive-bootstrap/package/receive-bootstrap-sdk2026-application-only.gbl, SHA2569b88fe804f87897091fee0a140dc68440ea26c170a36cae706ac38245b5dde60. ELF SHA2568b5046f9d4cc7dedaecbdd4a3acd4cf2d57257834ab44164874b9ac049da31bd. Package verification and source identities are recorded in evidence/receive-bootstrap-preparation-20260920.json. Mandatory original remains firmware4.6.0, SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Never substitute a different build under this procedure.

## Ordered execution

Reuse the completed receive-snapshot trial's access, backup, capture and recovery mechanics with fresh paths/events; never rerun its consumed helper actions.

1. Obtain approval for this exact single candidate plus mandatory restoration and a window preserving45minutes for recovery. Reconcile the Windows/WSL clock difference and use one explicit clock for all deadlines. Confirm access, no overlapping maintenance, serial identity, unchanged production baseline, exact artifacts and independent recovery access.
2. Install only absent pinned cached tooling; preserve the original package inventory. At first writer stop, start downtime timing. Stop required writers, capture fresh coherent radio/Matter/HA/actual-Z2M backups and verify independent copies byT+8minutes. Otherwise restore unchanged services without flashing. Restart Core/Matter while keeping radio/Z2M stopped.
3. Require successful original4.6.0 control and one serial owner. Start the single candidate byT+10minutes; run the unchanged version query at250ms with one retry and bounded six-second capture. No additional variants, retries beyond this pair, binding or host-candidate installation.
4. Begin original restoration byT+15minutes regardless of candidate outcome. Never interrupt an active upload to meet a deadline. Keep current host state; do not restore stale archives by default. After the established25second settle, require the original control response before restarting production radio/Z2M and restoring policies.
5. Verify original app settings, network identities/key/channel25/Thread dataset, representative Zigbee read, Matter Identify, fresh sensor reports and baseline-relative availability. Observe five minutes, remove temporary tools, verify original package versions, and save the qualified result.

Expected trial and checks15–25minutes; the previous radio interruption was4m23s, not a guarantee. No erase, unbind, bootloader/Secure Engine, network/channel or credential changes are included. Follow the existing reviewed recovery escalation limits if ordinary restoration fails; do not improvise destructive recovery.

## Decision after capture

Require at least one valid matched CPC version reply from the bounded query operation and matching valid diagnostic build/CRC, with no resize failures or invalid payload checksum, before considering this correction successful in the instrumented image. The host sends one query and retries only if needed; success on the first attempt correctly means no second attempt. A startup announcement alone is insufficient. Inspect any retry and callback/counter states, retaining the possibility of diagnostic timing effects.

Success supports removing the initialization hazard but does not prove that every earlier failure had the same cause. A normal, non-halting firmware build and separately approved functional trial remain necessary before upgrade acceptance. Failure should be classified by the retained counters; do not automatically repeat the flash or expand the component matrix.
