# Full-image startup trace — SDK 2026.6.1

Prepared offline and subsequently tested once on 2026-09-20. Diagnostic only, not a firmware fix or production release. All startup checkpoints appeared, but the later CPC probe failed; original production was restored. See ../../STARTUP-TRACE-RESULT-20260920.md for recovery verification and the remaining final snapshot. The approved trial allowance is consumed; do not repeat it.

## What this observes

The full multiprotocol firmware has not answered CPC, while the CPC-only, HFXO+CPC and crypto+HFXO+CPC images have answered. Add short fixed serial checkpoints around the full image's startup calls, rather than spending another outage on a component-only variant. Reuse the vendor HAL and the flasher's existing open serial connection. No additional serial owner, RTT/debugger hardware, logging framework or vendor SDK edit is introduced.

`app_init_early` configures only the existing USART0 TX pin PB1 at 115200, no flow control. The hook runs after early clocks, sleeptimer and MPU setup. Nineteen generated calls receive before/after checkpoints, and `FF` is the final checkpoint inside app_init, before processing. Exact-site guards reject source drift. The inherited source-sha256.txt records vendor inputs before instrumentation; retained source files and artifact hashes identify the resulting diagnostic. The generated marker dictionary is in output/evidence/startup-markers.json.

Expected sequence: **00, 09, 0A, 01–08, 0B–26, FF** (hexadecimal). Vendor permanent allocation occurs between 00 and 09 and is not separately marked. Forty frames of eight bytes add about 27.8 ms of wire time in total; interrupts are masked for each approximately 0.694 ms frame, plus software overhead. This timing and code-layout disturbance can affect the original failure.

Before CPC init, tracing uses the vendor USART HAL. After CPC init, tracing reuses that configuration without resetting the peripheral. It checks that CPC TX DMA is idle, masks TX completion interrupts, waits a bounded number of iterations for raw transmission, clears its own completion/pending flag, and restores the previous interrupt state. Otherwise an empty CPC TX queue could be serviced incorrectly. The final checkpoint permanently disables tracing before any process_action. A failed guard terminates this diagnostic; its RAM fault code cannot be read through this serial capture.

## Capture and interpretation

`capture-launch.py` changes only the reviewed universal-silabs-flasher 1.1.0 RUN wait from 2 to 30 seconds. The exact gecko_bootloader module SHA256 and original timeout are checked before any CLI action. Upload, reset, XMODEM and bootloader error handling remain vendor code. Every RUN performed by that invocation gets the longer wait, including any launch while probing. Use it only for the approved diagnostic upload; use the ordinary pinned flasher for control, later CPC probe and rollback.

Keep DEBUG output private: it includes firmware upload bytes and arbitrary RX, not just checkpoints. `parse-markers.py PRIVATE_LOG` prints only fixed-format received markers after the last logged standalone bootloader RUN command. It excludes transmitted firmware contents, rejects logs without RUN and handles split RX chunks. After the physical test, the parser was corrected to recognize the observed serialx `Immediately writing <GeckoBootloaderOption.RUN_FIRMWARE: b'2'>` record; the retained output/evidence copy is the original pretrial snapshot, not the current parser. Check the raw log privately for complete upload/RUN and resets; the sanitized list alone is insufficient evidence.

- A before-marker without its matching after-marker brackets the vendor call **and the tracing/capture machinery**. It does not uniquely prove the call failed.
- No 00 leaves early startup, UART setup, local trace failure and capture/launch failure unresolved.
- FF establishes arrival at the final app_init checkpoint. CPC responsiveness still needs the separate bounded version probe.
- Successful instrumented startup does not establish that the unmodified image is fixed, nor that encrypted binding or RF/network operation works.
- Repeated sequences may indicate resets; preserve their ordering and inspect raw timestamps.

## Build and package

From repository root:

```sh
docker build --platform linux/amd64 --progress plain \
  --file review/sdk2026/firmware/startup-trace/Dockerfile.offline \
  --build-arg BUILD_JOBS=2 \
  --output type=local,dest=review/sdk2026/firmware/startup-trace/output .
```

Uses the existing digest-pinned Nabu Casa builder, SDK, compiler, base recipe and Debian snapshot. Generation/compilation run without network or devices. SOURCE_DATE_EPOCH fixes OpenThread's embedded build date/time to 2026-09-20 00:00:00 UTC. This metadata difference is intentional; it prevents wall-clock changes obscuring binary comparisons. Build logs retain real timestamps. Two separate compilation runs then produced the identical ELF hash. The generated catalog omits the old LTO label, but exact-SDK search found no consumers and actual compile/link flags still enable LTO; see the review record.

`build-package.sh` supplies the exact ELF hash and basename to the existing recovery package helper. Set COMMANDER to Commander 1v25p0b1995, PYTHON, FIRMWARE_INPUT to output/artifacts and PACKAGE_WORK to a new directory. The shared helper's only extension is a validated input basename; its default and strict payload checks are unchanged.

- ELF SHA256: `75c8b8c9989fa95ef9cfdad9622fe4400c159157436f7982f520156d51eee009`
- GBL: `package/startup-trace-sdk2026-application-only.gbl`
- GBL SHA256: `e5eba832d7eecac5870f0db2d47ce9725e5c1d6c7ad4f15c1783c4e9fb59dbe6`
- Program pages: `[0x4000, 0x2c000)`, below NVM at 0xb4000; no bootloader/SE update tags. Runtime NVM writes are still possible.

Independent verification compares ELF, SREC and vendor-parsed GBL bytes, CRC, tag allowlist, application properties and page bounds. `test_capture.py` runs against the actual pinned flasher and covers the extended wait, retained RX, returning bootloader error, source/version guards, final-launch selection, split markers and TX exclusion. These checks cannot establish physical capture reliability. See evidence/comparison.json and ../../STARTUP-TRACE-REVIEW-20260920.md.

## Reused primary evidence

- [Silicon Labs main initialization](https://docs.silabs.com/gecko-platform/6.0.1/platform-service/sl-main): early/second-stage hook ordering; checked against exact SDK source.
- [Silicon Labs multiprotocol debugging](https://docs.silabs.com/openthread/latest/multiprotocol-solution-linux/debugging-local-processes): logging transports and excessive output caveat.
- [Nabu Casa SDK 2026.6.1 builder work](https://github.com/NabuCasa/silabs-firmware-builder/releases/tag/v2026.08.18-beta1): retained builder route, not a ready-made dongle image.
- Exact SDK source review: sl_main_init.c, Series-2 clock-manager runtime no-op, sl_cpc_drv_uart.c TX IRQ/queue/DMA lifecycle, USART/LDMA HAL. See ../../VENDOR-STARTUP-FINDINGS-20260920.md for applicability and alternatives.

A debugger could retrieve PC/fault RAM but access is not established. Existing crash fields and disabled logging do not provide this pre-CPC serial observation. No matching published fix currently justifies speculative clock, bootloader or SE changes.
