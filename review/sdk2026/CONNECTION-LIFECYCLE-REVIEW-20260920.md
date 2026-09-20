# Connection-lifecycle preparation review — 2026-09-20

## Bounded binary/source audit

The original full and passing crypto binaries both map USART0 TX IRQ12 and LDMA IRQ21 to actual handlers. Full vector values0xC731/0x1389B; control0x6C65/0xDF7D. Both start interrupt priority5 (0x50) and atomic BASEPRI0x30, with prior mask restored. Source: platform_core/platform/service/interrupt_manager/src/sl_interrupt_manager_cortexm.c:232–281. Linked full main0x423E–0x425E and control sl_interrupt_manager_init0xE0AC.

Full RAIL masking routines0x22EAC/0x22F44 target radio IRQ31–38/40, not CPC12/21; PRIMASK restored. RAIL use_dma0x24080→0x20AF4 stores the allocated channel at0x200040BE, and helper0x20A2C reads it for transfers. No obvious fixed-channel theft. No further UART reconfiguration identified after CPC in examined direct references; this cannot exclude every indirect write or runtime interrupt storm.

No concrete defect emerged. Stop the offline audit rather than reverse-engineer the whole radio library. Runtime early/pre-close/reopened queries now have greater information value. Full/control retained disassembly files remain the evidence; no firmware change resulted.

## Fresh independent review and corrections

Fresh-context GPT-6 Astra/high reviewed the exact adapter, tests and proposed procedure. Reproduced two attribution defects using fake transport in the existing pinned flasher environment:

1. A CRC-valid unsupported NOOP could raise a vendor KeyError and leave its parser stuck, later appearing as ordinary response timeout.
2. The separately reopened protocol could report timeout after connection loss.

Both corrected through shared explicit observation-failure state, pending-query cancellation and checks before querying and after completion/timeout. Gecko loss is forwarded to its observer; reopened loss uses the same handler. Expected cleanup closure is distinguished from unexpected transport loss. Regression tests cover these cases. Host parser/transport failures abort observation and cannot count as firmware silence.

Reviewer independently confirmed source hashes, existing eight tests, shared launch transport, serialx exclusive reopen and file-descriptor release before disconnection notification. No additional material scope/recovery blockers were identified. The final11tests pass after corrections; no broad retesting or another review cycle justified.

## Validation and current authority

Actual vendor classes, fake transport: split valid packets, exact known request, sequences0/1/2, startup/wrong-property/wrong-endpoint/stale/corrupt packet rejection, bounded silent attempts, menu failure, cancellation, loss, expected close and source/version guards. CLI help for both entry points passes. These are host-side tests, not physical timing or candidate response evidence.

Candidate and rollback hashes match retained artifacts; manifest evidence/connection-lifecycle-preparation-20260920.json records final adapter hashes and preflight. No firmware rebuild, HA configuration mutation, service stop, reset or flash during preparation. User three-hour HA testing authorization recorded12:21–15:21UTC; concrete firmware window approval has been requested separately under the retained boundary. Do not confuse an unanswered question with approval.

Read-only HA at12:38UTC: original radio0.2.3-ordered, Z2M2.14.1-1, Matter9.2.0, SSH10.5.0 all started. Five newly unavailable entities are one previously intermittent stue_vaeg_spisebord bulb, last report12:28:11UTC and failed availability pings12:33:41/49. Its power state and cause are unknown; this occurred on original firmware before any new test. Matter reports continue. Preserve this pre-existing condition in a fresh baseline and use the established separate computer-desk bulb for representative acceptance, if still available. Do not require this unrelated bulb to become available as an invented flashing prerequisite, or attribute it to an unperformed test.

Private preflight evidence: /home/wsluser/.local/share/ha-recovery/sdk2026-lifecycle-preparation-20260920. Refresh time-sensitive baseline/maintenance facts before any approved outage; take fresh coherent backups inside it. Existing prior flash allowances remain consumed.
