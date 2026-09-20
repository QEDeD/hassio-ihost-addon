# Broader CPC failure analysis — 2026-09-20

## Conclusion and current production state

The full SDK2026.6.1 application can transmit a valid CPC startup message. Sustained request handling has not been demonstrated. Calling this simply a boot failure, or assuming that serial reopening causes it, overstates the evidence.

The original app0.2.3-ordered and radio4.6.0 are restored. After operator unlock, the12:15:20UTC HA snapshot showed zero newly unavailable entities against the pretrial baseline, with fresh changing ALPSTUGA reports. App versions, options, policies and started states were reconfirmed at12:19UTC. This closes the outstanding recovery check; it does not complete the upgrade. No new hardware experiment occurred during this analysis.

## Evidence recovered from earlier logs

The original **uninstrumented** full candidate emitted the same valid startup message62ms after its final bootloader RUN. This was already present in the retained DEBUG upload log and was overlooked when attention concentrated on the later silent probe. Consequently, initial transmission is not a capability demonstrated only by the instrumented firmware. The trace still supplies useful localization and can still affect later timing or behavior.

| Image | Host-logged delay from RUN to startup message | Later raw probe RX chunks |
| --- | ---: | ---: |
| Original full SDK candidate |62ms|0|
| HFXO+CPC control |57ms|2|
| Crypto+HFXO+CPC control |57ms|2|
| Full startup-trace candidate |93ms|0|
| Mandatory restored original4.6.0 |620ms|2|

These are host log delivery timings, not exact MCU execution timings. Earlier original-firmware launches also produced faster notifications; do not infer firmware speed or a timing defect from these values. Each first version request was byte-identical across all five cases. Raw chunk counts are not response-parser counts; successful version decoding is separately recorded in the trial results.

The common startup frame is a system LAST_STATUS notification with RESET_WATCHDOG. It reports the launch reset cause and is also emitted by working controls. It is not evidence of a new crash after startup. The trace's40markers end inside app_init; neither those markers nor the outgoing message prove subsequent receive processing or interrupt completion.

Sanitized extraction with private source-log SHA256 references: [startup comparison](evidence/startup-comparison-20260920.json). Existing raw logs remain protected outside Git. The recovered finding should change the next experiment rather than trigger repetition of earlier component tests.

## Competing explanations and constraints

| Perspective | What supports further investigation | What limits the explanation | Discriminating evidence |
| --- | --- | --- | --- |
| Transmission completes electrically but software never releases it | CPC sets tx_ready=false before DMA; the USART TX-completion interrupt sets it true. A whole frame can arrive without proving this handler completed. | No missing interrupt has been observed. | Effective vector/priority/masking audit; if necessary, bounded completion/loop counters with a proven retrieval path. |
| Incoming bytes or later CPC servicing fail | No response to identical valid version requests; full image adds radio/OpenThread work to the processing loop. | UART RX routing/enabling matches the passing control; NCP reads are nonblocking and tasklets use a pending-task snapshot. No specific blocking call was found. | Inspect post-CPC peripheral/interrupt changes; distinguish RX arrival, processing progress and reply transmission. |
| Full-image resource interaction | Full enables round-robin allocation across eight DMA channels. Derived CPC RX/TX allocation is0/1 versus7/6 in the crypto control; RAIL subsequently gets2. | Allocator ownership prevents the obvious overlap; repeat initialization returns without resetting hardware. Channel-zero special handling was not found. These are derived, not runtime-measured, allocations. | Audit channel/interrupt assumptions at the radio-library boundary before changing allocation policy. |
| Elapsed time versus serial close/reopen | No queries were sent during the uninterrupted30second trace capture. Reopening changes control lines/buffer state. | Controls work through the same lifecycle. An OS port close is not a CPC endpoint-close protocol command. | Query on the launch connection early and again before closing, then query after reopening with the same settings and one owner. |
| Security/protocol mismatch | Full firmware has security and more integrated services. | The first request is identical to working SDK controls; vendor startup discovers the version before establishing encryption. | Audit the exact system-command path if needed. Do not try binding, key replacement or plaintext fallback to diagnose missing version replies. |
| Observation or board/reset effects | Instrumentation changes timing/layout; bootloader launch differs from a power cycle. | Uninstrumented full firmware already transmits; successful controls and restoration weaken a universally broken bootloader/baud/board explanation. No power-manager component or WFI/WFE was found in linked main. | Retain these as conditional alternatives, not reasons to update bootloader, erase state or acquire new hardware immediately. |

A single successful ingredient test does not establish that all ingredients work together. Conversely, a resource difference is not automatically a defect. RF interference, network membership, HA integration and host encrypted-session behavior are downstream of the unanswered local version query; they are not the first variables to change.

