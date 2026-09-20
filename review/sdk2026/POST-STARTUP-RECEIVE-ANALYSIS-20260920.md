# SDK2026 post-startup receive analysis — 2026-09-20

## Finding and limit

The terminal snapshot establishes continued main-loop execution, a completed startup TX interrupt, and two RX DMA callbacks. One buffer reached CPC core and failed its payload checksum. It does not establish which host attempt that buffer represented, nor whether its bytes or length were wrong before DMA, at the descriptor handoff, or afterward. No firmware fix is established by this audit.

The strongest additional evidence is a UART receive overflow and a full, unread receive FIFO at the four-second snapshot. This places the next investigation in the no-flow UART/DMA receive path. It does not prove that overflow caused the first checksum failure: the overflow might instead follow a descriptor problem or arise during the retry.

## Exact checksum path

All SDK paths below are relative to `/opt/silabs/sdks/simplicity_sdk_2026.6.1` in the retained stopped builder. Reads used Docker copy only; no container start or live serial access.

- `cpc/src/sl_cpc.c:3498–3502`: successful driver read increments core `rxd_frame`.
- `:3636–3647`: subtract two FCS bytes, extract the received FCS, validate the remaining payload, then increment `invalid_payload_checksum` on mismatch.
- `:3651–3658`: invalid unnumbered frames are dropped without a reply. This accounts for silent rejection of a version query.
- Full, crypto-control and snapshot catalogs all omit `SL_CATALOG_CPC_DRIVER_HW_CRC_PRESENT`. The selected function is `sli_cpc_validate_crc_sw`.
- `cpc/src/sl_cpc_crc.c:165–173`: local CRC initialized to zero, byte-wise software calculation, comparison to expected FCS. There is no GPCRC, crypto engine, RAIL state or shared hardware-CRC dependency in that calculation.
- Original full linked evidence `firmware/candidate-clean/evidence/disassembly.txt.gz`: software validator at `0x62B8`, byte calculation at `0x6284`.

Parent independently verified both host attempts contain the same valid 17-byte version request, declared length 10, header CRC `0xD355` and payload CRC `0x12DB`; the same bytes succeed against official 4.6.0. This rejects malformed host construction as the current explanation, but does not prove bytes arriving at the MCU equal the host log.

## Snapshot register interpretation

Exact device definitions: `platform_core/platform/Device/SiliconLabs/EFR32MG21/Include/efr32mg21_usart.h` and `efr32mg21_ldma.h`.

- USART IF `0x201E`: RXOF (bit 4), RXFULL (bit 3), RXDATAV (bit 2), TXBL and TXIDLE. Header lines 916–926 name the receive flags. No parity/framing-error bits are set in this snapshot.
- USART STATUS `0x21E3`: RX enabled, TX enabled, TX complete, TX buffer available, RX data available, RX FIFO full and TX idle. RXDATAV/RXFULL definitions are lines 610/615.
- This overflow flag cannot merely be inherited unchanged from the bootloader: `cpc/src/sl_cpc_drv_uart.c:535–539` clears RX/TX and all UART interrupt flags during driver initialization. Independently, `sl_hal_usart_init_async` calls reset (`platform_core/platform/peripheral/src/sl_hal_usart.c:88–90`), whose line 427 clears IF.
- RX channel 0 CTRL `0x03000000`: fixed source, incrementing destination, byte transfer, encoded XFERCNT zero and DONEIEN clear. LDMA header lines 525–526 and 566 define count and interrupt enable. Zero is a hardware count encoding; do not equate it alone with a software byte count.
- Channel 0 remains enabled (`CHSTATUS=1`) and has its done bit set (`CHDONE=7`); no channel is busy, request-disable is zero, and DMA global status reports no request/busy. Meanwhile UART FIFO remains full. The snapshot lacks channel LINK and software descriptor/recovery state, so it cannot distinguish a deliberately loaded spill descriptor from an exhausted or incorrectly resumed descriptor.
- `LDMA.IF=4` is channel 2; its bit is not enabled in `IEN=3`. This alone is not proof of an error or RAIL collision.

