# Protocol-crypto component isolation review — 2026-09-20

## Recommendation

Add the existing SDK component **`sli_protocol_crypto`** to the proven HFXO-enabled CPC diagnostic through SLC. Its declarations support a narrow mask-seeding diagnostic: no direct or newly identified transitive RAIL/Thread dependency is required. Keep HFXO enabled, CTUNE/token policy, security/storage/UART configuration, application patches and compiler settings from the passing diagnostic. No speculative prerequisite fix is justified by the inspected source.

This began as a component-definition/source audit and was extended to independently inspect the parent-generated diagnostic linked path below. Parent owns generation, full dependency/config/source comparison, packaging and any future device authorization. This review neither builds nor accesses production.

## Exact component and dependency evidence

All SDK paths below are relative to `/opt/silabs/sdks/simplicity_sdk_2026.6.1/` in stopped container `sisdk-upgrade-trial-20260914`. Files were read using `docker cp` without starting or mutating that container.

`platform_core/platform/security/component/sli_protocol_crypto.slcc`:

- ID/provides: `sli_protocol_crypto` (lines 1, 22-23). It is a production-quality internal component hidden in the UI (`visibility: never`, lines 8-10), not a custom application implementation.
- Sources: `platform/security/sl_component/sl_protocol_crypto/src/sli_protocol_crypto_radioaes.c` and `sli_radioaes_management.c`, each conditional on `device_has_radioaes` (lines 11-15).
- Requires `device`, `status`, `code_classification`, `emlib_core`; for `device_has_radioaes`, also `sli_psec_osal` and `psa_crypto_trng` (lines 24-32).
- Defines `SLI_RADIOAES_REQUIRES_MASKING` for `device_has_radioaes` (lines 35-37); contributes `SL_CATALOG_SLI_PROTOCOL_CRYPTO_PRESENT` through its catalog entry (lines 44-46). Series 3 is explicitly excluded (lines 33-34); the MG21 Series 2 target is not excluded.
- Registers `sli_protocol_crypto_init` in `service_init`, priority 1 (lines 47-53), and `sli_aes_seed_mask`, priority 2 (lines 54-62). The latter explicitly follows Mbed TLS and PSA initialization.

`platform_core/platform/security/component/sli_psec_osal.slcc:10-21,26-31` requires only `sl_core` and `code_classification`. It selects the bare-metal header unless `cmsis_rtos2` is already present; it does not require an RTOS. `sl_component/sli_psec_osal/inc/sli_psec_osal.h:45-52` enables `SLI_PSEC_THREADING` only for MicriumOS or FreeRTOS catalog entries. Preserve the baseline's bare-metal state.

`platform_core/platform/security/component/psa_crypto_trng.slcc:20-39` provides the TRNG capability, requiring `psa_crypto_common`, `psa_driver` for the applicable TrustZone state, and the TrustZone-state capability; the additional SI91x dependency is chip-conditional. There is no RAIL requirement. The baseline already has PSA crypto, whose own `psa_crypto.slcc:45-52` requires this TRNG capability on Series 2. It also has SE manager, whose component requires `sli_psec_osal` on Cortex-M (`se_manager.slcc:53-54`). These are existing dependency paths, not reasons to introduce another radio stack.

Local passing baseline evidence under `firmware/cpc-hfxo-diagnostic/output`: `autogen/sl_component_catalog.h:23-24` includes PSA crypto and SE manager; `autogen/sli_psa_config_autogen.h:17` defines `MBEDTLS_PSA_CRYPTO_EXTERNAL_RNG`; `autogen/sl_event_handler.c:51-52` calls `psa_crypto_init()` then `sl_se_init()`.

## Exact initialization behavior and prerequisites

Under `platform_core/platform/security/sl_component/sl_protocol_crypto/src/`:

- Both implementation files are guarded by `RADIOAES_PRESENT` (`sli_radioaes_management.c:30-32`, `sli_protocol_crypto_radioaes.c:30-32`). The full candidate's retained linked code already confirms MG21 takes this implementation.
- `sli_protocol_crypto_init()` creates a lock only under `SLI_PSEC_THREADING`; otherwise it returns OK with no hardware initialization (`sli_radioaes_management.c:88-124`).
- `sli_aes_seed_mask()` calls acquire and release (`sli_protocol_crypto_radioaes.c:859-865`). It performs mask preparation, not an AES encryption operation.
- Acquire enables the RADIOAES bus gate only on chips exposing `_CMU_CLKEN0_MASK`, and always enables `CMU->RADIOCLKCTRL` (`sli_radioaes_management.c:129-132`). The prior full linked audit showed the MG21 implementation writes RADIOCLKCTRL without a separate CLKEN0 write. This is the vendor's chip-guarded behavior, not evidence of an omitted clock call.
- In normal bare-metal context, acquire waits for RADIOAES FETCHERBSY/PUSHERBSY/SOFTRSTBSY to clear, then updates the mask (`sli_radioaes_management.c:161-168`). It contains no RAIL initialization call.
- The initial mask is four bytes from `psa_generate_random`, with a success assertion, then incremented and forced to have its high bit set (`sli_radioaes_management.c:63-83`). Release does no additional hardware operation in this context (lines 173-185).

