# Full startup trace result — September20,2026

One approved diagnostic upload and one mandatory original-firmware restoration completed. Original radio4.6.0/app0.2.3-ordered are running; representative checks and cleanup passed. Final HA availability comparison is pending because the shared API credential locked during observation; user has been asked to unlock. Do not replay this consumed flash allowance.

## What the test established

All40 startup checkpoints arrived in the expected order, including FF inside app_init. The last chunk also contained a valid CPC system frame. This instrumented run did not remain stuck in any bracketed initialization call; it reached CPC transmission after tracing's handoff. That does not prove continued receive/interrupt/main-loop health or behavior of the uninstrumented firmware.

The final bootloader RUN was logged at13:40:46.550CEST. Checkpoints and the trailing CPC frame completed at13:40:46.643, about93ms later. The connection remained open for30seconds without issuing CPC queries. After it closed and a new probe opened, four version requests received zero bytes. Therefore this experiment cannot distinguish loss of responsiveness during the idle interval from an interaction with closing/reopening the port.

The trailing CRC-valid frame is PROP_VALUE_IS/LAST_STATUS=120 (RESET_WATCHDOG), a startup reset-cause notification, not a version response or proof of a new watchdog reset after FF. The same log contains an identical notification from the original4.6.0 firmware before upload, followed by successful version queries. It is not distinctive evidence of the candidate's failure.

The unmodified baseline and restored firmware each returned both version properties, two raw RX chunks/two parsed frames, zero parse errors. Diagnostic probe exit1, zero RX/frames. No binding, unbind, candidate host, radio network command, clock/channel change, erase, bootloader or SE update occurred.

## Recovery evidence

First writer stop11:37:54UTC; independent coherent backup verification11:38:25. Diagnostic upload11:39:42–11:41:15; probe11:41:15–20. Latest stopped radio host stores were independently preserved and exactly unchanged. Mandatory original upload began11:41:56, well before T+15, and ended11:42:53. Original probe passed11:43:22; original radio/Z2M restarted11:43:52/58 and policies restored11:43:59. Services returned after about6m04s.

Saved coordinator identity, Zigbee PAN/extended PAN/channel/key and HA Thread dataset match. Explicit Zigbee currentLevel read returned1; ALPSTUGA Identify15seconds received Success(0), and changing measurements resumed. Temporary flasher tools were removed11:48:05 with all113 original package versions matching. Original app versions/options/startup/watchdog/update policies are verified. No stale host backup was restored.

Initial newly unavailable entities were still settling at the first snapshot. A later HA API snapshot was refused because the shared credential was locked. Final availability comparison remains required; do not infer its result from successful representative checks. SSH-side logs and app checks remained available. Restored old-stack logs include startup mDNS/DUA/fragmentation warnings, CLI broken-pipe warnings and unavailable-device pings; Matter logs had no warning/error lines in the reviewed snapshot. No error-free-log claim.

## Parser correction and limits

The prepared extractor expected a synthetic `Sending b'2'` line. Actual pinned serialx logs `Immediately writing <GeckoBootloaderOption.RUN_FIRMWARE: b'2'>`. Its fail-closed behavior correctly rejected that mismatch rather than combining earlier launch output. Corrected only the offline parser/tests, then extracted the complete sequence from the retained raw capture. Five pinned-flasher tests pass with the actual observed RUN format. Firmware, flasher capture wrapper and raw evidence were not changed; output/evidence retains the exact pretrial source snapshot for provenance. No repeat flash was needed.

This reveals a gap in the earlier parser test fixture: it tested segmentation logic but not the real transport's log wording. Future capture assertions should use observed or tool-generated log records. The hardware capture itself worked.

## Next investigation

Source specialist independently decoded the frame/checksums and compared exact flasher/serialx/SDK behavior. Serial-open mechanics change DTR/RTS and flush buffers even with flow control disabled; because controls work under those mechanics, this remains a hypothesis. Offline inspection should focus on the first CPC TX completion interrupt and first app_process_action work (otTaskletsProcess followed by otSysProcessDrivers), alongside the close/reopen path. Successful DMA transmission alone does not prove its completion ISR or RX processing worked.

If another physical test becomes justified, query CPC on the same still-open launch connection before any close/reopen. That is a sharper discriminator than another isolated-component firmware. First prepare/review that adaptation and its logging/ownership limits; no further hardware trial is authorized now. Avoid speculative firmware fixes and do not claim an SDK defect has been identified.

Private authoritative logs, backups, events and helpers: /home/wsluser/.local/share/ha-recovery/sdk2026-startup-20260920; HA /share/codex-sdk2026-startup-20260920. Sanitized evidence: evidence/startup-trace-result-20260920.json. SDK upgrade and nine-contribution reassessment remain open.