## Full versus passing control: bounded comparison

The exact generated UART config is identical between original full and passing crypto control. Both use the same vendor no-flow USART RX path and byte descriptors. Full CPC TX/RX buffer counts are 15 versus 20 in the control; there is no observed driver-error/drop counter evidence of starvation, although those counters do not cover every internal allocation branch. Full also has DMA round-robin/RAIL components and a different channel assignment; prior allocation/vector audits did not establish a collision.

Shared source path:

1. `sl_cpc_drv_uart.c:481–485`: peripheral RX/TX request configurations.
2. `:548–560`: two single P2M byte descriptors, both descriptor DONE interrupt bits cleared initially, absolute mutual links, head descriptor 0.
3. `:2458–2481`: restart sets first transfer to a seven-byte header, initializes/starts/enables DMA, then enables live channel linking and completion interrupt.
4. `:2050–2071`: completion uses the old head buffer, restores its maximum count and advances the software head to follow the hardware link.
5. `:2146–2195`: copies and validates a header, reads its payload length, resizes the next DMA transfer.
6. `:2227–2255`: attaches completed payload buffer, resizes for the next seven-byte header, queues the completed frame.
7. `:2287–2352`: resize disables the channel, reads current CTRL and received count, updates count/LINK/DONEIEN, disables linking in the next descriptor, then enables the channel again. `:2303–2307` explicitly notes that disabling does not abort previously queued transfers.
8. `:1072–1083`: received count is current hardware DST minus software-head descriptor destination. `:1114–1133`: recovery dispatch deliberately disables linking/completion IRQ while deferred recovery runs.

Original full linked resize at `0x6392` and passing crypto-control resize at `0x6170` both implement the same disable/read/count/update/link/enable sequence. Full inlines HAL/atomic operations and removes assertions; control has calls/assertions. Full linked count guard is `0x6334`, control `0x6134`. No incorrect mask, count formula or missing mandatory write was established by this bounded comparison. Timing/code layout, radio/DMA scheduling, buffer count and assertion differences prevent treating control success as proof that every handoff timing is identical.

## Smallest useful next evidence

Do not substitute a hardware-CRC workaround: this image uses software CRC. Do not infer a global hang, missing TX interrupt, or missing UART RX IRQ from the original silence; the snapshot disproves those broad explanations for this trial.

Before another image, use the existing linked full/control evidence to constrain a small host-side model of the no-flow descriptor handoff: header length 7, declared body length 10, two sequential host attempts. Exercise ordinary, already-received/spill, and count-out-of-range branches; explicitly model that a disable write does not flush queued DMA work. This can verify instrumentation/branch expectations, but cannot validate the MCU DMA timing or establish a silicon defect.

If further device evidence is authorized later, extend the existing terminal snapshot narrowly, without streaming during CPC ownership:

- First bad frame: header-declared length, driver data_length, extracted FCS, software computed CRC; no payload bytes.
- RX header/payload callback counts separately; resize calls and outcome counts (`OK`, `ALREADY_EXISTS`, failure), first/last requested size and already-received count.
- Recovery dispatch and completion counts plus scalar state (`header_expected_next`, `next_rx_size`, out_of_sync/misaligned/recovery_completed flags).
- At the existing terminal snapshot: live RX LINK plus both reviewed static descriptors' CTRL/DST/LINK and head index. Only fixed known metadata, never arbitrary pointer dereferences.
- To order overflow relative to the bad frame, sample UART IF into the first header/payload and first checksum-failure records. Reading IF does not clear it.

These fields distinguish length/buffer corruption from a spill/recovery or descriptor-rearm failure and locate overflow before or after the rejected frame. Additional reads and counters perturb ISR timing; preserve original failure reproduction and do not call a changed result a fix. No new build, device action or speculative source fix was performed here.
