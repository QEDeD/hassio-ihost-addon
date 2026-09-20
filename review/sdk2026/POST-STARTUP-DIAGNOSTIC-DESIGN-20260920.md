# Full-image post-startup diagnostic design — 2026-09-20

Status: offline design only. No firmware implementation, build, upload or production change is performed by this review. Parent owns integration and authorization. This diagnostic is deliberately terminal, not a production fix.

## Implemented refinements

The parent subsequently built, packaged and independently reviewed this design; no hardware trial has occurred. The implementation deliberately omits stacked-PC/LR capture. The exact MG21 is Series2 configuration1: vendor clock-manager HAL reports module bus clocks always enabled, and its CMU has no CLKEN0 register. The proposed CLKEN0 guards below are therefore superseded by a CONFIG1 compile guard and bus_clock_ungated=1 architectural marker; no clock write was added. The final71-field schema in firmware/post-startup-snapshot/fields.json and POST-STARTUP-DIAGNOSTIC-REVIEW-20260920.md are authoritative for the built artifact. The diagnostic adds no persistence writes; retained application runtime may still write NVM.

## Purpose and evidence

The uninstrumented full SDK2026.6.1 image emits one valid CPC startup reset-status frame about 62 ms after RUN. It does not answer version GETs on that same connection at approximately 250 ms or 30 seconds, or after reopening. Passing CPC/HFXO/crypto controls answer. The full startup-trace image completed all initialization markers. These observations leave post-startup RX, TX completion, processing progress and subsequent fault/IRQ behavior unresolved; they do not demonstrate a vendor source defect.

Collect RAM-only evidence during normal execution, then take one terminal snapshot four seconds after app initialization and transmit a fixed allowlisted record over the existing USART0 PB1 TX at 115200. No raw markers share the running CPC transport. The existing host connection sends only its early version queries and captures through six seconds. No reset, binding, unbinding, storage write or normal host stack is part of the diagnostic.

## Why this mechanism

- Vendor core counters exist: `cpc/inc/sl_cpc.h:277–293`, `cpc/inc/sli_cpc_debug.h:194–201`. Enable only `SL_CPC_DEBUG_CORE_EVENT_COUNTERS=1` in the existing CPC config. Leave endpoint, allocator and SystemView counters disabled.
- Vendor `PROP_CORE_DEBUG_COUNTERS` retrieval exists (`cpc/src/sl_cpc_system_secondary.c:786–801,1276–1279`), but depends on the failed receive/reply path. It cannot be the only export mechanism.
- Vendor journal is primarily a RAM circular buffer; its print facility requires IOStream (`cpc/src/sl_cpc_journal.c:56–64,117–141`). Adding journal, IOStream and another UART owner is larger and less useful for this first discrimination.
- Sleeptimer callbacks run in interrupt context (`platform_core/platform/service/sleeptimer/inc/sl_sleeptimer.h:967–970`). The existing RTCC priority does not independently escape a stuck equal-priority handler. Use an otherwise unowned SysTick at priority 0 for this diagnostic.
- Original full binary vector 15 is `0x130C1`, the default infinite-loop handler. Its only linked SysTick reference found is a clock-frequency query reading CTRL. No kernel/power-manager component is present. Verify these assumptions again in the diagnostic ELF.

## Timer and arming

Arm once at the end of `app_init`, after all platform/service/radio/OpenThread initialization and immediately before normal processing. Preserve the existing source/configuration and LTO settings otherwise. Do not add early raw-UART initialization or startup marker output just to arm this timer.

Use direct CMSIS SysTick registers and a strong `SysTick_Handler`, not the generic interrupt-manager dynamic registration API (the existing vector table is in flash). Disable SysTick, reject an unexpectedly enabled inherited timer, clear its pending exception, set priority 0, install a valid reload/value and enable core-clock source, timer and timer interrupt. Independent linked review must confirm the vector points to the new handler and that initialization cannot subsequently reset its priority to 5.

Use `CMU_ClockFreqGet(cmuClock_CORE)` once during arming, rather than trusting a cached `SystemCoreClock` variable. Exact MG21 emlib implementation returns `SystemHCLKGet()` (`platform_core/platform/emlib/src/em_cmu.c:926–931`; enum in `em_cmu.h:289`). Program `reload = core_hz / 10 - 1`, with explicit nonzero and 24-bit range checks, for 100 ms nominal periods. Forty delivered ticks trigger the dump. At the candidate's nominal 80 MHz, reload is 7,999,999 and fits 24 bits.

The timer's operation does not depend on the `SystemCoreClock` C variable. Its real-time interpretation still depends on correct clock-frequency reporting and an unchanged core clock. Record core_hz, reload and the live CMU clock-selection/prescaler registers. Missed/coalesced SysTick exceptions can delay the nominal four-second deadline. Forty delivered ticks are not a proof of four seconds of uninterrupted execution.

