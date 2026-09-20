# Terminal snapshot trial result — September 20, 2026

The one approved diagnostic upload/capture and mandatory original restoration completed. Original firmware4.6.0 and app0.2.3-ordered are running. Radio-service interruption was257.2seconds (about4m18s). Recovery closeout at15:13:46UTC followed more than five minutes of observation, with no newly unavailable HA entities. The SDK upgrade remains incomplete.

## What the diagnostic established

The host received680bytes after launch: the21byte CPC startup frame and one complete659byte diagnostic record. The record's schema, build discriminator and CRC validate; all snapshot groups are valid and terminal takeover status is7. Both early request attempts timed out.

The firmware completed299611 main loops before capture. CPC transmit completion and the TX-completion interrupt each completed once; tx_ready=1. Receive callbacks entered and returned twice; the CPC core processed one received frame and counted one invalid payload checksum, with no invalid header checksum. This is not evidence of a general startup or main-loop hang. The captured CPC_ENTER phase is only an instantaneous sample.

Independent host-side CRC calculation validates both identical17byte requests: declared length10, header CRC0xd355 and payload CRC0x12db. The exact same request succeeds in the original4.6.0 controls before and after the trial. The retained vendor source drops an unnumbered frame when its payload CRC is invalid, explaining why that processing path sends no reply. It does not yet establish which bytes/length reached validation or why they differed.

The receive snapshot also records USART.IF0x201e (including RXOF/RXFULL/RXDATAV) and STATUS0x21e3. A focused source review identifies receive overflow and unread FIFO data; exact initialization/descriptor analysis is separate. These flags and the checksum failure focus investigation on reception and buffer handoff. No speculative firmware fix has been applied.

## Recovery and verification

- Writer stop15:04:26UTC; fresh coherent radio/Matter/HA/actual-Z2M backups independently copied and verified15:04:57. Core/Matter restarted15:05:24; original control passed15:05:26.
- Diagnostic uploaded once15:05:38–15:06:17. Original restoration began15:06:36 and completed15:07:30; settled original control passed15:08:00.
- Original radio/Z2M restarted15:08:32/44; saved policies restored15:08:44. No stale host backup was restored.
- Coordinator identity, PAN/extended PAN, channel25, network key and saved Thread dataset match the fresh stopped backup. The non-actuating Zigbee read returned currentLevel1; ALPSTUGA Identify returned Success(0). Fresh changing temperature, humidity and CO2 reports continued.
- Temporary flasher environment/packages removed15:09:48; all113 original SSH package versions match exactly. All four app versions/options/policies and running states verified at final closeout.
- Final availability compared with the fresh baseline shows no newly unavailable entities. Logs contain startup Thread warnings and pings to already unavailable Zigbee devices; a Matter subscription timeout was observed before continuing reports. The bounded recovery check does not establish long-term reliability or an error-free log.

## Next action and authority

Finish the focused receive-path comparison, including exact descriptor handoff and vendor fixes, before selecting a corrective change or another diagnostic. Do not repeat the startup/lifecycle or reduced-component matrix without a new discriminator. The approved single diagnostic is consumed; further preparation is authorized, another firmware trial requires its own concrete approved scope.

Sanitized evidence: evidence/post-startup-result-20260920.json. Private raw logs, coherent backups, helper source and event record: /home/wsluser/.local/share/ha-recovery/sdk2026-poststartup-20260920. HA retained captures: /share/codex-sdk2026-poststartup-20260920. Completed helper flash/backup commands must not be replayed.
