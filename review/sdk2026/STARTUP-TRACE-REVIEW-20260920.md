# Full startup trace review — 2026-09-20

Historical preparation review below. The later approved physical test is recorded in STARTUP-TRACE-RESULT-20260920.md; its allowance is consumed and production restored. The parser fixture limitation discovered in that test is documented there.

## Route and evidence

Three increasingly complete CPC diagnostics now reply, but the full image remains unexplained. Adding another isolated component would leave the same observability gap. Instrument the existing full image's startup boundaries and retain its active flasher connection for early output. Reuse vendor HAL, exact generated call sites, pinned flasher and strict application-only packaging; do not add a framework or require unestablished debugger hardware.

Full build and existing configuration checks pass. All 35 generated configuration files are byte-identical to candidate-clean. Intended source differences are app_init's final checkpoint and the new trace source; generated event handlers contain guarded checkpoints. A further generated catalog difference omits SL_CATALOG_TOOLCHAIN_GCC_LTO_PRESENT. Bounded source review found no consumers anywhere in the exact SDK; both projects select the component, its definition is identical, and retained CMake flags plus lto-wrapper confirm LTO remains active. The exact SLC omission cause is unresolved; no identified behavioral consequence or justification for manually patching the catalog.

OpenThread embeds compilation time, which initially changed artifact hashes. SOURCE_DATE_EPOCH is now pinned to September 20 midnight UTC. Two separate compilation runs after that change produced identical ELF SHA256 75c8b8c9989fa95ef9cfdad9622fe4400c159157436f7982f520156d51eee009. Real timestamps in build logs remain different. This is a metadata stabilization, not a startup fix.

Linked instructions retain finite TX polling (100000 iterations), IRQ save/mask/restore, DMA checks, TXC clearing, and the final trace gate store before CPC processing. These observations and source review support the handoff; they do not establish physical timing or capture reliability.

Five actual-flasher host tests pass: extended existing RUN wait with RX retained; menu-return failure preserved; source/version mismatch rejection; TX exclusion, split markers and final-RUN selection; missing RUN rejection. The timeout test sees both the outer RUN timeout and vendor state-machine timeout; both are intentionally exercised. No serial hardware is used.

Final GBL SHA256 e5eba832d7eecac5870f0db2d47ce9725e5c1d6c7ad4f15c1783c4e9fb59dbe6 passes ELF/SREC/vendor-parser equality, CRC, application properties, allowed tags and programming bounds [0x4000,0x2c000). Bootloader and NVM programming pages are excluded; runtime storage writes are not excluded. The shared package helper only gains a validated ELF basename, defaulting to its former name. Existing HFXO and crypto packages still pass; deliberately wrong ELF hash and path-escape basename are rejected.

## Independent review and disposition

Fresh-context GPT-6 Astra, high reasoning, reviewed source, generated output, pinned flasher tests and exact vendor init/UART code. No confirmed must-fix safety or implementation defect was found. Accepted corrections:

- FF is the final checkpoint inside app_init, not proof that app_init returned or CPC works.
- Actual order is 00,09,0A,01–08,0B–26,FF; permanent allocation lies unmarked between 00 and09.
- A missing marker includes tracing, reset/interrupt and capture failures among explanations. Local trace_fail is terminal and its RAM code is not available via serial.
- No00 cannot distinguish early startup from UART/capture failure.
- Forty frames add about27.8ms wire time with per-frame interrupt masking, plus code/layout changes. Instrumented success cannot certify the unchanged candidate.

The reviewer checked the apparent early-UART clock risk: the exact Series-2 clock-manager runtime initializer merely returns success, so that call does not change the configured baud. It also confirmed CPC's TX completion handler assumes an enqueued buffer, making marker interrupt masking/clearing necessary. No simpler source-supported route provides comparable localization with established interfaces.

Parent incorporated these limitations in the README and proposed trial, and additionally restricted parsing to RX after the final logged RUN. Source specialist completed the bounded LTO discrepancy check. No worker remains assigned after closeout.

## Next decision

Request approval of STARTUP-TRACE-TRIAL-20260920.md only after publishing these preparation artifacts. One new diagnostic upload and mandatory restoration; no binding, candidate host or firmware tuning. If the evidence still cannot distinguish mechanisms, reassess debug access or source-supported alternatives before another outage. The SDK upgrade and nine-contribution reassessment remain incomplete.