For the first 39 ticks, perform only a bounded counter increment and return. No allocation, CPC/RAIL APIs, locks, formatting, serial output or clock-manager calls in this high-priority path.

## RAM instrumentation and exact hooks

Use naturally aligned `volatile uint32_t` fields and simple stores/increments. No logging, allocation or new critical sections in these hooks.

1. In generated `sli_service_process_action`, write phase CPC_ENTER and increment cpc_enter just before `sl_cpc_process_action`; write CPC_EXIT and increment cpc_exit immediately after it. Existing generated file is `firmware/candidate-clean/autogen/sl_event_handler.c:86–89`.
2. In application `app_process_action`, write TASKLETS_ENTER before `otTaskletsProcess(sInstance)`, then TASKLETS_EXIT after return; write DRIVERS_ENTER before `otSysProcessDrivers(sInstance)`, then DRIVERS_EXIT and increment full_loop_done after return. Keep one counter for completed tasklet processing and one for completed driver processing. Existing SDK driver order is `openthread/platform-abstraction/efr32/system.c:125–145`.
3. Add TXC entry/exit counters inside the real TXC-flag branch of `CPC_UART_ISR_TX_HANDLER` (`cpc/src/sl_cpc_drv_uart.c:1032–1069`). Entry precedes existing processing; exit follows it. These distinguish ISR entry from completion. Do not manufacture/clear flags or change the existing TX queue logic.
4. Add RX DMA callback entry/exit counters in the actual no-flow-control callback (`sl_cpc_drv_uart.c:2034` onward), including every return path. This is necessary because core counters do not record raw DMA IRQ arrival. Prefer one local cleanup/exit hook mechanically covering the existing returns without changing their conditions.
5. Expose a read-only diagnostic view of the static driver's `tx_ready` boolean in that same locally instrumented translation unit. Do not change its linkage globally or walk linked lists from the snapshot ISR.

Vendor counters are insufficient alone: `rxd_frame` increments when core decode processes a received buffer (`cpc/src/sl_cpc.c:3502`); `txd_completed` increments when core receives the driver's deferred completion (`sl_cpc.c:2222–2225`), not at the instant TXC fires. The direct IRQ counters and main-loop breadcrumbs close that gap.

Obtain and store the initialized system instance pointer during normal app arming through the existing internal `sli_cpc_get_instance(SL_CPC_ENDPOINT_SYSTEM)` (`cpc/inc/sli_cpc.h:462`, implementation `cpc/src/sl_cpc.c:329`), validate non-null, and copy only selected counter fields during the final snapshot. Do not call this accessor or another potentially evolving library function from the terminal ISR.

Use a small local source overlay with an exact input checksum and bounded patch assertions for the driver hooks; do not mutate the shared SDK. Confirm replacement rather than duplicate compilation. No endpoint handlers, encryption, UART routing, clock selection or storage geometry changes.

## Snapshot before takeover

At tick 40, capture the following fixed allowlist into a static structure before altering UART, LDMA, IRQ enables or flags. Capture CPU masks before setting PRIMASK. Then mask interrupts and finish the bounded register/counter reads. The snapshot is not a single-cycle atomic hardware capture; label it accordingly.

- Header: format version, build discriminator, requested core_hz, reload, delivered ticks, snapshot-valid flags.
- Execution: current phase; cpc_enter/cpc_exit; tasklets_done; drivers_done/full_loop_done; TXC entry/exit; RX callback entry/exit; tx_ready.
- Vendor CPC: rxd_frame, rxd_valid_uframe, txd_completed, driver_error, driver_packet_dropped, invalid_header_checksum, invalid_payload_checksum.
- CPU/IRQ: entry BASEPRI, PRIMASK, FAULTMASK; SCB ICSR, SHCSR, CFSR, HFSR; both implemented NVIC ISER, ISPR and IABR words; encoded priorities for USART0_TX, LDMA, RTCC and SysTick. The live exception number is SysTick; it is not the interrupted exception.
- UART0: EN, STATUS, IEN, IF, CTRL, CTRLX, CLKDIV; GPIO USART0 ROUTEEN/RXROUTE/TXROUTE. Do not read RXDATA: it consumes input. Do not read RAM payload buffers.
- DMA: read_channel/write_channel validity and values; LDMA EN, CTRL, STATUS, IEN, IF, CHSTATUS, CHBUSY, CHDONE, REQDIS; RX/TX LDMA channel CTRL and LDMAXBAR channel REQSEL (the request mux is a separate peripheral; `sl_hal_ldma.c:169–174`). If needed, include the channel DST register address value as metadata, never dereference it or export pointed-to memory. No descriptor-list walking.
- Clock: CMU SYSCLKCTRL, without calling a clock API at elevated priority. The queried core frequency is metadata captured at arming; do not add undocumented clock-status reads.

