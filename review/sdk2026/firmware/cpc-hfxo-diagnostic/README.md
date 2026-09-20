# CPC diagnostic with external crystal initialization

Status: built, packaged and hardware-tested September20,2026. Both CPC version queries passed; original4.6.0 was then restored and production checks passed. See ../../HFXO-TRIAL-RESULT-20260920.md. This remains diagnostic firmware, not a corrective release or qualified production image.

The hardware-proven CPC-only SDK2026 image answers version queries; the full multiprotocol image does not. This variant explicitly enables HFXO (the external high-frequency crystal) in that CPC-only image, using the vendor clock-manager setting. Its purpose is to establish whether this additional initialization can finish on the existing ZBDongle-E.

## Controlled change and evidence

`prepare-build.py` reuses the existing CPC recovery build recipe and adds only `SL_CLOCK_MANAGER_HFXO_EN=1`. It preserves CTUNE fallback128 and stored calibration selection, SYSCLK/PCLK, UART115200/no flow, SDK, source patches, security/storage, component catalog, generated startup and original non-LTO compiler configuration. Comparison of every retained source, config and generated file found only the intended oscillator setting and its SLC checksum changed. See evidence/comparison.json and linked-clock-review.md.

Build uses the same digest-pinned Nabu Casa builder and Debian snapshot as the successful recovery build. Generation and compilation run with network disabled. `build.sh` builds from the repository root and refuses an existing output directory. The output directory and full build log remain local/ignored; selected provenance and linked evidence are retained under evidence/.

ELF SHA256: fa14fd55f8e16ef6729572eb4d1dbc63c0b17762b6da640bf34352cbb4f3f913

Application-only GBL: package/cpc-hfxo-sdk2026-application-only.gbl

GBL SHA256: fcd9addc9323d92f23013056e93689e43213709f896c99a733348398d3283cb8

## Packaging and validation

`build-package.sh` pins the new ELF and delegates the existing recovery packaging/checks. Existing recovery defaults are unchanged. Run with COMMANDER, PACKAGE_WORK (new directory), FIRMWARE_INPUT (build artifacts directory) and PYTHON set, as for the recovery image. Commander1v25p0b1995 archive SHA256 is ed1605a12ae3c5e43c2cd7e88d5abb8a7bb62e801ab4f91b286f3bae7f5beaa1; the verified retained archive was reused inside a network-disabled container with no device mounts.

Independent validation verifies ELF/SREC/parsed GBL payload equality, CRC, application properties and tag allowlist. Program pages are 0x4000 through0x14000 (exclusive), below NVM at0xb4000; no bootloader/SE/dependency update tag is present. This does not establish runtime NVM safety or hardware success. Original recovery package still passes unchanged defaults; wrong ELF and path traversal inputs are rejected. See package/independent-validation.json and evidence/package-regression-results.json.

The inherited recovery app has an empty cpc_app_init and no automatic unbind, but initializes NVM/PSA and retains an explicit unbind endpoint. It is not a read-only image. Only version probing is proposed; no host client or unbind may run.

## Interpretation and authority

A CPC reply establishes that the HFXO-enabled recovery startup reaches communication under the tested boot sequence. Vendor initialization can skip crystal reinitialization if inherited SYSCLK already uses HFXO, so a reply does not prove every crystal wait ran. It does not establish RF, full-image startup, binding or network operation. Silence narrows suspicion to the added initialization or its interactions; it does not prove a faulty crystal or justify speculative tuning.

See ../../NEXT-INVESTIGATION-20260920.md for the adaptive route and ../../HFXO-TRIAL-PLAN-20260920.md for the separately approved production procedure. No live action or publication is authorized by these recipes.

Linked-code caveat: the vendor initializer skips crystal reinitialization when inherited SYSCLK is already HFXO; the full candidate has the same guard. A version reply proves that the configured startup path returns under this boot sequence, not that every crystal wait executed. Record this limitation and retain the same upload/open sequence; a further test is worthwhile only if it resolves the remaining mechanism.
