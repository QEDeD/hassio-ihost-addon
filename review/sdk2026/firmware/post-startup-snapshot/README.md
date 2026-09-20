# Full-image terminal snapshot diagnostic

Offline implementation, compilation, linked review and application-only packaging completed on2026-09-20. This is observability code, not a proposed firmware fix. No hardware trial has occurred. Current testing authority and remaining live prerequisites are recorded in ../../EXECUTION.md and ../../POST-STARTUP-DIAGNOSTIC-TRIAL-20260920.md.

The original application logic with diagnostic instrumentation (timing and layout change) runs for forty delivered SysTick periods, nominally four seconds. RAM breadcrumbs record before/after CPC, OpenThread tasklets and platform-driver processing. A checksum-guarded local copy of the vendor UART driver adds TXC-branch entry/exit counts, six RX-callback return counts and a read-only tx_ready accessor. Only vendor CPC core event counters are enabled. The original SDK is never modified.

At the deadline, priority-0 SysTick snapshots allowlisted execution/IRQ/UART/DMA metadata, permanently stops normal processing, quiesces all LDMA channels and disables LDMA, drains UART TX, then emits one bounded record. There is no raw diagnostic output while CPC owns the UART, no resumption after takeover, and no stacked-PC/LR shim. The diagnostic adds no reset, binding, unbinding or persistence writes; normal retained application initialization/runtime can still perform its existing NVM operations.

## Files and wire contract

- `fields.json` is the authoritative ordered array of 71 unique field names. Firmware enum generation and the parent-owned host parser use the same file.
- `snapshot.c` / `snapshot.h` implement the timer, primitive RAM hooks, snapshot and bounded terminal export. Build ID is `0x504F5331`, format version is 1.
- `instrument.py` checks complete SHA256 values of the vendor driver, app, generated event handler and CPC config before producing a local source overlay. It replaces the original driver in the generated CMake target, preserving its existing options. Hook removal must reproduce the exact original function text. All six RX return replacements are compound statements, preserving conditional control flow.
- `Dockerfile.offline` reuses the pinned builder, SDK/base recipe, Debian snapshot and SOURCE_DATE_EPOCH from startup-trace. Generation/compilation have no network/device access. The expanded local overlay, generated header, original hashes and mutation manifest are retained as build evidence.
- `build-package.sh` requires an explicitly supplied, independently verified ELF SHA256; it does not assume a hash before the build. It delegates application-only GBL packaging to the existing helper.
- `capture-launch.py` and host parser/tests are owned by the parent task.

One 659-byte record uses this grammar:

```text
\r\n@POST1:0047:<71 colon-separated uppercase 8-hex words>:<4-hex CRC>\r\n
```

CRC16/CCITT uses polynomial0x1021 and initial0 over ASCII `@POST1` through the final data word, excluding the delimiter before CRC. The fixed count, format/build identifiers, CRC and terminator must all validate. Arbitrary receive data, raw payload buffers, security keys and stacks are never exported. DMA DST register values are address metadata only; the pointers are not dereferenced.

`snapshot_valid` bits: 0=CPU/software progress, 1=vendor CPC counters, 2=UART registers, 3=GPIO routes, 4=global LDMA registers, 5=valid RX/TX channel plus request-mux registers, 6=clock metadata. Unavailable groups remain zero with their bit clear. `takeover_status` bits: 0=DMA idle, 1=DMA module disabled, 2=preexisting UART TX drained. A successfully started report has takeover_status7; the final TX drain is verified after the record and cannot retroactively appear in it.

Phase: 0=armed, 1=CPC_ENTER, 2=CPC_EXIT, 3=TASKLETS_ENTER, 4=TASKLETS_EXIT, 5=DRIVERS_ENTER, 6=DRIVERS_EXIT. IRQ priorities are raw encoded priority bytes. The snapshot runs inside SysTick; live ICSR identifies SysTick, while NVIC active bits help identify a preempted external handler. No interrupted-PC claim is made.

## Timer and failure limits

Core-clock SysTick uses `CMU_ClockFreqGet(cmuClock_CORE)/10 - 1`, with nonzero/24-bit checks. At80MHz the reload is7,999,999. This does not rely on a cached SystemCoreClock variable, but real elapsed time still depends on clock reporting, unchanged core frequency and timely exception delivery. Missed/coalesced ticks can delay takeover.

Priority0 can preempt the reviewed priority5 CPC/radio handlers and BASEPRI0x30 regions. It cannot escape PRIMASK, HardFault/NMI, an equal-priority handler, stopped clocks or a bus lockup. Instrumentation changes timing/layout and can change the observed behavior. Primitive fields can describe an intermediate interrupted update; no library locks or list walking occur during capture.

The terminal path uses only bounded register polls. It disables DMA requests/channels, waits for no busy transfers while the module remains enabled, then disables the module and verifies that state. It never treats channel disable alone as a transfer-drain guarantee. If DMA cannot quiesce or UART cannot drain/transmit, the image halts with only a RAM diagnostic fault code; it does not manufacture an apparently valid report. Missing output remains ambiguous and must never be labeled proof of a firmware hang.

RAM fault codes: 1=SysTick already owned, 2=invalid reload, 3=missing CPC instance, 10=DMA snapshot metadata unavailable, 11=UART snapshot metadata unavailable or USART module disabled, 12=DMA quiesce timeout, 13=DMA-disable timeout, 14=UART pre-drain timeout, 15=UART byte timeout, 16=final TX drain timeout. Zero after terminal output denotes the diagnostic's successful terminal halt, not firmware acceptance.

## Preparation checks completed

Before handing off for the separate build: Python syntax checks passed; the exact retained UART-driver SHA256 passed; all six RX callback returns and the TXC entry/exit branch were instrumented; stripping added hooks reproduced original functions; modified-source drift was rejected; all71 schema fields matched the C source; authored files were UTF8/LF. No firmware compilation or device operation was performed by this implementation worker.

Required next checks include compilation, vector15/priority0/timer arming review in the actual ELF, hook retention and original-driver exclusion, polling bounds, schema/CRC integration, storage/package checks and independent review. The prepared design is at `../../POST-STARTUP-DIAGNOSTIC-DESIGN-20260920.md`; where its optional frame/table proposal differs, this implementation deliberately omits frame capture and fields.json is authoritative.

## MG21 clock-register correction

The first compile rejected CLKEN0 accesses. The exact target is Series2 config1: `platform_core/platform/service/clock_manager/src/sl_clock_manager_hal_s2.c:539-559` makes bus-clock enable a no-op, and lines 565-587 report every module bus clock enabled without reading a gate register. The MG21 CMU header has no CLKEN0. The implementation now requires config1 at compile time, reads these ungated bus interfaces directly, and reports `bus_clock_ungated=1` in the final schema field. USART module EN and the LDMA state/drain checks remain separate; no clock register is written by this correction. The ordered schema still contains 71 fields and the wire record remains 659 bytes.

## Verified artifact

ELF SHA256955146b29036c1ddde18f25d8db4a23622af584358eb0fa3966aa6deb88ca5de; GBL SHA25676c560b9a0d78bfa9aa2cc8a5555144971434975859d714ff3cb12da16e8bb12. Program pages[0x4000,0x2c000); strict ELF/SREC/GBL equality and tag/CRC checks passed. Parent/reviewer linked checks and18host/parser test results are summarized in ../../POST-STARTUP-DIAGNOSTIC-REVIEW-20260920.md. These checks establish preparation, not hardware behavior.
