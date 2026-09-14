Current closeout (2026-09-14): see review/sdk2026/recovery/FINAL-ASSESSMENT.md and BACKUP-20260914.md. A new current host backup closes the earlier missing backup coverage; production radio recovery and candidate hardware acceptance remain unverified.

# Recovery decision checkpoint — 2026-09-14

## Decision

Continue offline preparation; do not request a production flash yet. The remaining gate is credible restoration of the current application AND relevant persistent radio state. Package validation is complete enough to support further compatibility investigation, not hardware acceptance.

## Evidence

- Confirmed ZBDongle-E; coordinated probe observed SONOFF1.0.1 / Gecko Bootloader1.12.00 and CPC4.6.0. Existing service operation was restored. See ../bootloader-probe/.
- Official SONOFF rollback candidate is retained with pinned provenance and SHA256 in rollback/README.md. Model/version/baud match; exact installed bytes and tested rollback are not established.
- SDK2026.6.1 application-only GBL was generated with Commander and independently compared against the clean compiled ELF/SREC. See ../firmware/package/. No bootloader or SE update is included. Firmware package encryption is separate from CPC transport encryption.
- Candidate payload ends below0x2a898; rollback payload ends0x402f8. Candidate linker reserves NVM3 at[0xb4000,0xbe000),40KiB, NOLOAD. These payloads avoid that region, but do not establish baseline storage layout, physical erase boundaries, bootloader policy or startup effects.
- candidate-clean/config/psa_crypto_config.h selects ITS driverV3, with V1/V2 driver support disabled and128 user files. Its configuration comments warn that changing the total key count for V3 can make existing keys inaccessible. Driver version is not interchangeable with metadata-format version.
- SDK platform_core/platform/security/sl_component/sl_psa_driver/src/sl_psa_its_nvm3.c places legacy migration under SL_PSA_ITS_SUPPORT_V2_DRIVER (including the block beginning line2028). That migration is not enabled here. This does not establish destructive migration; old-layout compatibility remains unknown.
- SDK cpc/src/sl_cpc_security.c defines binding keyID0x4200 and imports it with PSA_KEY_LIFETIME_PERSISTENT / LOCAL_STORAGE in store_binding_key (lines862–891). Binding therefore changes radio-held persistent state. Session-key behavior must not be confused with this binding key.
- Generated startup initializes NVM3 and PSA. nvm3_initDefault calls nvm3_open. A successful build or nonoverlapping application payload does not prove startup is storage-read-only.
- Host snapshot coverage is distinct from physical-radio state. See HOST-STATE.md for inspected paths, backup coverage and missing installed-image identity.

## Focused remaining checks

1. Find the baseline firmware's actual build/storage configuration: NVM3 region, PSA driver/key ranges, calibration/token handling and startup initialization. Prefer existing SONOFF/Silicon Labs source/build records. A filename or version string is insufficient.
2. Establish whether the installed bootloader provides a documented readback AND restore route covering the relevant radio regions. Readback alone is not recovery. Do not confuse Commander debug-probe memory access with the dongle's USB serial bootloader.
3. Compare candidate and baseline startup and downgrade behavior using those facts. Check recovery both before and after the first encrypted binding. Do not enable legacy migration speculatively.
4. Close host recovery gaps: immutable currently installed image, fresh backup covering focused app/Zigbee/Thread/Matter, private CPC host-key preservation and exact restoration mapping. No secret contents belong in this repository.
5. If sufficient evidence is unavailable, propose a spare equivalent dongle to test firmware/bootloader/binding behavior while preserving the production radio untouched. Spare success alone does not prove preservation of the production radio's existing state.

## Proposed next prompt

Resolve the remaining recovery gate for the prepared SDK2026.6.1 encrypted Multiprotocol candidate on our ZBDongle-E. Reuse the package, rollback, bootloader and host-state evidence already recorded. Prioritize obtaining the old firmware's storage/startup configuration and verifying a supported method to preserve and restore relevant radio state. Evaluate upgrade, first startup, first binding and downgrade separately. Distinguish serial-bootloader capabilities from debug-probe capabilities, and payload validation from hardware acceptance. Stop searches when further work has little prospect of changing the decision; report exactly what evidence is missing and the smallest practical alternative, including an isolated spare-radio trial if appropriate. Reconcile the installation proposal and have an independent reviewer challenge the recovery claims. Return either an exact bounded trial ready for approval, or a concrete remaining obstacle and recommended next action. Read-only inspection and offline work only: no production interruption, flash, erase, binding, publication or secret capture.

## Independent challenge

Rollback worker reviewed the decision separately: low payload addresses cannot establish first-start preservation; V3-only support is uncertainty, not proof of destruction; readback needs a supported restoration route. These qualifications are incorporated above.

## Primary references

- https://docs.silabs.com/simplicity-commander/latest/simplicity-commander-commands/gbl-commands — application packaging; compression requires target support; bootloader/SE upgrades are separate inputs.
- https://docs.silabs.com/gecko-platform/latest/platform-driver/nvm3 — persistent store operations; initialization/repacking cannot be inferred from application payload addresses.
- Exact SDK2026.6.1 source paths above and retained generated configuration provide candidate-specific evidence.