# Candidate startup comparison — 2026-09-20

## Result and scope

Offline comparison of the exact failed-trial candidate with the exact SONOFF rollback finds **no established firmware root cause or justified corrective patch**. Two real clock configuration differences exist, but the candidate calculates its UART divisor from the correct clock, and the differences do not by themselves explain silence. The working rollback also performs the potentially sensitive bootloader/security-state initialization that initially looked suspicious in the candidate.

This report concerns startup/clock/bootloader source and machine code. The parent investigation owns flash-launch behavior, transport capture, probe compatibility, and the interpretation of trial logs. A failed CPC probe does not locate the failure or prove execution never reached the application. No new device operation, build, image publication, or production access was performed for this comparison.

Inputs:

- Candidate GBL: `firmware/package/output/rcp-sdk2026-application-only.gbl`, SHA256 `b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50`.
- Candidate ELF: `firmware/candidate-clean/artifacts/rcp-uart-802154.out`, recorded SHA256 `165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74`. Source-interleaved disassembly is `firmware/candidate-clean/evidence/disassembly.txt.gz`.
- Working rollback: `recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl`, SHA256 `40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787`.
- SDK sources were read from stopped container `sisdk-upgrade-trial-20260914`, under `/opt/silabs/sdks/simplicity_sdk_2026.6.1/`. The container was not started or modified. `docker cp ... -` streamed selected files into memory.

All hexadecimal addresses below are firmware load addresses, not GBL file offsets. Rollback function identities are inferred from their instructions and register operations because its GBL contains no symbol table. Candidate names and source annotations come from its ELF disassembly. Reproducible analysis: decode ordinary GBL ERASEPROG payloads into their addressed bytes; fill the unprogrammed alignment gap with `0xff`; disassemble as ARM Thumb with origin `0x4000`. The retained builder's ARM objdump 2.43.1.20241119 was copied to a temporary directory and used for this; no compiler ran. Temporary working files are at `/tmp/sdk2026-boot-wqdl5g39/` in WSL, not required inputs for reproduction.

## Clock comparison

| Property | Working SONOFF rollback | Candidate | Finding |
| --- | --- | --- | --- |
| HFXO frequency | 38.4 MHz, literal at `0x8b58` | 38.4 MHz | Same nominal crystal frequency |
| CTUNE preference | DEVINFO, manufacturing token, fallback | DEVINFO, manufacturing token, fallback | Same selection hierarchy |
| CTUNE fallback | 140 at `0x8a24–0x8a2a` | 128 at `0x4b2a–0x4b2e` | Real difference; effective value unknown |
| Main system clock | HFXO, CLKSEL=3 at `0x8a62–0x8a6e` | HFRCODPLL, CLKSEL=2 at `0x43c6–0x43d0` | Real difference |
| HCLK/PCLK dividers | HCLK /1, PCLK /1 at `0x8a74–0x8a7a` | HCLK /1, PCLK /2 at `0x43e8–0x43f2` | Candidate nominal PCLK is 40 MHz |
| Blocking HFXO waits | `0x74c8`, `0x754e`, `0x755c` | `0x42b4`, `0x42ee`, `0x42fc` | Both contain equivalent types of hardware-ready wait |

The rollback clock-init routine starts at `0x89fc`. Its DEVINFO MODULEINFO test is at `0x8a14–0x8a1c`, DEVINFO MODXOCAL branch at `0x8b1e`, manufacturing-token read at `0x8a1e–0x8a22`, and fallback selection at `0x8a24–0x8a2a`. Candidate equivalent paths are at `0x4260–0x4270` and `0x4b26–0x4b30`. The manufacturing address is `0x0fe00100` in both. Both add the chip-dependent CTUNE delta and saturate the result.

The rollback HFXO initializer at `0x74a0` receives its base configuration from the 40-byte structure at `0x38f3c`:

```text
0b0000000b000000020000000000202000000000030000008c8c3c00000000000000000000000000
```

Following the actual field accesses in that initializer reconstructs initial XTALCFG `0x0bb00820`, matching the candidate literal at `0x44c4`. The crystal mode, core-bias setting 60 and steady-state timeout 2 likewise match the candidate instructions. This is evidence against an entirely different HFXO startup recipe; it is not a claim that all clock-related behavior is identical.

The candidate generated tree header defines AUTO as HFRCODPLL, even though a nearby configuration comment describes choosing HFXO when a radio is present. The linked instructions settle the effective value: the candidate uses HFRCODPLL. See `firmware/candidate-clean/config/sl_clock_manager_tree_config.h`, oscillator settings in `sl_clock_manager_oscillator_config.h:72,78,84,105`, and the addresses above. Treat the stale-looking comment as documentation, not proof that the generated setting is faulty.

### UART clock calculation is internally consistent

Candidate `uart_drv_hw_init` at `0x68a8` calls the clock-frequency helper with branch 3 at `0x68cc–0x68d0`. The table in `sli_clock_manager_hal_get_clock_branch_frequency.isra.0` at `0x25f34` sends branch 3 to `CMU_ClockFreqGet(cmuClock_PCLK)` at `0x25f6a`. Its divisor arithmetic at `0x68d4–0x6928` uses 115200 baud, 16-times oversampling, and the returned peripheral clock.

With the configured 80 MHz HFRCODPLL and PCLK /2:

```text
PCLK = 40,000,000 Hz
fractional_divisor = floor((32 * PCLK + (16 * 115200)/2) / (16 * 115200)) - 32
                   = 662
CLKDIV register = 662 << 3 = 5296
nominal baud = 40,000,000 / (16 * (1 + 662/32))
             = 115,273.775... (+0.0640% versus 115200)
```

