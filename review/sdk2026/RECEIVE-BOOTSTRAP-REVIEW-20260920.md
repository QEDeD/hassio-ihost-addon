# Receive bootstrap independent review - 2026-09-20

No blocking source or linked-code finding for the proposed bounded startup diagnostic. This is not production acceptance or authorization to flash. Packaging identity and recovery procedure verification remain the parent's responsibility.

Reviewed exact ELF SHA256: `8b5046f9d4cc7dedaecbdd4a3acd4cf2d57257834ab44164874b9ac049da31bd`, from `firmware/receive-bootstrap/output/artifacts/rcp-uart-802154.out`. Reviewed its linked disassembly and symbols, the generated UART overlay, candidate recipe, previous receive diagnostic, retained SDK HAL/CPC source and the proposed trial.

## Source and linked findings

- The bootstrap is static RAM at `0x20000e10`, in `.bss`, word-aligned, with a compile-time 16-byte size check. Original descriptors remain at `0x20000df0` and `0x20000e00`. At `restart_dma+0x5c` (`0xbd38`) the compiler forms the bootstrap address, then copies all four descriptor0 words at `0xbd3c-0xbd40`.
- The original seven-byte transfer count is set before that copy. Linked writes set only LINK bit1 (`0xbd4a-0xbd4e`) and DONEIEN bit20 (byte2 bit4, `0xbd58-0xbd5c`) in the copy. At first start this changes CTRL `0x03000060` to `0x03100060` and LINK `0x20000e00` to `0x20000e02`; source remains USART0 RXDATA `0x50058024`, and destination remains the same runtime-allocated buffer.
- HAL initialization receives the bootstrap address at `0xbd62-0xbd6e`. The start call at `0xbd78` reaches DMB at `0x157e2`, CHDONE clear at `0x157ee`, and LINKLOAD_SET at `0x157f0`. After return, restart only enables the channel and restores interrupt state; no live LINK/CTRL edits remain there. DMB provides memory ordering, not descriptor-load completion.
- Linked ring initialization preserves descriptor0 -> descriptor1 -> descriptor0, with spill link/IRQ enables clear. The bootstrap is not a future ring target. The software head is still descriptor0; the callback reads its completed buffer and advances through its absolute link at `0xbe66-0xbe7c`. Therefore the first bootstrap completion maps to the same software buffer and next descriptor as intended previously.
- Source changes beyond the previous receive overlay are confined to restart initialization. The HWFC branch retains its original initialization call; it is not hardware-tested or separately built by this review. Normal no-flow resize and recovery logic remain unchanged. `fields.json`, `snapshot.h` and `capture-launch.py` have identical hashes to receive-snapshot; `snapshot.c` differs only in the RXB1 build discriminator.

The exact SDK requires stable descriptor memory and supplies DMB before starting; its stop function disables channel/interrupts and permits the current AHB burst to finish asynchronously. The [MG21 reference manual](https://www.silabs.com/documents/public/reference-manuals/efr32xg21-rm.pdf), sections 25.3.1.6-7 and 25.7.19, supports word-aligned absolute descriptor loading and marks LINKLOAD write-only. No guessed completion polling is justified.

## Limits and sufficient next validation

Restart reuses the static bootstrap after the existing asynchronous stop. This preserves an unproven wider stop/reinitialization assumption; it does not block a bounded initial-start test, but success cannot establish restart/recovery correctness or prove the original lost-write cause. The correction is justified as a narrow intervention that removes a source-grounded initialization hazard. Timing and layout changes remain alternative contributors to any improvement. The synthetic Python descriptor tuple test alone does not prove compiled layout; the linked checks above supply that evidence.

One material acceptance ambiguity was corrected in the trial and analysis: the adapter schedules one query with a conditional retry. First-attempt success produces only one request/reply, so a second reply must not be required. Require at least one valid matched CPC version reply within that bounded operation, a valid RXB1 record/schema/CRC, no resize failures and no invalid payload checksum; inspect callback/recovery state and any actual retry. A startup announcement alone is insufficient. Restore original firmware regardless of diagnostic success because the image halts after capture. A normal non-halting image and separate authorized functional validation remain necessary for upgrade acceptance.

Review performed offline; no device access, firmware upload, service action or commit. The only reviewer mutation is this review document.
