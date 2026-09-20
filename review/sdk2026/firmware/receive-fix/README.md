Current qualification, September20: exact normalGBL713d18d799727d4b85cd2fd657617522f4adc3bb62e79d83758d782dc261f604 is accepted and running on the production ZBDongle-E with host0.3.1-sdk2026. CPC binding/encrypted operation, existing networks and controlled app restart passed. See ../../FULL-FUNCTIONAL-RESULT-20260920.md for scope/limits. The preparation chronology below describes the earlier unflashed state, not current production status.

# Normal full-firmware receive initialization candidate

This recipe builds the original full SDK2026.6.1 application with only the reviewed no-flow UART DMA bootstrap correction. It derives from the pinned original `../build-offline.sh` and retains its target, compiler/link settings, application configuration, UART pins/baud/flow control, HFXO settings, security and storage layout. Existing recipes/artifacts are unchanged.

## Evidence and qualification boundary

The RXB1 diagnostic with this initialization correction answered the first version query as CPC4.9.1 in 8.4ms. Its matched terminal report showed two successful DMA resizes, zero failed resizes/checksum errors, one valid unnumbered frame, two completed transmissions and no UART overflow at capture. This supports the initialization correction and the descriptor-load ordering explanation. It does not qualify full host services, network operation, encrypted transport, long-running stability or restart/recovery behavior.

This normal candidate removes all diagnostic instrumentation rather than retaining a terminal application. It has no snapshot timer, extra counters, first-failure CRC pass, checkpoint output or UART takeover/halt. Its offline build and review pass; it is not an independently qualified production release.

## Exact code change

The checksum-pinned UART source receives the same `restart_dma()` function used by RXB1. Function-text SHA256 is `aab4641d64a1a49ab5f621dec656287d5d61539da5419cb2ea0d54138a502297`.

In the no-hardware-flow-control branch, after the existing seven-byte header setup, copy descriptor0 into a static four-byte-aligned 16-byte bootstrap descriptor. Set only the copy's link-enable and completion-interrupt bits. Initialize DMA with that stable descriptor, preserving the software head at descriptor0 and the bootstrap link target at descriptor1. Remove the later live LINK/DONEIEN edits. The original two descriptors keep their reusable spill semantics, and the HWFC alternative retains its original HAL initialization call.

The normal UART source is otherwise byte-identical to the pinned SDK source. The existing stop/resize/recovery logic remains; this change is not a general proof of every DMA restart condition. The vendor HAL memory barrier/start sequence is reused; there is no guessed LINKLOAD polling, arbitrary delay, forced reset or DMA channel reassignment.

## Reproducible preparation

`prepare-build.py` inserts the local `instrument.py` preparation into the original full build recipe before CMake configuration. `instrument.py` pins the vendor UART source, original app, generated event handler and CPC configuration hashes. It replaces exactly one generated CMake source path with a local patched UART file. It does not add include paths, flags, sources for diagnostics or configuration changes. The SDK and preserved inputs are checked unchanged afterward. `evidence/receive-fix-overlay.json` records the input, overlay, CMake and preserved-input hashes.

`Dockerfile.offline` reuses the pinned builder digest, Debian snapshot preparation, source epoch and original build/verification scripts. No prior generated output is copied into this recipe. `build-package.sh` requires the independently reviewed exact ELF SHA256 and delegates to the established application-only packager; output name is `receive-fix-sdk2026-application-only.gbl`.

## Checks completed and remaining

Four offline tests pass: exact RXB1 restart equality/no diagnostics; restart-only change and preserved HWFC path; rejection of source/anchor drift; and preparation preserving all other inputs while adding only the driver overlay and manifest. Python syntax and UTF-8/LF checks pass. Tests do not emulate DMA timing.

Reproduce with the pinned SDK source available:

```sh
SDK_CPC_UART_SOURCE=/opt/silabs/sdks/simplicity_sdk_2026.6.1/cpc/src/sl_cpc_drv_uart.c python3 -m unittest test_instrument
```

Parent owns exact-target build, artifact hashes, linked/source/config comparison, independent review, packaging and any separately authorized hardware/service trial. Linked review should confirm bootstrap static RAM/alignment, correct initial descriptor values and unchanged original source/configuration apart from this driver substitution; absence of diagnostic SysTick/counter/output code must also be verified. No build, live operation or commit was performed by the implementation worker.

## Parent verification completed

All4 tests and the exact-target build pass. Fresh independent source/linked review confirms complete original config/autogen/app equality, the exact RXB1 restart correction, static aligned bootstrap0x20000d6c and correct copy/flags before HAL load. Diagnostic symbols, literal output, counters and takeover are absent; SysTick resolves to the ordinary default handler.

ELF SHA256601c73da6feaf6e29fa9a797fe93f48e73f75fd0f88deda42444a2949ae39cc1. Application-only GBL SHA256713d18d799727d4b85cd2fd657617522f4adc3bb62e79d83758d782dc261f604. Independent ELF/SREC/GBL byte equality, CRC, tag and page checks pass; program pages[0x4000,0x2c000), below preserved NVM0xb4000, no bootloader/SE tags. Packaging container stopped. See ../../evidence/receive-fix-preparation-20260920.json and ../../RECEIVE-FIX-REVIEW-20260920.md. Not uploaded to HA or flashed.
