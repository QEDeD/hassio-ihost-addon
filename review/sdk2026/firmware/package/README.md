# Offline application-only GBL3 package — not authorization to flash

Created `output/rcp-sdk2026-application-only.gbl` from the clean ELF whose SHA-256 is `165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74`. This packages the existing encrypted-CPC multi-PAN application without rebuilding or changing firmware source. The confirmed target is ZBDongle-E; observed Gecko Bootloader 1.12.00 / Sonoff 1.0.1 banner and current CPC 4.6.0 are supplied installation facts, not observations made by this packaging task.

GBL SHA-256: **`b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50`**. Size: 157,924 bytes. GBL3 is selected explicitly, not GBL4. Package is unsigned and unencrypted, with no compression, certificate, version dependency, bootloader or Secure Engine update. CPC link encryption is separate from GBL file encryption.

## Verified content

Commander 1v25p0b1995 created the GBL and parsed its application back to S37 successfully. The independent standard-library Python validator checked GBL tag bounds and CRC, SREC checksums, ELF load segments, exact byte/address equality among original ELF, original S37, independently decoded GBL payload and vendor-extracted S37. All 157,836 programmed bytes match; there are no metadata patches or extra programmed bytes. See `output/independent-validation.json`, create/parse logs and captured exact tool help.

Only five tags occur: GBL3 header version `0x03000000` / type 0, application information, two ordinary ERASEPROG tags, and CRC/end. Program intervals are `[0x4000, 0x4134)` and `[0x4140, 0x2a898)`. With the target SDK's 8-KiB flash pages, these addresses touch pages within `[0x4000, 0x2c000)`. Neither the candidate bootloader reservation `[0, 0x4000)` nor candidate NVM `[0xb4000, 0xbe000)` occurs in the payload or its touched pages. This is package content evidence: it does not prove the installed bootloader's erase policy or preservation of the existing firmware's storage layout.

Application properties at vector-word-13 pointer `0x26254` retain structure version `0x201` (major 1, minor 2), signature type 0, signature location `0xffffffff`, application type `0x2` (Thread), version 1, capabilities 0 and all-zero product ID. These are generic vendor-project metadata, not the SDK/CPC version or a board compatibility check. Multi-PAN behavior comes from the compiled configuration. The properties contain no minimum-bootloader field, and the GBL has no explicit dependency tag; this is not proof of no minimum runtime requirement.

## Provenance and recreation

No existing Commander executable was found. Downloaded the official [Simplicity Commander Linux archive](https://www.silabs.com/documents/public/software/SimplicityCommander-Linux.zip) on 2026-09-14; archive SHA-256 `a6fa2d906757af0fd37f60ea60ede0430ac360eff38b7dcb84095dc28984608e`. Selected `Commander-cli_linux_x86_64_1v25p0b1995.tar.bz`, SHA-256 `ed1605a12ae3c5e43c2cd7e88d5abb8a7bb62e801ab4f91b286f3bae7f5beaa1`. This mutable download URL must be checked against the recorded hash when recreating the tool input. Downloaded archives remain locally under ignored `tool/`.

Ran the extracted CLI in disposable container `sdk2026-gbl-package` with network disabled, no bind mounts or device mappings, based on `ghcr.io/nabucasa/silabs-firmware-builder@sha256:aaeedf3cceb95dc15a9d3333093e76957ef20d06f94d3f7b23d5bd88d337a85d`. Existing bundled Python extracted the archive and performed validation; no global tools or packages changed.

The exact creation operation was `commander-cli gbl3 create OUTPUT.gbl --app VERIFIED.out`, followed by `commander-cli gbl3 parse OUTPUT.gbl --app EXTRACTED.s37`. `build-package.sh` records the repeatable bounded sequence with explicit tool/input paths and a fresh destination. Its `verify-package.py` uses no vendor parsing library. Official [GBL3 command documentation](https://docs.silabs.com/simplicity-commander/latest/simplicity-commander-commands/gbl-commands) supports this application-only route; the captured installed-version help is authoritative for the command used here.

## Remaining compatibility limits

Basic, uncompressed application-only GBL3 avoids requiring optional decompression or bootloader/SE upgrade support and is the proposed package form for the Series-2 Gecko bootloader. Commander parsing does **not** verify acceptance by the actual Gecko 1.12.00 image, its signed/encrypted-image policy, application-version checks, application-properties compatibility, erase behavior or installed storage allocation. No old bootloader source/image policy was established here. No actual device accepted this package, and no flash, reset, binding or live access occurred. Those installation gates remain with the upgrade/recovery proposal.
