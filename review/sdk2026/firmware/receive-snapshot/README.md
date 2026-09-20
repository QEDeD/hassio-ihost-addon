# Receive snapshot diagnostic — offline recipe

This is a separate successor to `../post-startup-snapshot`. It retains the original full SDK2026 application logic with diagnostic instrumentation; timing and layout change. It is not a production firmware fix. Previous diagnostic source and evidence remain unchanged.

## Wire contract and unchanged mechanics

`fields.json` is the authoritative ordered array: the previous 71 fields followed by 30 receive fields. There are 101 words and a 929-byte record, below 1024 bytes. `format_version=1`; `build_id=0x52585331` (`RXS1`). Wire framing remains `@POST1`, four hexadecimal count digits, eight hexadecimal digits per word, and CRC16-CCITT polynomial 0x1021, initial zero over the ASCII prefix through the last word. The surrounding CR/LF and colon before the CRC are excluded.

The verified SysTick arming, 40 x 100ms nominal timing, priority0 terminal snapshot, interrupt masking, bounded DMA shutdown/UART drain, terminal output and permanent halt are unchanged. SysTick cannot escape PRIMASK, a fault, a higher/equal-priority execution context, a stopped clock or a stalled bus. Missing output is ambiguous. There is no streaming during CPC ownership. The diagnostic adds no persistence writes; retained application code may perform normal runtime persistence operations.

## Exact additional metadata

- First payload-CRC failure: committed validity, declared header length, driver data length, received FCS, recomputed software CRC, frame control and UART IF. The driver-length field is read after the existing core clamp for oversized frames; it is not universally the untouched driver-reported length. The fixed length-10 test query is unaffected. No payload bytes. `first_bad_seen` is written last, after all fields; ignore the entire first-bad record if it is zero. The hook executes only on the first failed payload CRC and before the vendor failure counter/return. Therefore that valid first-bad record can briefly precede the vendor counter increment if terminal capture interrupts there.
- Header-versus-payload RX callback entry counts, and UART IF sampled at the first callback of each kind. These classify the driver's `header_expected_next` state at entry; they are not counts of complete host requests. IF reads do not clear flags.
- Resize call/OK/already-received/failure counts, last requested length, last observed received count. `0xFFFFFFFF` for last received means no successful count was recorded for the latest call. A terminal interrupt may see an in-progress call, so outcome counts need not sum to call count.
- Recovery dispatch/run entry counts. These are attempts/entries, not claims of completed recovery.
- At terminal capture: header-expected state, next RX size, four recovery flags, live RX channel LINK, both fixed descriptors' CTRL/DST/LINK words, and software head index. Recovery flag bits are 1 out-of-sync, 2 misaligned payload, 4 recovery completed, 8 dispatcher submitted. Head index is 0/1 or `0xFFFFFFFF` for neither reviewed descriptor. Channel LINK is `0xFFFFFFFF` if the channel index is invalid. The helper compares the head pointer but never dereferences it. Only the two statically known descriptors are copied; their 16-byte size is compile-time checked.

All previous counters and register fields retain their order and meaning. `bus_clock_ungated=1` remains an architectural constant for compile-guarded MG21 Series2 config1, not a runtime measurement.

## Guarded local overlays

`instrument.py` retains the previous exact guards for generated handler/app/config and UART driver, and additionally pins `cpc/src/sl_cpc.c` to SHA256 `38769f54e490b2a747971223083237c65fe4653dcfb1bc35abf4500b78480a17`. It replaces only the generated target's references to those two SDK source files with local working-tree overlays. The SDK itself is checked unchanged afterward. Compiler/link options, application config except existing vendor debug counters, timer and takeover behavior are preserved.

Hooks use unique exact anchors and insertion round-trip checks. Return hooks are compound statements, preserving existing conditional scope. The six prior UART RX exits and TXC hooks remain. The core hook uses the existing vendor `sli_cpc_get_crc_sw` only after a first failure; it does not change the original CRC decision, buffer or response path.

Exact SDK source locations:

- `cpc/src/sl_cpc.c:3636–3658`: payload FCS extraction, validation, silent U-frame rejection; metadata inserted inside `if (!crc_valid)`.
- `cpc/src/sl_cpc_drv_uart.c:2034`: no-flow callback entry classification; existing callback body/returns retained.
- `:2287–2352`: resize counters and scalar inputs/outcomes. Crucially, the existing predicate is `already_recvd_cnt >= new_length` before calculating `remaining - 1`; equality already takes the ALREADY_EXISTS path. No SDK underflow workaround is applied.
- `:1114` and `:1136`: recovery dispatch/run entry counts.
- Driver-local appended helper reads fixed descriptors and scalar state after terminal capture has disabled ordinary interrupts.

Full original and passing crypto-control generated service handlers both call `sl_cpc_process_action`; neither needs a separate generated recovery-dispatch process hook. The new counters will show whether deferred recovery actually runs for the failing receive sequence.

## Verification and interpretation

Completed offline preparation checks: both exact vendor overlays apply; both reject source checksum drift; all 101 fields appear in C; Python syntax succeeds; authored files are UTF-8/LF. Parent owns exact-target compilation, linked review, packaging and host parser/capture tests. No device operation or firmware build was performed by the implementation worker.

New ISR counters/IF reads and resize metadata stores add timing perturbation. The extra CRC pass occurs only after a frame has already failed; it can affect subsequent traffic. Descriptor metadata is not a simultaneous hardware snapshot, and ordinary software counters may be captured between updates. These limits must remain visible when interpreting changed behavior. Prefer the existing host's fixed version query and capture window; no payload/key export, pointer walks, radio behavioral changes or speculative fixes were introduced.

## Parent verification completed

Exact pinned-target build passed on first attempt (36.5second compile/verification stage). Generated configuration is byte-identical to the tested prior snapshot; capture adapter source is identical after newline normalization. Five host-parser tests pass, including rejection of the old build with a valid CRC. Independent source and linked delta review found no blocking issue; first-bad committed-last publication, resize >= branch, callback scope and fixed-descriptor loads are confirmed in the compiled image.

ELF SHA256546011d16476c54cda50e3401b4740b4d38df78856877f61929f6a1aff051825. Application-only GBL SHA2565d2ce0a0de6f2c4e0c0a495f34fc8614862c295877e8367c89ba102551f912dc. Independent packaging checks pass: matching ELF/SREC/program bytes, valid CRC, program pages[0x4000,0x2c000), no bootloader/SE/dependency tags. The image is not yet hardware-tested or authorized for another flash. See ../../RECEIVE-SNAPSHOT-TRIAL-20260920.md.
