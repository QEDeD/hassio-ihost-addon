# SONOFF ZBDongle-E rollback candidate, 2026-09-14

Obtained `donglee_mg21_multipan_beta_4.6.0_115200.gbl` from the public SONOFF/iHost flasher repository. This is the best-supported available rollback candidate matching the observed model, CPC version and baud rate. It is **not proven to be byte-identical to the currently installed application**, and has not been flashed or tested on this radio.

## Provenance and integrity

- Repository: https://github.com/iHost-Open-Source-Project/hassio-ihost-sonoff-dongle-flasher
- Pinned source commit: `136ab2fe736a1e5e9c880c2334d2c95adf1e2f25` (2026-06-23).
- Download: https://raw.githubusercontent.com/iHost-Open-Source-Project/hassio-ihost-sonoff-dongle-flasher/136ab2fe736a1e5e9c880c2334d2c95adf1e2f25/firmware-build/donglee_mg21_multipan_beta_4.6.0_115200.gbl
- File size: 246596 bytes.
- SHA-256: `40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787`.
- Git blob: `df4ae1eb773207f13dad0662077a993b01b4e15d`; independently matched by `git hash-object`.
- Public file history returned one introducing commit, `849a095884060de08d716726d554f8d2d2f1c15a`, 2025-06-26, message `feat: add more firmware to supports v1.1.0`.
- Saved public catalog `FIRMWARE_LIST.json` labels it ZBDongle-E / mg21 / MultiPAN / beta / 4.6.0 / 115200. Catalog SDK version is empty.

Supporting metadata is retained in `source.json`, `source-commit.json`, and `artifact-history.json`. Issue https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/issues/55 also records this filename in the SONOFF flasher catalog in February 2026. That third-party issue log was a discovery lead; the downloaded repository artifact and catalog are the primary artifact evidence.

## Offline inspection

`inspect_gbl.py` parses all length-delimited tags and produces `gbl-inspection.json`.

- GBL header version 0x03000000, flags zero.
- App-info payload is preserved exactly in the JSON; it is not a unique installed-image identifier.
- Uncompressed plaintext program ranges: `[0x4000, 0x42d4)` (724 bytes) and `[0x42e0, 0x402f8)` (245784 bytes).
- Only header, application-info, program, and end tags appear. No bootloader-update, secure-element-update, encryption, or signature tag is present.
- Entire-file CRC32 residue is `0x2144df1c`, matching GBL CRC validation convention. This verifies file consistency, not vendor cryptographic signing or live bootloader acceptance.
- Embedded string: `SL-OPENTHREAD/2.6.1.0_GitHub-7f6723ffb; EFR32; Mar 31 2025 17:13:46`.
- Build-path strings reference `SimplicityStudio/SDKs/simplicity_sdk_12_01`; this is a directory name, not a verified SDK release declaration.
- CPC-related strings exist, including Bluetooth HCI CPC. Their presence does not establish enabled endpoints or persistent binding configuration.

## Known limits and practical use

The live probe established ZBDongle-E, Gecko bootloader 1.12.00 / SONOFF 1.0.1, CPC 4.6.0 at 115200, and an undefined secondary application version. The published model/version/baud match makes this a credible recovery artifact. No retained matching .gbl was found by a filename scan of C:/Users/Kristoffer/Git/otbr; the retained GBLs were OpenThread images for other purposes. No live readback or original flash record ties this file to installed bytes.

This GBL's program payload stops at 0x402f8, below the candidate firmware's reported NVM3 region 0xb4000–0xbe000. Payload ranges alone do not identify the old firmware's NVM3/PSA layout, demonstrate erase boundaries, guarantee startup preservation, or establish rollback compatibility. Public catalog metadata does not specify NVM3, PSA ITS, CPC encryption/binding, flow control, UART pin mapping, or manufacturing-token handling. Treat those as unresolved unless supported by separate source/config evidence.

Use this retained file to prepare a concrete rollback procedure and compare packaging/storage assumptions. Do not describe it as a tested rollback, exact original firmware, a state backup, or authorization to flash. No live access, serial operation, restart, flash, erase, publication, or external message was performed for this investigation.
