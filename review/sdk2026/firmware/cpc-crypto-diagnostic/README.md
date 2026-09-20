# Isolated protocol-crypto startup diagnostic

Status: built and packaged offline September20,2026. No HA staging or physical test. This is a diagnostic, not a corrective release or production firmware.

The full SDK2026 firmware is silent to CPC probing. The CPC-only image with external crystal initialization enabled has now passed on the dongle. This variant adds exactly the vendor `sli_protocol_crypto` component to that proven recipe. It initializes protocol-crypto state and seeds a masking value used by the radio cryptography implementation; it does not add a Thread/Zigbee stack, exercise radio packets or establish encrypted CPC binding.

## Why this is a useful split

Vendor component dependencies introduce no RAIL/OpenThread/Zigbee stack. Every retained application source and configuration file is byte-identical to the proven HFXO variant. The generated catalog adds only SLI_PROTOCOL_CRYPTO; the event handler adds its header and two unconditional calls after PSA/SE initialization. The clock, CTUNE/calibration policy, UART, security/storage and baseline compiler optimization/assertion policy remain unchanged; the component supplies its RADIOAES masking definition. See evidence/comparison.json and ../../CRYPTO-COMPONENT-REVIEW-20260920.md.

Linked code confirms the normal-path RADIOAES busy wait, four-byte randomness request and calls before CPC processing. Protocol init itself is a no-op in this bare-metal build. The entropy error assertion is an infinite loop in this diagnostic; the optimized full image omits that check. A diagnostic failure therefore does not by itself establish the cause of full-image silence. Preserve this known difference rather than simultaneously changing assertions/optimization.

## Reproduction and artifacts

`build.sh` reuses the digest-pinned Nabu Casa builder and Debian snapshot. The existing HFXO prepare script first produces its unchanged recipe; this directory's prepare script adds only the vendor component selection. Generation and compilation run without network access or devices. Defaults refuse existing output. SDK source/patch manifests and installed build packages match the proven HFXO build. Evidence retains the exact generated differences and linked instructions.

ELF SHA256: ffdea6681bc996038cd2cdd4f6bdffcb7d294a748dc7b24b17eaff114b6c99a8

GBL: package/cpc-crypto-sdk2026-application-only.gbl

GBL SHA256: a7684fe05c9d31fccb311ba9f895769087a040f6525d2163c8c6311ebffe91ee

`build-package.sh` pins this ELF and reuses the unchanged recovery packaging verifier. Set COMMANDER, PACKAGE_WORK (new directory), FIRMWARE_INPUT and PYTHON as documented for that helper. Retained Commander1v25p0b1995 was reused in a network-disabled container without devices/mounts. ELF/SREC/parsed-GBL equality, CRC, tag allowlist, application properties and program-page bounds pass. Pages0x4000–0x14000 exclude bootloader and NVM at0xb4000; no bootloader/SE update tag. Runtime NVM writes remain possible because the inherited CPC sample initializes NVM/PSA. Its explicit unbind endpoint remains unused; automatic unbind is absent.

Compilation and packaging establish a controlled artifact, not hardware behavior or a fix. The inherited-HFXO early-return caveat also remains. See ../../CRYPTO-TRIAL-PLAN-20260920.md for the unapproved hardware procedure and ../../CRYPTO-NEXT-STEPS-20260920.md for the adaptive investigation route. Legacy OFFLINE/NOT FOR FLASHING strings in the reused source denote the original build's scope; they are not a substitute for later exact-artifact review and explicit test approval.
