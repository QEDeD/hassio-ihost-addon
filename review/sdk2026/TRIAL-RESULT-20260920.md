# SDK2026 production trial — September 20, 2026

## Outcome

The candidate application upload completed, but the radio failed its CPC response gate. The approved single terminal fallback restored SONOFF4.6.0 and multiprotocol app0.2.3-ordered. Zigbee and Matter reports resumed, an explicit Zigbee LevelControl read succeeded, and ALPSTUGA Identify completed. The SDK2026 upgrade remains incomplete. No second candidate cycle is authorized by this trial.

## Observed sequence (UTC)

- 08:04:43: first writer stopped; downtime began.
- Supervisor's combined backup failed because stopped Core could not receive its WebSocket backup preparation request. No firmware had changed. With all relevant writers still stopped, created a three-app Supervisor backup and a separate direct HA configuration archive, excluding history. Both independently copied to protected WSL storage and hash/coverage verified by08:06:38.
- 08:07:05: Core and Matter restarted; radio app and Z2M remained stopped.
- 08:08:21: candidate app0.3.1-sdk2026 installed stopped with existing options/data preserved. Supervisor store info reports installed version in `version` and the selected update in `version_latest`; use the latter before updating.
- 08:08:48–08:09:25: candidate GBL b5deda18… uploaded once; flasher exited0. This establishes accepted upload, not independent flash readback or application health.
- CPC-only probe at115200 failed. A bounded bootloader/CPC probe without reset also failed. No `bind-ecdh`, candidate network startup or encrypted session was attempted.
- 08:11:16–08:12:12: after saving latest stopped host state, one approved official SONOFF4.6.0 fallback upload completed. RTS/DTR reached Gecko bootloader1.12.0. Subsequent probe detected CPC4.6.0.
- 08:13:35–08:13:41: original app0.2.3-ordered and Z2M restarted against latest preserved stores. About9minutes elapsed to service restart; fresh Zigbee and ALPSTUGA reports followed by08:13:54.
- 08:14:59–08:15:00: startup/watchdog/update policies restored, explicit Zigbee LevelControl read returned1, ALPSTUGA Identify completed. No lamp brightness or power command and no plug switching occurred.
- 08:16:12: temporary flasher venv/APK group removed; all113 original SSH package versions restored and apps verified started. Firmware bundle and protected recovery copies retained. ALPSTUGA reports remained fresh at08:19:15.

## Preservation and limits

The focused host token and complete Thread store captured before fallback were byte-identical to the initial coherent copies; the candidate host never started. Restored Zigbee coordinator identity, PAN, extended PAN, channel and network key match the initial archive. HA's saved Thread datasets are unchanged. Recovery reused current stores, not older counter snapshots. Bootloader and Secure Engine were not flashed; no erase/unbind/key-regeneration occurred.

This is physical recovery evidence for the specific pre-binding failure encountered. It does not establish recovery after candidate binding or network activity. Successful probes of the old application and failed probes of the candidate narrow the issue, but do not distinguish startup faults from UART/protocol behavior. Prior wording calling it a firmware startup failure was stronger than the evidence.

## Offline next step

Do not reflash this candidate unchanged. First compare the actual startup/clock/bootloader initialization path with a known working ZBDongle-E vendor/community build and establish what a minimal diagnostic would distinguish. The pinned flasher queries CPC/system application versions using unnumbered system messages. The retained SDK's cpc/src/sl_cpc_system_secondary.c explicitly permits both version queries on unencrypted U-frames (lines1451–1463), with the expected three-uint32 CPC version and NUL-terminated application string (484–523); encryption alone is not an evident explanation. This is a targeted source check, not complete protocol compatibility proof.

Independent offline inspection found no demonstrated vector/package/baud/pin defect. Treat clock wait loops, old bootloader initialization and pre-loop RAIL/security initialization as hypotheses until stronger evidence exists. Reuse existing board definitions and vendor startup code before adding custom diagnostics. Any new disruptive trial requires a revised concrete approval; the previous one-candidate/one-fallback allowance is consumed.

The nine prepared contributions retain their September19 dispositions. This pre-binding firmware failure supplies no evidence to obsolete or declare production acceptance of their SDK adaptations. Reassess again when the startup issue is understood and an upgraded combination operates successfully.

## Evidence and recovery material

- Sanitized result: evidence/trial-result-20260920.json.
- Private command logs, baseline options, timestamped events and backups: /home/wsluser/.local/share/ha-recovery/sdk2026-20260920 (0700 directory,0600 files).
- Initial app archive: HA backup d983591c, independent initial-apps.tar SHA256c0c0ef07055fba1d88150823fe8bcd653de776cf0b61d2d5ff80e9e52794afdf.
- Direct HA config: /backup/sdk2026-ha-config-coherent-20260920.tar.gz, independent initial-ha-config.tar.gz SHA256c03b794eae7308c15b636390ff61b437154823e7faa6753f2b2bd7ce6d6008fe. It is a direct configuration archive, not a Supervisor-restorable Core backup; no restore was performed.
- Latest pre-fallback focused app archive is independently preserved; no raw backup/key contents belong in Git.


## Bounded independent offline review

The candidate_boot_failure worker reported the following inspection findings; no new hardware operation or rebuild was performed:

- Candidate and working rollback share vector origin0x4000, initial SP0x20000ac8 and application-properties format0x201. Candidate reset vector0x130c3 resolves to Reset_Handler and Reset_Handler_C. App-type metadata differs0x2 versus0x22; rejection is not established.
- Candidate uart_drv_hw_init at0x68a8 contains the intended PB1/PB0,115200,no-CTS configuration. This reduces the likelihood of a simple generated-header/pin mismatch; actual clock operation remains unproven.
- Early HFXO wait loops in main at0x42b4/42ee/42fc precede CPC. Generated oscillator configuration uses38.4MHz and fallback CTUNE128 with calibration preference. A physical stall is a hypothesis, not an observation.
- bootloader_init calls the resident bootloader before CPC (linked call0x47be); old-bootloader mitigation/NVM fault handling are enabled. No blanket bootloader-too-old conclusion follows.
- NVM, RAIL/OpenThread and SE entropy initialization precede the main CPC processing loop. Silence does not identify which stage failed.

References: firmware/candidate-clean/evidence/disassembly.txt.gz; candidate-clean/config/sl_clock_manager_oscillator_config.h; candidate-clean/config/btl_interface_cfg_s2c1.h; candidate-clean/autogen/sl_event_handler.c; both hashed GBLs. Next useful comparison is the exact working rollback's HFXO and bootloader/security initialization against these paths, reusing its vendor board recipe. Do not select a different tuning value, erase storage or change bootloader/SE without evidence.
