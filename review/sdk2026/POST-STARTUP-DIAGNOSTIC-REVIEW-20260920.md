# Post-startup diagnostic review - 2026-09-20

## Independent review

A fresh-context GPT-6 Astra/high reviewer read the current result, proposed design, firmware/host source and test cases. It did not execute tests or inspect a linked diagnostic ELF. It found the experiment justified by the remaining RX, TX-completion and processing uncertainty, and found no material source-level blocker after these refinements:

- Omit optional stacked-PC/LR capture; avoid exception-frame decoding complexity.
- Keep all six RX callback returns structurally intact. The guarded overlay wraps each added exit counter and original return in a compound statement; removing instrumentation reproduces original function text.
- Check a real fixed-format fragmented report after unanswered early requests, not merely connection duration or fake output.
- Verify vector, priority, actual linked hooks and bounded takeover on the final ELF before hardware. Source review does not establish those properties.

The final source review found firmware/parser agreement on71words/659bytes and CRC coverage; pre-takeover snapshot, clock/channel guards and bounded DMA/UART polling were appropriate. Missing-output and instrumentation-perturbation limitations remain explicit. Mandatory original restoration and45minute recovery reserve were retained.

## Parent checks and open build work

The parent executed14host-capture tests and4parser tests successfully, including exact STARTUP-plus-fragmented-report retention, checksum decoding, no late query, passive disconnection, truncation and overflow rejection. The simplified fixture was rerun successfully; exact output is in evidence/post-startup-host-tests-20260920.log.

The parser also consumed the actual retained private lifecycle candidate-flash.log. It extracted exactly the known21-byte startup notification after the final RUN (SHA25612e4f52187f0f2237b0ad0f8ea55652fede60c7b982359cc6399862bed5cd5be). Raw private logs remain outside Git.

The first offline build stopped at compilation because the proposed CMU_CLKEN0_LDMA/LDMAXBAR clock-gate names do not exist on this exact MG21. No firmware artifact was exported and no production state changed. Correct the guards using exact device/vendor evidence, rerun compilation and review resulting ELF/package. Do not describe the diagnostic as flash-ready until those checks pass.

## Exact-device correction

The full failed-build log confirmed all four proposed CLKEN0 masks and the CMU member were absent, not a different compiler target. Exact clock-manager HAL lines539-559 and565-587 establish that Series2 configuration1 module bus clocks are ungated. The corrected source compile-guards that configuration, removes nonexistent register accesses and records bus_clock_ungated=1 as an architectural constant. USART.EN, channel bounds and DMA quiesce checks remain. The independent reviewer inspected this correction and accepted it at source level; its earlier source review had missed the register mismatch. The rebuild and linked checks remain the evidence needed before deployment.

## Final build and linked verification

Corrected build passed, ELF955146b29036c1ddde18f25d8db4a23622af584358eb0fa3966aa6deb88ca5de. Existing strict Commander packaging independently compared ELF/SREC/GBL payload, CRC, application properties and allowed tags/pages. GBL76c560b9a0d78bfa9aa2cc8a5555144971434975859d714ff3cb12da16e8bb12 programs only[0x4000,0x2c000), below NVM at0xb4000; no bootloader/SE update tags. Runtime application writes remain possible.

The independent reviewer inspected actual vector bytes, symbols, disassembly, linker map and build/configuration evidence. Vector15=0x173F5 resolves to strong SysTick_Handler0x173F4. Priority0 write at0x5350 precedes CTRL7 at0x5374 and entry to the CPC loop; earlier default-priority initialization does not overwrite it. First39ticks return after bounded increment. Actual CPC/tasklet/driver progress and TXC/RX hooks remain linked; only the overlay driver is selected. The terminal path calls only bounded local output/poll/halt helpers, with100000-iteration polling bounds and71-word output, no allocation/locks/reset/persistence. Intentional final halt is unbounded.

Static RAM rises412bytes, heap48948 to48536; reserved stack remains2752bytes. Deepest diagnostic software stack is64bytes plus exception frame/interrupted context; this does not prove runtime stack headroom. The parent independently read the ELF vector and compared generated configuration: the sole change is enabling vendor CPC core counters. Final field-schema rerun passed14capture and4parser tests. Evidence: post-startup-build-20260920.log, post-startup-package-20260920.log, post-startup-host-tests-20260920.log and post-startup-preparation-20260920.json under evidence/.

No diagnostic has been flashed. HA access relocked during read-only preflight; the parent cancelled its passphrase prompt and asked the operator to unlock while completing offline preparation. No service was stopped or configuration changed.