Invalid channel indices must prevent channel-array access; encode invalidity instead. Restrict all register reads to peripherals whose clocks are known enabled at arming. A missing clock/peripheral access fault is an instrumentation failure, not proof of the original defect.

Interrupted PC/LR/xPSR are useful but optional for the first implementation. Include them only with an independently reviewed naked entry shim preserving the incoming EXC_RETURN and pre-prologue MSP/PSP. Validate stack range/alignment before reading exactly the stacked LR, PC and xPSR; handle extended FP frames using EXC_RETURN bit 4 and the architectural frame offset, and distinguish EXC_RETURN from the stacked LR. The interrupted IPSR is in stacked xPSR, not current IPSR. Never export a raw stack or general register block. If safely decoding the exact M33 frame would delay or complicate this small diagnostic, omit these fields with an explicit validity flag; the counters/phase remain valuable.

## Exclusive terminal UART takeover

The existing `startup_trace_mark` is unsuitable after CPC starts: it requires idle TX DMA/no pending TX IRQ and clears TXC (`startup-trace/output/evidence/startup_trace.c:44–68`). Reuse only its bounded TXBL/TXC polling and fixed hexadecimal conversion.

After the snapshot is complete:

1. Disable SysTick and all maskable interrupts permanently. Never return to the interrupted program. Record takeover results separately from the pre-takeover snapshot.
2. Mask USART TXC and LDMA IRQs. Disable both CPC DMA channel requests and channel interrupts, then disable the channels. Vendor APIs are bounded register writes: `sl_hal_ldma_disable_channel_request` (`platform_core/platform/peripheral/inc/sl_hal_ldma.h:2665–2672`), `sl_hal_ldma_disable_channel` (`:2544–2551`); `sl_hal_ldma_stop_transfer` (`src/sl_hal_ldma.c:264–277`) disables its channel and interrupt but is not a drain guarantee.
3. Because this is terminal and radio processing will never resume, disable the LDMA module globally as well with the vendor bounded write (`sl_hal_ldma_disable`, `inc/sl_hal_ldma.h:2523–2530`). This prevents another radio descriptor from interfering while the core is stopped. No DMA/peripheral reset is required or permitted by this design.
4. Use a fixed iteration limit to verify LDMA disable and absence of active DMA transfers before claiming UART ownership. Check EN and CHBUSY/STATUS ANYBUSY; MG21 defines EN as one enable bit and ANYBUSY at STATUS bit 0 (`Device/SiliconLabs/EFR32MG21/Include/efr32mg21_ldma.h:172–198`). Channel disable alone does not prove already-submitted transactions have drained. If exclusive ownership cannot be established, halt without emitting a purported valid report.
5. Stop accepting UART RX after its snapshot. Leave the existing TX configuration and routing intact. Allow any already-buffered TX bytes to drain by bounded TXC polling. If this fails, halt without output. Do not clear a partially transmitted FIFO and pretend its completion is known. A partially issued CPC frame before takeover may precede the diagnostic delimiter; the host must search the raw stream for the diagnostic record independently of CPC framing.
6. Transmit exactly one fixed-size record by direct TXDATA writes guarded by bounded TXBL polling; finish with bounded TXC drain. Then stay in a terminal loop with interrupts disabled. Any timeout means incomplete diagnostic transport. No CPC resume, reset, bootloader entry or storage write.

These checks are conservative: a real DMA/UART fault may prevent its own report. Missing output therefore remains explicitly ambiguous. Do not add an unbounded HAL wait, printf, dynamic allocation or recovery reset to improve apparent success.

## Wire format proposal

One raw record, maximum 1024 bytes:

`\r\n@POST1:<word-count-4hex>:<word0-8hex>:...:<wordN-8hex>:<crc16-4hex>\r\n`

Use a fixed ordered field table shared by firmware and parser. Every field is uint32, uppercase fixed-width hex. The first words identify format/build and validity. CRC16/CCITT with initial zero covers the ASCII bytes from `@POST1` through the final data word (excluding the delimiter before CRC). End-to-end checks require the exact expected count, all mandatory keys by position, valid CRC and terminator; a partial record is not a valid snapshot. Keep payload/key/address-dereference output structurally impossible. If the final allowlist exceeds 1024 bytes, reduce optional fields rather than enlarge the transport.

Takeover outcome bits belong in the record alongside, but clearly distinct from, the pre-takeover validity flags. Host early queries must finish before the four-second takeover; after it, absent CPC responses are expected and uninformative. Capture through six seconds using the same connection and raw-RX logger.


