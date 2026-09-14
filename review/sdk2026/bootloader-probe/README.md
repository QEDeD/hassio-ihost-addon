# Authorized ZBDongle-E bootloader identification, 2026-09-14

Operator confirmed model ZBDongle-E and label identifier3075302DE7. This is a model identification, not a separately verified board revision.

Coordinated with the HA general-improvements task: its Core restart finished first. This task stopped Zigbee2MQTT and focused Multiprotocol, invoked universal-silabs-flasher1.1.0 probe with RTS/DTR reset and bootloader:115200,cpc:115200, then restarted the existing apps via an EXIT trap. No firmware file, flash, erase, write-IEEE or binding operation was invoked.

## Observed
- Bootloader banner: Sonoff v1.0.1; Gecko Bootloader v1.12.00.
- Bootloader query/return succeeded; existing application replied over CPC as version4.6.0 at115200 baud. Secondary application-version property was UNDEFINED; do not treat CPC version as a uniquely identified firmware build.
- Probe exit0. Redacted protocol evidence: probe.log.
- Interruption began11:51:20 CEST. Zigbee bridge online11:51:51; fresh ALPSTUGA reports11:51:50 and11:52:19. Both radio apps and Matter Server subsequently reported started.
- A trailing CR from PowerShell stdin made the wrapper's final shell exit argument invalid. The EXIT trap still restarted both apps successfully. Actual probeexit0 and independently observed restoration are the acceptance evidence, not wrapper status. Future remote scripts should be transferred as LF files rather than piped with an added CRLF.
- Temporary APK virtual group .codex-bootloader-probe and /tmp/codex-bootloader-probe venv removed; all19 added packages removed, original113 packages restored. Package indexes and the non-secret probe log may remain in SSH-app cache/tmp.

## What this establishes

The connected model supports the tested software-triggered bootloader entry and return to its current working CPC application. No physical unplug was needed. This does not establish a successful flash, downgrade, preservation of NVM across an SDK jump, or compatibility of the new candidate's firmware/storage layout.

## Remaining before flashing

Identify the exact known-good firmware artifact (CPC4.6.0 alone is insufficient), verify Gecko1.12-compatible application GBL packaging and update/NVM preservation rules against the existing and candidate layouts, and prepare the matched host/radio/key rollback. Obtain approval for that concrete flashing procedure. Do not treat this successful probe as firmware upgrade approval or as a tested radio-state backup.
