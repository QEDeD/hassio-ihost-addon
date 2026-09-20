# Full RCP versus working CPC-only startup, 2026-09-20

## Conclusion

The next useful diagnostic is the existing working CPC-only recovery build with exactly one intentional configuration change: `SL_CLOCK_MANAGER_HFXO_EN=1`. Keep CTUNE fallback 128, manufacturing-token selection, security, storage, UART, application behavior, compiler options, and packaging unchanged. This is a supported clock-manager configuration and selects the full candidate's early HFXO-enabled initialization path (which may skip reinitialization if inherited SYSCLK already uses HFXO) without adding its later radio/Thread initialization. It is a diagnostic, not a demonstrated fix.

No concrete missing initialization prerequisite or proven source defect was established in this review. The new successful CPC-only run substantially narrows the problem, but does not prove which full-image stage fails. A valid CPC response requires reaching the main processing loop; UART silence alone cannot distinguish an early clock wait from a later assertion or fault.

## Inputs and scope

Parent-reported physical evidence: the exact full candidate produced zero RX during DEBUG CPC probing; the existing exact CPC-only recovery image returned CPC 4.9.1 and both version replies. Official 4.6.0 was restored and device operation verified. No binding/unbind occurred. This review independently inspects retained source and linked code, not the physical logs or devices.

Full candidate ELF: `firmware/candidate-clean/artifacts/rcp-uart-802154.out`, SHA-256 `165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74`. Full linked addresses below refer to its `evidence/disassembly.txt.gz`. Working CPC ELF: `firmware/cpc-recovery/output/artifacts/cpc_secondary_vcom_security_device_recovery.out`. SDK source references are relative to `/opt/silabs/sdks/simplicity_sdk_2026.6.1/` in the stopped retained builder `sisdk-upgrade-trial-20260914`; read through `docker cp`, without starting the container. No build, production access, or device action was performed for this review.

## The first useful split: HFXO

Both generated oscillator config files contain identical AUTO logic, but their catalogs make it mean different things:

- `candidate-clean/config/sl_clock_manager_oscillator_config.h:40-63` and `cpc-recovery/output/config/sl_clock_manager_oscillator_config.h:40-63`: AUTO enables HFXO only when `SL_CATALOG_RAIL_LIB_PRESENT` exists.
- Full `autogen/sl_component_catalog.h` defines RAIL; recovery `output/autogen/sl_component_catalog.h` does not.
- Both oscillator configs retain CTUNE fallback 128 at line 84 and manufacturing CTUNE selection at line 105. Fallback 128 is not proof of the effective hardware CTUNE; DEVINFO/manufacturing values can override it.
- Actual recovery `sli_clock_manager_hal_init` at `0xD9F4` starts directly with `CMU_HFRCODPLLBandSet` at `0xD9F8`, followed by HFRCOEM23. There is no HFXO initialization preceding it.
- Actual full main initializes HFXO before the matching HFRCO setup. Its HFXO disable wait is at `0x42B4`, crystal readiness/core-bias wait at `0x42EE`, and FSM-lock wait at `0x42FC`. These unbounded waits precede CPC initialization. It later clears FORCEEN at `0x431E-0x4320`; this is startup/optimization, not a request to run SYSCLK from the crystal.

Retained SDK `platform_core/platform/service/clock_manager/src/sl_clock_manager_init_hal_s2.c:898-901` includes `init_hfxo()` whenever HFXO exists and HFXO_EN equals 1, before HFRCO setup at line 906 and clock branches at 928. `init_hfxo()` calls `SystemHFXOClockSet`, `CMU_HFXOInit`, and `CMU_HFXOPrecisionSet` at lines 292-294. This does not require installing RAIL. RFFPLL/USBPLL blocks are separately chip-presence guarded at 917-924; verify the resulting MG21 linked image contains only the intended additional HFXO path.

Recovery tree config line 48 explicitly resolves AUTO to HFRCODPLL, with SYSCLK using that default at line 87 and PCLK minimum divider at line 107. Its linked writes at `0xDA1A-0xDA38` confirm HFRCODPLL SYSCLK and divide-by-two PCLK, matching the full candidate. Enabling HFXO alone should not change those selections. The earlier UART/PCLK audit in `BOOT-COMPARISON-20260920.md` found no nominal divisor mismatch.

## Remaining full-image startup paths

Generated full `autogen/sl_event_handler.c:57-80` adds protocol crypto mask seeding, RAIL utilities, `sl_ot_sys_init`, and `sl_ot_init`; recovery `evidence/generated-sl_event_handler.c:47-61` has only the common CPC/PSA/SE service initialization and empty stack/application hooks. Common platform hooks are full lines 39-45 versus recovery lines 30-36. Identical hook lists do not imply all earlier startup is identical: full also includes MPU, OT crash handling, and LTO components absent from recovery.

