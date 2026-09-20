# Receive bootstrap candidate — unproved

This isolated candidate tests the initial DMA descriptor-load hypothesis documented in `../../RECEIVE-DMA-START-ANALYSIS-20260920.md`. It is derived from `../receive-snapshot`; all prior source and evidence are preserved. It is not an established production fix.

## Exact behavioral delta

Only the no-hardware-flow-control `restart_dma()` initialization changes. A static, explicitly four-byte-aligned, 16-byte `sl_hal_ldma_descriptor_t` is copied from descriptor0 after the existing seven-byte header count is configured. Only the copy's `xfer.link` and `xfer.done_ifs` bits are set. HAL initialization receives that stable bootstrap object; HAL start/enable remains. The subsequent live LINK/DONEIEN edits are removed.

The software head still points to descriptor0. The bootstrap has the same RXDATA source, destination buffer, count, absolute link mode and descriptor1 link address as descriptor0, with only those two enable bits changed. It is never a future link target. Both original descriptors retain their IRQ-disabled, link-disabled spill-buffer semantics and original mutual addresses. The hardware-flow-control branch retains the original HAL initialization call.

This avoids competing live register writes while the initial descriptor load is pending. It does not introduce a guessed LINKLOAD wait, delay or reset, nor change normal resize/recovery logic, clock, security, pin, UART or DMA channel assignment. It does not establish that every possible restart/resize race is solved. Existing stop/burst behavior and descriptor-reuse assumptions still require review.

## Preserved diagnostic and identity

All 101 fields, receive/core counters, committed-last first-bad validity, four-second nominal SysTick trigger, bounded terminal takeover and permanent halt are unchanged from receive-snapshot. The fixed record remains 929 bytes, format version1 and `@POST1` framing. The unique `build_id` is `0x52584231` (`RXB1`). `fields.json` is byte-identical to the previous schema; the parser rejects both earlier diagnostic discriminators even with valid CRCs.

The terminal diagnostic still adds timing/layout perturbation, cannot guarantee output under global interrupt masking or hardware faults, and adds no persistence writes; normal retained application code may write runtime storage. It exports metadata only, never payloads, keys or arbitrary RAM. Hardware acceptance requires successful CPC queries and disappearance of the observed resize/CRC failures, not merely a startup frame or terminal record.

## Guarding and checks

The pinned input driver/core hashes and prior exact-source guards remain unchanged. `bootstrap_restart()` requires the reviewed head/count/start structure, replaces exactly one HAL initialization and one no-flow live-edit block, and round-trips to the original function when its two changes are removed. The test verifies all text outside restart remains identical to the previous receive overlay.

Completed offline checks: four source-transformation/descriptor-invariant tests and five parser tests pass; Python syntax, unique101-field C/schema coverage, schema identity and UTF-8/LF checks pass. Tests use the exact retained SDK UART source, reject checksum drift and changed patch anchors, and cover the intended two-bit bootstrap descriptor delta. They do not simulate DMA hardware timing or prove the race.

Reproduce offline tests with the pinned SDK source available:

```sh
SDK_CPC_UART_SOURCE=/opt/silabs/sdks/simplicity_sdk_2026.6.1/cpc/src/sl_cpc_drv_uart.c python3 -m unittest test_instrument test_snapshot
```

Parent owns exact-target compilation, linked review, independent review, packaging and any separately authorized hardware trial. Before acceptance, confirm static RAM placement/alignment, copied descriptor fields, the absence of post-LINKLOAD live edits in restart, preserved HWFC path and ring targets, unchanged timer/takeover, and the RXB1 discriminator. No firmware build, device operation or commit was performed by the implementation worker.

## Parent verification

Exact target compilation and all9 tests pass. Generated configuration is byte-identical to the tested receive snapshot. Fresh independent source/linked review passes: bootstrap .bss0x20000e10, four-word copy after seven-byte setup, flags before HAL start/DMB, original two-descriptor ring/head mapping preserved, no later live LINK/CTRL edits in restart.

ELF SHA2568b5046f9d4cc7dedaecbdd4a3acd4cf2d57257834ab44164874b9ac049da31bd. Application-only GBL SHA2569b88fe804f87897091fee0a140dc68440ea26c170a36cae706ac38245b5dde60. Independent ELF/SREC/GBL byte equality, CRC and tag/page checks pass; program pages[0x4000,0x2c000), below NVM0xb4000, no bootloader/SE tags. Local packaging container stopped. Hardware behavior remains untested; see ../../RECEIVE-BOOTSTRAP-TRIAL-20260920.md for the separately approvable test.
