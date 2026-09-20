# Receive snapshot review — September 20, 2026

Fresh-context GPT-6 Astra/high reviewer reviewed the source and linked delta independently. No blocking correctness issue found. Parent owns build/parser/package verification; review is not flash authorization.

- First-bad metadata is published before first_bad_seen store0xCF54. Existing vendor invalid-checksum increment follows0xCF58.
- Resize0x649E retains received>=requested handling; cmp0x6500/bcc0x6504 enters arithmetic only for received<requested. Return scopes preserved.
- Callback classification at0xBDF4 and recovery counters measure entries, as documented.
- Getter is inlined into SysTick after cpsid i0x174D2; bounded LINK access0x17548–5E, fixed descriptor loads0x17564–7A and pointer comparisons0x1758A–9E. No pointer traversal or payload export.
- Previous timer/takeover logic is unchanged. Schema appends30 fields:101 total,929bytes,RXS1 discriminator. Capture source differs only in newline format.
- Minor documentation correction incorporated: first_bad_driver_length is sampled after the core oversized-frame clamp, not always raw driver length. Expected length10 is unaffected; no rebuild warranted.

Parent confirmed exact-target compile, five parser tests, identical generated config, source-equivalent capture adapter and strict application-only packaging. Full output remains locally reproducible; recipe, identities, package and concise evidence are retained rather than duplicating another generated SDK source tree.

## Relevant vendor work checked

[Platform MCU6.1.1 notes](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-platform-release-notes/sisdk-plat-mcu-release-notes) describe DMA Channel Driver fix1686377 for equal update/completed counts and HAL change1563576 clearing CHDONE before a new transfer. CPC's own resize function already branches on received>=requested before remaining-1, so the documented equal-count correction is not evidence of an applicable patch here. Keep CHDONE handling as receive-state context; this review has not established a missing clear. [CPC4.9.1 notes](https://docs.silabs.com/sisdk-release-notes/2026.6.1/sisdk-platform-release-notes/sisdk-plat-cpc-release-notes) provide no demonstrated fix for this observed path. Do not substitute a speculative workaround.
