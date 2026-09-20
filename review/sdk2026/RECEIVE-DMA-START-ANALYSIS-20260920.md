# Receive DMA start analysis — 2026-09-20

## Conclusion

The receive diagnostic proves that both DMA resize attempts failed the hardware-destination/software-buffer accounting check. This occurs before normal rearming and before the subsequent FIFO overflow. A concrete initialization hazard fits these findings: CPC starts an asynchronous descriptor load and then immediately changes the very hardware LINK/CTRL registers that the load populates.

The exact vendor HAL contract supports a narrow route that avoids this ordering hazard: prepare a separate static bootstrap descriptor containing the intended initial LINK and DONEIEN state before starting DMA. It does not support inventing a LINKLOAD readback wait from the register name alone. No corrective build or hardware validation has been performed, and the initial lost-write mechanism remains a hypothesis until tested.

## What the new snapshot establishes

The first header length and driver length are both 10, but received FCS `0x5599` and computed software CRC `0x3EB7` differ from the known valid host request. UART IF was `0x2002` at first header callback, payload callback and checksum failure: overflow was not yet latched at these observation points. RXOF appeared only later at the terminal snapshot.

There was one header callback, one payload callback, two resize attempts, two resize failures, no successful/already-received resize, and no recovery dispatch/run. `get_already_received_cnt` (`cpc/src/sl_cpc_drv_uart.c:1072–1083`) subtracts software-head destination from hardware DST and fails when the unsigned result exceeds the RX buffer bound. `resize_current_dma_descriptor:2311–2315` re-enables the channel and returns FAIL. Its caller does not establish a new descriptor size on that path. The equality guard at lines 2318–2321 already handles `already_recvd_cnt >= new_length`; this is not evidence for an equality underflow fix.

At terminal capture, hardware DST is descriptor1 destination + 8 while the software head is descriptor0. Both reusable descriptor link-enable bits are clear. Hardware LINK is the descriptor1 address with link-enable clear. These fields demonstrate a mismatch but do not preserve the initial buffer addresses or the state immediately before the first interrupt. Allocation/free reuse means the final addresses cannot uniquely reconstruct every earlier transition.

DMA manager source does not show a channel-zero callback indexing defect: `platform_core/platform/service/dma_manager/src/sl_dma_manager_hal_ldma.c:284–287` reads enabled pending and clears flags before dispatch; lines 303–308 select and clear each actual channel bit. `sl_dma_manager.c:625–628` invokes the registered callback for that channel. `SL_CLEAR_BIT` takes a mask (`platform_core/platform/common/inc/sl_bit.h:89`).

## Exact start hazard and linked difference

SDK paths are relative to `/opt/silabs/sdks/simplicity_sdk_2026.6.1` in the retained stopped builder.

`cpc/src/sl_cpc_drv_uart.c:548–559` creates two byte-transfer descriptors, clears both descriptor completion-interrupt bits, and writes their mutual absolute link addresses with link-enable false. They are reusable spill descriptors.

`restart_dma:2456–2481` selects descriptor0 as software head, sets its initial count to seven header bytes, calls HAL init/start/enable, and only afterward sets live channel LINK and CTRL.DONEIEN. The callback at 2066–2070 assumes that hardware has followed the link when it advances the software head.

Linked original full (`firmware/candidate-clean/evidence/disassembly.txt.gz`): start call at `0xBC32`, channel enable at `0xBC36`, LINK read/modify/write `0xBC38–0xBC3E`, DONEIEN read/modify/write `0xBC40–0xBC46`. Receive diagnostic: corresponding sequence `0xBD56`, `0xBD60`, `0xBD64–0xBD6A`, `0xBD6C–0xBD72`.

Passing crypto control (`firmware/cpc-crypto-diagnostic/output/evidence/disassembly.txt.gz`): start at `0x5BEE`, then an outlined enable-channel call at `0x5BF6` and index arithmetic before LINK update at `0x5C04`. This supplies a concrete timing difference; it does not by itself prove the race or exclude round-robin/channel-allocation/radio scheduling effects.