This is nominal arithmetic, not a measured baud rate. It rules out the simple claim that firmware calculates the divisor for 38.4 MHz while actually clocking the UART at 80 MHz. Retained SDK `platform_core/platform/emlib/src/em_cmu.c:102` defines maximum PCLK as 50 MHz; the configured 40 MHz does not violate that check. The SDK's `pclkDivOptimize()` around line 5379 selects /2 above the limit.

GPIO/USART bus-clock enable calls disappearing under optimization are also expected: `platform_core/platform/service/clock_manager/src/sl_clock_manager_hal_s2.c:539` deliberately performs no register write for Series-2 config 1, which is this MG21 target. That observation is not a missing-clock bug.

Consequences: neither the SYSCLK difference nor the CTUNE fallback difference warrants changing the firmware on its own. CTUNE 128 versus 140 matters only if DEVINFO and manufacturing calibration are unavailable, and no such device-state evidence was collected. Changing both at once would also obscure causality.

## Bootloader/security-state comparison

The rollback calls its bootloader initialization at `0x4bf6`; that routine starts at `0x4fd0` and invokes the resident bootloader's `init` function through the table at `0x5016`. The candidate likewise invokes resident `init` at `0x47be`, before CPC setup. Thus merely calling Gecko 1.12 from an application is not a newly introduced behavior.

The rollback already has security-state save/reconfiguration and restoration helpers at `0x4db8` and `0x4f20`. Its fallback USART detection checks USART0/1/2 at `0x4eb2–0x4edc`. Candidate compiled mitigation likewise appears in the early bootloader path, including the USART checks around `0x4d10–0x4d36`. Both contain peripheral-security mitigation rather than blindly assuming a modern resident bootloader.

Candidate generated `firmware/candidate-clean/config/btl_interface_cfg_s2c1.h` enables the old-bootloader fallback (`BOOTLOADER_DISABLE_OLD_BOOTLOADER_MITIGATION=0`, line 29) and NVM3 fault handling (`BOOTLOADER_DISABLE_NVM3_FAULT_HANDLING=0`, line 36), with manual security overrides disabled (line 48). Retained SDK `bootloader/platform/bootloader/api/btl_interface_storage.c:653` checks valid pointers, the STORAGE capability and version >=1.11 before calling `getDMAchannel`. The optional peripheral-list API is capability-gated. These are evidence against a blanket inference that SDK2026 simply requires Gecko2 or a new bootloader.

This does not prove every new bootloader-interface path is compatible with the installed SONOFF image. There is no exception trace, PC sample, resident bootloader dump or runtime status to identify a failure inside that path. A bootloader upgrade is therefore not a supported fix.

## Initialization and observability

`firmware/candidate-clean/autogen/sl_event_handler.c` establishes these second-stage dependencies:

1. Platform stage: clock runtime hook, bootloader initialization, DMA-manager initialization, NVM3 initialization (lines 39–45).
2. Services: CPC, mbedTLS, PSA, SE and protocol crypto (lines 57–65).
3. Stack stage: RAIL utilities and OpenThread system initialization (lines 67–75).
4. Internal application stage: OpenThread instance/NCP initialization (lines 77–80).
5. Main-loop service action: `sl_cpc_process_action()` (line 88).

Generated ordering alone is not evidence of a PSA bug. CPC security initialization calls `psa_crypto_init()` internally before using its storage/keys. CPC memory has an explicit first-stage permanent-allocation hook. Retained `cpc/src/sl_cpc.c:278` allocates per-instance memory; line 306 initializes each instance; `cpc/src/sl_cpc_instance.c:274` initializes hardware before starting receive; `sl_cpc.c` around line 2435 then starts system/security services in the bare-metal build. The generated UART instance points at the UART driver. No missing prerequisite was established in this wiring.

The rollback includes a kernel; the candidate uses the vendor example's bare-metal path. In that path, a failure after UART receive starts but before the main service loop could still prevent a CPC response. Candidate RAIL initialization occurs at `0x4afe`, and an SE entropy request appears at `0x4f04`. These are possible diagnostic stage boundaries, not identified failures. Enabling encrypted CPC also does not by itself mean an unbound radio cannot answer system-version queries; the parent investigation checks that protocol separately.

## Recommended next diagnostic and fix boundary

First resolve whether the existing trial actually commanded and verified application launch, using the parent investigation's flasher/log evidence. Offline boot analysis cannot substitute for that distinction.

If a future separately authorized physical split-test is needed, the already built CPC-only recovery application is a more useful starting point than an ungrounded CTUNE or bootloader change. Its recorded storage comparison covers the same target, UART, security and NVM geometry while omitting the normal candidate's RAIL/OpenThread initialization. The test would only ask for ordinary unencrypted CPC system properties; it must not invoke its unbind function. Its startup behavior and absence of automatic key deletion must remain explicitly verified from the exact retained artifact before use. A successful probe would show that this SDK's common platform/CPC path can run on the board and focus investigation on the additional normal-candidate path. A failed probe would still leave launch, platform and transport causes to separate. Neither outcome alone qualifies the upgrade.

If another build is necessary, prefer a diagnostic build that preserves clock, UART, security and storage settings, captures initialization return values, and identifies the last completed startup stage and hard-fault/reset reason through a deliberately chosen accessible diagnostic channel. Do not emit arbitrary text onto active CPC traffic. Choose the channel and collection method before building; otherwise a diagnostic image can remain as opaque as this one. Reuse existing SDK diagnostic hooks when they meet that requirement.

No corrective build is yet justified by this comparison. Keep the known-good rollback running while selecting the smallest experiment that distinguishes the remaining causes. Avoid speculative bootloader/SE updates, storage erasure, disabling CPC encryption as a purported fix, or simultaneous clock changes.
