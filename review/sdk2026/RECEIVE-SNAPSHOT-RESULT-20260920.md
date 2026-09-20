# Receive diagnostic trial result — September 20, 2026

The approved follow-up diagnostic and mandatory original restoration completed once. Production firmware4.6.0 and app0.2.3-ordered are restored. Radio-service interruption was263.3seconds (about4m23s). Recovery checks passed after382.8seconds of observation. This completes the diagnostic trial, not the SDK upgrade.

## Findings

The host captured the21byte CPC startup frame followed by a valid929byte RXS1 diagnostic record (schema, build and CRC verified). Firmware completed287756 main loops, one transmit completion and two receive callbacks. One received frame failed its payload CRC; no header CRC failure was recorded.

Both calls to adjust the receive transfer failed in the driver's received-byte-count check: resize_calls2, resize_fail2, resize_ok0, resize_already0. The terminal receive destination is descriptor1's destination+8 while the software head selects descriptor0; subtracting that head's destination gives−552. This supports a mismatch between hardware and software buffer position. The terminal descriptors can have been modified after the first failure, so these final addresses alone do not prove the exact first-failure sequence.

The first rejected frame had header and driver lengths10, received FCS0x5599 and computed CRC0x3eb7. USART.IF was0x2002 at the header, payload and first-bad observations: no receive-overflow flag then. Overflow appears in the later terminal flags0x201e. Overflow therefore is not established as the initial cause. No recovery dispatch or run was recorded.

Both host requests are independently valid:17bytes, payload-with-CRC length10, header CRC0xd355, payload CRC0x12db. Original4.6.0 answers the same request before and after the diagnostic. This rules against malformed host construction; it does not prove every byte arrived unchanged at the MCU.

## Interpretation and next investigation

The best current hypothesis is initial DMA descriptor-loading timing. The driver starts a descriptor load and immediately modifies live LINK/DONEIEN registers. Both initial RAM descriptors have linking disabled. If the asynchronous load overwrites a live LINK edit, the callback could advance its software buffer while hardware stays on the previous buffer. Full LTO reaches these writes sooner than the passing control. This is a plausible explanation, not a confirmed defect: the diagnostic does not capture the post-initialization, pre-request registers.

Check the vendor's supported completion/initialization contract and descriptor reuse before changing this sequence. Avoid arbitrary delays, speculative CRC changes, or another broad diagnostic matrix. A source-grounded correction or one discriminating initial-state observation should determine the next trial.

## Recovery evidence

- Writers stopped15:35:24–15:35:50UTC; fresh coherent backups independently verified15:35:56. Core/Matter restarted15:36:17; original control passed15:36:20.
- Diagnostic upload15:36:33–15:37:12; original restoration15:37:34–15:38:31. Settled original control passed15:38:58.
- Radio/Zigbee2MQTT restarted15:39:41/47; original policies restored15:39:48. No old host-state backup was restored.
- Coordinator IEEE, PAN, extended PAN, channel25, network key and Thread dataset match the stopped backup. Zigbee read returned currentLevel1; Matter Identify returned Success(0). ALPSTUGA temperature/humidity/CO2 updated15:45:48.
- All four original app versions/options/policies/running states match. Temporary tools removed and all113 original SSH package versions preserved.
- Final state observation15:46:13 showed no newly unavailable radio-device entities. Two dishwasher controls became unavailable when the connected dishwasher started a programme; this is a separate state change, not evidence of radio loss.
- Logs retain Thread reassembly/drop messages and Zigbee ping failures. These checks establish representative recovery, not error-free operation or long-term reliability.

Timestamps above use the WSL event clock. Windows/tool wall time was about7m45s behind WSL at closeout; observation durations compare timestamps from the same clock. Exact events and sanitized metadata are in [the evidence file](evidence/receive-snapshot-result-20260920.json).

Raw logs, snapshots and backups remain private at /home/wsluser/.local/share/ha-recovery/sdk2026-receive-20260920 and /share/codex-sdk2026-receive-20260920 on HA. Completed helper flash/backup commands must not be replayed. The single diagnostic approval is consumed; offline preparation continues. Any additional flash requires a concrete approved trial.