## Exact-source review and independent challenge

Two bounded offline workers were used: the existing source specialist and a fresh-context challenge/reuse review. Neither changed files or accessed hardware. The parent independently re-extracted historical launch/probe evidence and spot-checked the original linked USART0_TX handler.

Source references from the retained SDK2026.6.1 build:

- CPC UART driver `cpc/src/sl_cpc_drv_uart.c:924–935,1032–1069`; original ELF USART0_TX_IRQHandler at0xC730 and tx_ready store at0xC750. Parent confirmed these in `firmware/candidate-clean/evidence/disassembly.txt.gz`.
- Full generated `autogen/sl_event_handler.c:86–89`, app_process_action, and `openthread/platform-abstraction/efr32/system.c:125–145`; nonblocking NCP reads in `ncp/ncp_cpc.cpp:307–339`.
- Full `config/sl_dma_manager_round_robin_config.h:40`; `platform_core/platform/service/dma_manager/src/sl_dma_manager.c:100–103,235–377`; `rail_library/plugin/sl_rail_util_dma/sl_rail_util_dma.c:39–61`. Specialist checked original linked round-robin setup at0x163EA–0x163F6 and allocator at0x17B70. MG21 exposes eight DMA channels.

Accepted review corrections: separate immediate responsiveness, time-dependent failure and port transition; distinguish host port closure from CPC user-endpoint closure; avoid attributing silence to missing binding; retain observer limits despite the recovered uninstrumented message. No matching published fix or proven code defect was established.

## Reuse current vendor diagnostics where they actually help

[Platform6.1.1 CPC documentation](https://docs.silabs.com/gecko-platform/6.1.1/platform-cpc-overview/) describes counters, SystemView and a bounded CPC Journal. Journal retrieval requires CLI/IOStream; debugger counters require debugger access. Neither is automatically available through this dongle in its installed position. Logging over the failing serial link could interfere with CPC or fail to retrieve anything. Establish retrieval and output bounds before adding instrumentation.

[Vendor troubleshooting](https://github.com/SiliconLabs/cpc-daemon/blob/main/doc/troubleshooting.md) offers UART validation and additional diagnostics. Audit their exact protocol effects and firmware requirements before use; a general-purpose daemon or test mode must not silently introduce resets, binding or extra owners. [Current vendor startup source](https://github.com/SiliconLabs/cpc-daemon/blob/main/server_core/server_core.c) requests SECONDARY_CPC_VERSION before security_init, supporting the pre-encryption distinction. Main-branch source is supporting design evidence, not proof of every pinned binary's behavior.

A community flow-control report found during research concerned MG24/Spinel and did not establish a matching MG21/CPC failure. It is not grounds for a transport change here.

## Smallest useful route forward

1. **One bounded offline audit:** compare effective interrupt vectors, priorities and masking, plus post-CPC UART/LDMA changes, in the original full and passing crypto builds. Reuse retained disassembly/source and concentrate on the radio-library boundary. Stop broad source exploration if no concrete fault emerges; actual interrupt delivery cannot be established offline.
2. **Prepare one connection-lifecycle observation, not another component-removal image.** Prefer the already-built uninstrumented full candidate to avoid extra observer changes. Adapt the existing single-owner launch/capture path to send the established version query soon after the startup notification, again after a bounded delay before close, then after reopening. Capture raw TX/RX, timing and host-visible DTR/RTS settings. Verify locally that the bootloader parser cannot silently swallow the CPC reply or contaminate the result. Host settings alone do not measure physical line voltages.
3. **Use explicit decision branches.** Early reply then pre-close silence implicates time-dependent behavior; pre-close success then post-open silence implicates the transition; silence from the first query shifts priority to RX, first TX completion and servicing. A later-only reply instead suggests delayed readiness. A reply at every phase means the earlier failure was not reproduced; do not declare a fix or proceed to binding automatically.
4. **Only if needed, add narrowly targeted observability.** Prefer vendor counters/journal if retrievable. Otherwise identify the smallest bounded way to distinguish receive arrival, TX completion and loop progress. Do not build a broad tracing framework or accumulate several firmware variants without an evidence-based question.
5. **Before another physical trial:** prepare the exact bounded procedure and recovery package, obtain independent review and operator approval, then refresh baseline/coherent backups and maintenance facts. Mandatory original restoration and existing recovery limits remain the default. Current analysis authorization supplies no additional flash allowance.

No new root cause, corrective patch, performance benefit or deployment readiness is claimed. No production configuration, binding, network state, bootloader or Secure Engine was changed. The next executable work is the bounded offline interrupt/peripheral comparison and preparation described above; SDK qualification and contribution reassessment remain open.