### Protocol crypto

SDK `platform_core/platform/security/sl_component/sl_protocol_crypto/src/sli_radioaes_management.c:88-124` only creates a lock under `SLI_PSEC_THREADING`. The bare-metal full image has no surviving independent protocol-crypto-init call; no missing mutex prerequisite is established.

The meaningful extra operation is `sli_aes_seed_mask`, inlined as a call to `sli_radioaes_acquire` at full `0x4976`. That linked function:

1. Enables the radio clock through `CMU->RADIOCLKCTRL` at `0x25732-0x2573C`.
2. Busy-waits on RADIOAES FETCHERBSY/PUSHERBSY/SOFTRSTBSY at `0x25760-0x25766` on the normal, non-ISR path.
3. Obtains the initial mask through `psa_generate_random_internal` at `0x25770-0x25776`; that function invokes `se_get_random` at `0x9CB4` once PSA state is initialized.

This is a concrete extra pre-mainloop hardware path and potential wait location, not evidence that it actually failed. PSA initialization is present before it at full `0x4972`, and CPC security also initializes PSA internally (`sl_cpc_security.c:191`, linked full `0x4D6A`). Do not infer an initialization-order bug simply because the generated service list begins with CPC. Source mask-generation assertions at `sli_radioaes_management.c:71-72` do not survive as a checked branch in this linked function; do not claim an observed assertion there.

### RAIL and OpenThread

The full candidate does perform radio initialization:

- `sl_openthread_init` is called at `0x49E0`; its linked implementation at `0x1C0D8` invokes `RAIL_UnlockModule`.
- Radio FIFO/configuration setup precedes `sl_rail_init` at `0x4AFE`. Its return status is checked; a failure traps at `0x4B08`.
- Subsequent checks can trap at `0x4DA8` (calibration configuration), `0x4DB4` (PTI protocol), `0x4DC0` (IEEE 802.15.4 init), `0x4DCC` and `0x4DDA` (frame-pending support), and `0x4E0C` (null radio handle).
- Later Thread entropy initialization reaches `se_get_random` at `0x4F04`, with failure handling before the main processing loop.

These linked paths explain why successful `sl_cpc_init` would still not guarantee a CPC reply: generated service processing (`sl_cpc_process_action`, full event handler line 88) runs only after the complete startup sequence. The reviewed code supplies radio unlocking and radio initialization; no evidence supports fixing this by blindly adding another RAIL initializer. Some RAIL implementation comes from the linked vendor library, so this bounded review is not a proof of all its internal prerequisites.

## Diagnostic controls and interpretation

The HFXO-only recovery variant is preferable to a full candidate with HFXO disabled: the latter still invokes radio paths that require the crystal and would introduce an invalid prerequisite. Changing CTUNE, SYSCLK, security, NVM layout, or compiler optimization together would spoil the first split.

Before accepting the diagnostic artifact, compare against the working recovery build: retain the same SDK/toolchain and source patches; confirm unchanged component catalog, normalized security/NVM/UART settings and generated event-handler sequence; confirm that only HFXO_EN changes intentionally; inspect linked HFXO CTUNE selection, waits, and SYSCLK/PCLK writes. Recovery and full candidate already differ in LTO, so a recovery pass cannot rule out full-image compilation/layout effects. Do not enable full-image LTO in this diagnostic merely to match the full candidate.

A successful version reply would establish that the HFXO-enabled recovery startup reaches communication under the tested boot sequence. The vendor initializer can skip reinitialization if inherited SYSCLK already uses HFXO, so this does not establish that every crystal wait executed. Later protocol-crypto/RAIL startup becomes the next investigative priority, while inherited-clock/timing interactions remain alternatives. It would not prove RF calibration, sustained crystal operation, full RCP behavior, or Thread operation.

Silence from the HFXO-only image, with controlled build comparison and equivalent trial handling, would strongly localize the added HFXO initialization or its interaction with startup. It still would not identify CTUNE as the cause or distinguish the three wait sites without an additional observation. Do not preemptively change CTUNE to the old fallback 140; the actual effective tuning value remains unknown.

If the HFXO-only variant passes, the smallest next source split is protocol-crypto initialization/mask seeding added to that proven baseline, after auditing the generated dependency changes. If dependency installation pulls in broad radio startup, use a separately reviewed explicit stage diagnostic instead. A full instrumented image can expose later assertion/wait locations more directly but adds UART/diagnostic infrastructure and timing changes; it is unnecessary for the first clean HFXO split.