A plausible sequence is that initial descriptor loading overwrites the early live LINK enable while the later DONEIEN write survives. Seven header bytes can then produce an IRQ without the intended automatic link. The software head still advances, accounting fails, and re-enabling an exhausted transfer can produce another callback without a correct payload rearm. This matches the observed broad shape, but the snapshot does not prove this exact sequence.

## Supported vendor contract; no guessed wait

`platform_core/platform/peripheral/src/sl_hal_ldma.c:183–184` records the supplied descriptor address in channel LINK. `:242–257` performs a DMB to make earlier memory accesses visible, clears CHDONE, writes LINKLOAD_SET and returns. It does not wait for descriptor-load completion.

The corresponding header explicitly requires stable descriptor memory because the controller may load it at any time (`platform_core/platform/peripheral/inc/sl_hal_ldma.h:2336–2342`), and says its fields are loaded into hardware at the appropriate time (`:2353–2356`). This directly supports preconfiguring the descriptor, rather than relying on an undocumented delay before editing hardware registers.

A bounded search of the retained platform sources found no descriptor-load-completion wait idiom. Emlib `LDMA_StartTransfer` likewise writes LINKLOAD and returns (`platform_core/platform/emlib/src/em_ldma.c:328–332`). Other platform users wait for the entire transfer through CHSTATUS/CHDONE, unsuitable for an RX transfer waiting on host bytes. The MG21 generated header uses an `__IOM` declaration for LINKLOAD, but that C annotation is not the hardware access contract. Parent independently checked the primary [EFR32xG21 reference manual](https://www.silabs.com/documents/public/reference-manuals/efr32xg21-rm.pdf): section 25.7.19, printed page 838, explicitly marks LINKLOAD **W** and describes forcing a descriptor load and channel enable. There is no supported completion readback to poll. Section 25.3.2, printed pages 798–799, describes the hardware registers reflecting a loaded descriptor and states that hardware does not edit RAM descriptors. These manual findings support the static RAM descriptor route below; they do not establish that the observed failure was caused by the hypothesized race. Neither polling LINKLOAD until zero nor treating DMB/DSB as DMA completion is justified.

## Narrow candidate correction for review

Use one static, word-aligned `sl_hal_ldma_descriptor_t` bootstrap object (16 bytes). After the existing seven-byte setup:

1. Copy descriptor0 into the bootstrap object, preserving its source, destination, byte count, absolute link mode and descriptor1 link address.
2. Set only bootstrap `xfer.link=1` and `xfer.done_ifs=1`.
3. Pass the bootstrap object to `sl_hal_ldma_init_transfer`; keep software `rx_descriptor_head=&rx_descriptor[0]`.
4. Start/enable through the vendor APIs and remove the two post-start live LINK/DONEIEN edits in this no-flow branch.

The initial hardware transfer then receives its entire intended state from stable RAM. On first completion it links to descriptor1. The existing callback can still treat descriptor0 as the completed buffer because source/destination/count and next-descriptor address match. The two original descriptors retain their spill semantics; no extra node is placed in their mutual ring. The bootstrap is not a stack object and is not a future link target.

Do not simply set these bits permanently on descriptor0: it later serves as a spill descriptor, where an extra completion interrupt or automatic link would change existing behavior. Do not set then immediately clear RAM bits after starting; that recreates the asynchronous-load race in memory.

Before a candidate build is accepted, review exact old/new descriptor values, word alignment, static lifetime, no new ring links, unchanged no-flow resize/recovery logic, and restart behavior. The existing stop operation completes an outstanding burst asynchronously; this candidate removes the startup live-register overwrite hazard but should not be described as a general proof of all restart/resize synchronization. A startup-only implementation can keep broader recovery changes outside the experiment if needed.

The smallest useful experiment is this single initialization change in the existing receive diagnostic, retaining its counters and known valid host query. Success would require a valid matched CPC version reply within the bounded query operation (one attempt, conditional retry) plus disappearance of resize failures/checksum mismatch, not merely a startup frame. Failure would leave the initial-link-load hypothesis unconfirmed and preserve evidence for later handoff analysis. Hardware validation needs separate authorization; no build, live operation, commit or speculative source edit was performed in this analysis.