### Proposed fixed field order

Version 1 has 74 words. Keep optional frame fields present as zero with `frame_valid=0` if PC/LR capture is omitted. Invalid DMA-channel fields are zero with the corresponding snapshot-valid bit clear. `build_tag` is a fixed non-secret artifact discriminator, not a runtime device identifier. `priority_*` are raw encoded priority bytes promoted to uint32. Phase values: 0=armed, 1=CPC_ENTER, 2=CPC_EXIT, 3=TASKLETS_ENTER, 4=TASKLETS_EXIT, 5=DRIVERS_ENTER, 6=DRIVERS_EXIT. The complete record with this table is comfortably below 1024 bytes.

```text
00 format_version
01 build_tag
02 core_hz
03 systick_reload
04 delivered_ticks
05 snapshot_valid
06 takeover_status
07 phase
08 cpc_enter
09 cpc_exit
10 tasklets_done
11 drivers_done
12 full_loop_done
13 txc_enter
14 txc_exit
15 rx_callback_enter
16 rx_callback_exit
17 tx_ready
18 cpc_rxd_frame
19 cpc_rxd_valid_uframe
20 cpc_txd_completed
21 cpc_driver_error
22 cpc_driver_packet_dropped
23 cpc_invalid_header_checksum
24 cpc_invalid_payload_checksum
25 entry_basepri
26 entry_primask
27 entry_faultmask
28 scb_icsr
29 scb_shcsr
30 scb_cfsr
31 scb_hfsr
32 nvic_iser0
33 nvic_iser1
34 nvic_ispr0
35 nvic_ispr1
36 nvic_iabr0
37 nvic_iabr1
38 priority_uart_tx
39 priority_ldma
40 priority_rtcc
41 priority_systick
42 frame_valid
43 interrupted_pc
44 interrupted_lr
45 interrupted_xpsr
46 usart_en
47 usart_status
48 usart_ien
49 usart_if
50 usart_ctrl
51 usart_ctrlx
52 usart_clkdiv
53 usart_routeen
54 usart_rxroute
55 usart_txroute
56 read_channel
57 write_channel
58 ldma_en
59 ldma_ctrl
60 ldma_status
61 ldma_ien
62 ldma_if
63 ldma_chstatus
64 ldma_chbusy
65 ldma_chdone
66 ldma_reqdis
67 rx_channel_ctrl
68 rx_request_select
69 rx_channel_dst
70 tx_channel_ctrl
71 tx_request_select
72 tx_channel_dst
73 cmu_sysclkctrl
```

## Interpretation and blind spots

- TXC entry/exit and vendor txd_completed distinguish no completion interrupt, incomplete handler, and completion not reaching the core dispatcher.
- RX callback counts versus vendor rxd_frame/rxd_valid_uframe distinguish raw receive/driver progress from core processing. Zero callback count alone does not prove no wire bytes: compare UART flags and DMA state.
- Phase and completed-loop counters distinguish continued processing from failure to return from a specific region. A single captured PC, if included, is a location sample, not proof of an infinite loop.
- SysTick priority 0 can preempt the current priority-5 CPC/radio handlers and the usual BASEPRI=0x30 atomic regions. It cannot escape PRIMASK masking, HardFault/NMI, stopped clocks or a bus lockup. Its exception cannot preempt another priority-0 handler.
- Forty 100-ms ticks add small but real interrupt/timing perturbation. Core counters alter RAM layout and instruction count; breadcrumbs and driver hooks alter optimization. Retain full-image LTO/assert settings and account for instrumentation-created success or failure.
- At priority 0, the terminal snapshot may interrupt a library operation halfway through updating data. Capture only primitive metadata; do not acquire its locks or invoke its APIs. Some related fields may describe an intermediate state.
- No-output remains compatible with diagnostic arming failure, blocked SysTick, invalid frame capture, peripheral access fault, failed DMA quiesce, UART drain timeout or truncated host capture. It is never automatically classified as a firmware hang.

## Required offline verification before any separately authorized trial

Review the exact field table, timer clock/reload calculation, SysTick ownership/vector/priority and lack of later rewrites; ensure the minimal early ISR is bounded. Verify every original RX callback return accounts for exit instrumentation, no original semantics were changed, and the IRQ hooks are in the actually linked paths. Confirm fixed-size storage, output bound, CRC parser tests, malformed/truncated record rejection, no raw payload reads, and that no snapshot/terminal path invokes locks, allocation, reset or persistence. Review linked takeover instructions and absence of unbounded polling. Confirm original DMA/channel/config/security/LTO context apart from the declared diagnostic additions. Hardware success remains unproven until the resulting diagnostic has been tried; this design alone does not authorize an upload.