`platform_core/platform/security/component/psa_crypto.slcc:76-83` gives PSA initialization priority 1 for TrustZone-unaware TRNG builds; `se_manager.slcc:104-109` gives SE initialization priority 1. Both precede the mask handler's priority 2. Ordering among priority-1 callbacks is not a mask-seeding prerequisite because the bare-metal protocol init itself is a no-op. Existing CPC security also invokes PSA initialization internally, as established in the previous startup review.

The HSE entropy backend supplies another explicit prerequisite check: `platform_core/platform/security/sl_component/sl_psa_driver/src/sli_psa_trng.c:58-89` calls `sl_se_init()` at line 68, creates an SE command context at 74, then calls `sl_se_get_random()` at 80. Its selection is guarded by HSE/TRNG driver features; the external RNG dispatch selects this backend at lines 109-113. The full candidate's linked `psa_generate_random_internal` reaches this SE backend. No missing SE initialization or RAIL-before-entropy requirement was demonstrated.

## Acceptance checks and interpretation limits

The generated result should add only the expected protocol-crypto component/catalog entry, source units, masking define and two service callbacks, plus mechanically required build artifacts. Verify actual graph changes rather than treating this declaration audit as the resolved SLC graph. Reject unexplained RAIL/Thread/RTOS, storage, security or clock changes from this isolation build.

Inspect the linked result to confirm the call is retained after PSA/SE initialization, RADIOCLKCTRL is enabled, the bare-metal RADIOAES busy-wait is present, and the four-byte entropy request is reachable. Compare the generated graph and compiler settings to the passing HFXO diagnostic; do not introduce LTO to match the full candidate during this split.

A CPC response would prove this added startup sequence returned and the processing loop ran. It would not validate an AES operation or sustained radio behavior. More narrowly, if `EFM_ASSERT` is compiled out, `sli_radioaes_update_mask` ignores an entropy failure and still forces the mask's high bit; `sli_aes_seed_mask` returns void. Therefore inspect the linked success check before treating a response as evidence that random generation succeeded. The previously inspected full LTO image lacked that success-check branch; do not silently alter the diagnostic's assertion policy to compensate.

Silence would localize the difference to the added component/startup path or its build interactions, but would not alone distinguish a RADIOAES wait from entropy failure/fault. Direct stage observation would then be more useful than changing unrelated crypto configuration. A passing result would move attention toward the remaining RAIL/OpenThread startup paths and full-image differences such as MPU, crash handling and LTO.

The preceding HFXO diagnostic's inherited-clock guard remains a separate limitation: its successful response established that its configured startup path returned, not that every HFXO optimization wait necessarily executed. Retain the same HFXO baseline for this next split.

## Independent linked check of the parent-generated diagnostic

Subsequently inspected `firmware/cpc-crypto-diagnostic/output/evidence/disassembly.txt.gz`, `symbols.txt`, and the ELF. Independently computed ELF SHA-256: `ffdea6681bc996038cd2cdd4f6bdffcb7d294a748dc7b24b17eaff114b6c99a8`. The parent reports source/config exact matches to the passing HFXO baseline, with only the intended component catalog and generated event-handler additions.

The linked path validates the proposed split:

- `sl_service_init` at `0x11FFC` calls CPC, Mbed TLS, PSA (`0x12006`), SE (`0x1200A`), protocol init (`0x1200E`), then tail-calls mask seeding (`0x12016`).
- `sli_protocol_crypto_init` at `0x114A6` is exactly return-OK; no RTOS/mutex path was introduced.
- `sli_aes_seed_mask` at `0x12AAC` calls acquire at `0x12AAE`, then release at `0x12AB6`.
- Acquire enables RADIOCLKCTRL at `0x12410-0x12418`; its non-ISR RADIOAES status wait is `0x1244A-0x12450`, using mask `0x43`.
- The mask symbol is zero-initialized BSS at `0x20001AD8`. If zero, the linked function requests four random bytes at `0x12458-0x1245C`. It checks success at `0x12460` and calls `assertEFM` on failure at `0x12466`.
- `assertEFM` at `0x1057C` is an infinite branch to itself. Thus the diagnostic retains a real failure trap; it cannot simply ignore an entropy failure through the seed path. Release at `0x12488` returns OK without additional peripheral initialization.

**Decision-changing compile difference:** this diagnostic retains the working recovery baseline's live EFM assertions, whereas the previously reviewed full LTO candidate has no entropy-success check in its linked mask-seeding path. Preserve this existing baseline policy for the narrow split. A diagnostic failure at this assertion would identify a real entropy problem, but would not by itself explain the full candidate's silence, because the full candidate continues past that particular failure. A successful response after a fresh application start is stronger evidence here that the added wait and checked entropy request returned successfully, assuming the expected normal-context startup and initially zero BSS mask; it still does not exercise an AES transaction or identify the full candidate's later failure.
