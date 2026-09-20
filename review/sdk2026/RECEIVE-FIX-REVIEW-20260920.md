# Normal receive-fix independent review - 2026-09-20

No blocking source or linked-code finding for this offline normal-firmware candidate. This review establishes the intended delta and removal of diagnostic code; it does not qualify production service operation or authorize a firmware upload.

Reviewed ELF SHA256: `601c73da6feaf6e29fa9a797fe93f48e73f75fd0f88deda42444a2949ae39cc1`, from `firmware/receive-fix/output/artifacts/rcp-uart-802154.out`.

## Verified delta

- Independently applied the transformation in memory to the retained, checksum-pinned SDK UART driver. Every byte outside `restart_dma()` remains vendor-original. The built restart function is byte-identical to the RXB1 restart function: SHA256 `aab4641d64a1a49ab5f621dec656287d5d61539da5419cb2ea0d54138a502297`. Built UART overlay SHA256 is `91420f2beeb8052ef860515e8f5024ac26b1a0fbdb49a7daf17ad7ad163530aa`.
- Compared complete output trees with `candidate-clean`: all generated `config` and `autogen` files are byte-identical, with no added or removed files. Original application-source files are also byte-identical; only the patched UART source is added. This preserves the original security, debug-counter, pin, clock and application configuration.
- The generated CMake file selects the patched UART source and original SDK CPC core. It matches the RXB1 generated CMake after reversing all diagnostic source replacements/additions and applying only the normal UART substitution. No diagnostic source, include path or target-flag addition remains.
- No diagnostic counter, capture, first-failure CRC, takeover or snapshot symbol/literal remains in the reviewed linked disassembly. `SysTick_Handler` is the ordinary `Default_Handler` alias at `0x130d0`, not the diagnostic handler; the unchanged original app does not arm the four-second snapshot. No scheduled terminal takeover/halt remains. The normal fault/default handler still loops, as in the original application.

## Exact linked bootstrap

The original descriptors are at `0x20000d4c` and `0x20000d5c`; static bootstrap storage is at `0x20000d6c` in `.bss`, word-aligned. The seven-byte count is set before the four-word copy at `0xbc16-0xbc18`. The bootstrap LINK bit1 and DONEIEN bit20 are set at `0xbc24-0xbc28` and `0xbc32-0xbc36`; the software head remains descriptor0. HAL receives the bootstrap address at `0xbc3c-0xbc3e`. Start at `0xbc50` reaches DMB `0x1550a`, CHDONE clear `0x15516` and LINKLOAD_SET `0x15518`. Only channel enable and interrupt-state restoration follow; there are no post-load LINK/CTRL edits in restart.

The source preserves the two-descriptor ring, callback mapping, normal resize/recovery logic and HWFC alternative exactly as reviewed for RXB1. The existing asynchronous stop/restart limitation is not expanded into a proven general recovery fix.

## Qualification boundary

The parent reports that RXB1 answered the first physical query with CPC4.9.1, two successful resizes and no resize/CRC failures. That supports the initialization correction in the instrumented image. Removing instrumentation changes timing and layout, so this exact normal ELF still needs separately authorized hardware and full host-service validation before upgrade acceptance. No claim about long-term encrypted transport, Zigbee/Thread operation or restart reliability follows from this offline review.

Parent owns application-only packaging/hash validation and the concrete trial/recovery plan. Reviewer performed no build, device access, service action, firmware upload or commit. The only reviewer mutation for this assignment is this document.
