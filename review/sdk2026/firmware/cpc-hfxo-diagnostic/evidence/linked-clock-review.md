# Linked clock review — HFXO-only CPC diagnostic

Reviewed offline on 2026-09-20. Result: the requested HFXO initialization is linked and called before normal CPC startup; subsequent SYSCLK/HCLK/PCLK settings and UART clock selection remain equivalent to the working CPC-only recovery image. This validates the intended clock split, not execution on hardware.

## Evidence identity

- Diagnostic: `../output/artifacts/cpc_secondary_vcom_security_device_recovery.out`; independently computed SHA-256 `fa14fd55f8e16ef6729572eb4d1dbc63c0b17762b6da640bf34352cbb4f3f913`.
- Diagnostic inspection: retained `../output/evidence/disassembly.txt.gz`, `symbols.txt`, and ELF constant data.
- Baseline: `../../cpc-recovery/output/artifacts/cpc_secondary_vcom_security_device_recovery.out`, read with retained GNU Arm objdump. Addresses below are linked virtual addresses, not file offsets.
- Parent reports source/config/autogen comparison differs only in HFXO_EN=1 and its configuration checksum. This review independently verifies consequential linked clock behavior; it does not repeat that entire source comparison.

## HFXO initialization and tuning selection

`sl_main_init` calls `sl_clock_manager_init` at diagnostic `0x11F6C`; that dispatches to `sli_clock_manager_hal_init` at `0xDC00`. Unlike baseline `0xD9F4`, which begins directly with HFRCO setup, the diagnostic first:

1. Reads DEVINFO MODULEINFO at `0xDC1A` and MODXOCAL at `0xDC24`, extracting the CTUNE XI byte.
2. Falls back through the manufacturing token at `0xDD50-0xDD52`, using address `0x0FE00100` from the literal at `0xDD80`.
3. Uses configured fallback **128** if the manufacturing halfword exceeds 255 (`0xDD54-0xDD58`).
4. Stores XI at `0xDC2A`, applies `CMU_HFXOCTuneDeltaGet` and saturates XO to eight bits at `0xDC2E-0xDC3A`.
5. Sets the HFXO frequency to **38,400,000 Hz** (`0xDC38-0xDC3E`, literal `0x0249F000`), calls `CMU_HFXOInit` at `0xDC44`, and sets precision 50 ppm at `0xDC48-0xDC4A`.

The copied default HFXO structure at `0x138E0` is 40 bytes:

`0b0000000b000000020000000000202000000000030000008c8c3c00000000000000000000000000`

Its initial CTUNE bytes 140/140 are overwritten by the selection above before initialization. They do not mean the diagnostic changed fallback 128 to 140. The effective board CTUNE remains unknown without observing the selected hardware/token values.

`CMU_HFXOInit` at `0xB184` contains the expected waits:

| Purpose | Diagnostic address | Corresponding full candidate address |
| --- | --- | --- |
| Wait for HFXO disabled | `0xB24A-0xB24E` | `0x42B4-0x42B8` |
| Wait for ready/core-bias optimization (mask `0x40010003`) | `0xB2E2-0xB2E8` | `0x42EE-0x42F4` |
| Wait for FSM lock cleared | `0xB2F0-0xB2F4` | `0x42FC-0x4300` |

The crystal mode and startup parameters select the crystal optimization path. The default structure leaves force-enable/dis-on-demand false; the initializer clears these controls afterward (`0xB30C-0xB31C`) as in the full candidate. No RAIL or RF PLL startup was added to the inspected clock-manager function.

## CPU/peripheral clocks remain unchanged

| Operation | Working CPC baseline | HFXO diagnostic | Meaning |
| --- | --- | --- | --- |
| HFRCO band setup | call `0xD9F8`, literal `0xDAF8=0x04C4B400` | call `0xDC50`, literal `0xDD68=0x04C4B400` | 80 MHz |
| SYSCLK selection | `0xDA1A-0xDA26` | `0xDC72-0xDC7E` | Clear CLKSEL bits, set value 2: HFRCODPLL |
| HCLK/PCLK dividers | `0xDA2C-0xDA38` | `0xDC84-0xDC90` | Same mask `0x3400`, value `0x400`: HCLK /1, PCLK /2 |

Consequently nominal SYSCLK/HCLK remain 80 MHz and PCLK remains 40 MHz. The remaining clock-branch writes also retain their prior masks/values; address relocation and function prologue size changes are expected.

UART initialization remains at `0x6AD4` in both images. At `0x6B26-0x6B28` it reads the same branch identifier 3 and queries its frequency; at `0x6B38` it requests 115200 baud. The linked clock-branch structure is byte-identical (`0080055003000000`, baseline `0x13678`, diagnostic `0x13920`), selecting USART0 at `0x50058000` and PCLK. Branch 3 resolves through the same jump-table entry to `CMU_ClockFreqGet(3)` (baseline `0x12800`, diagnostic `0x12A74`). The 24-byte UART configuration/pin constant block is also identical (baseline `0x135D0`, diagnostic `0x13850`). No UART divisor-source change was found.

## Interpretation limits

- **Inherited-clock guard:** the initializer checks the current SYSCLK and returns immediately if it is already HFXO (`0xB228-0xB230`, return `0xB32C`). The full candidate has the same guard (`0x4294-0x429A`). A CPC reply therefore establishes that this configured startup path returns, but without evidence of the inherited clock state does not prove every crystal optimization wait executed. Use equivalent bootloader/reset entry conditions when comparing outcomes.
- The diagnostic preserves the working recovery build's optimization behavior. It is not a byte-identical transplant of the full candidate's LTO-inlined implementation. The additional code changes layout and stack use; the HFXO-enabled clock-manager function allocates 44 local stack bytes for its initialization structure.
- Source/linked verification cannot prove crystal stability, the effective CTUNE, absence of faults, or full RCP/RF behavior. No build or device access was performed by this review.
