# Current likelihood assessment — 2026-09-14

The operator accepts the previously estimated ordinary outage (15–30 minutes, allowing 45) and straightforward rollback case (20–60 minutes). This is not approval to flash and does not accept an unbounded recovery. These remain estimates, not measured hardware results.

## New evidence

- Actual generated zigbeed selects classic host token storage, software AES and STACK_UNIX. Zigbee network keys are not being migrated into radio PSA by this candidate. CPC transport binding is separate. See token-schema/ASSESSMENT.md.
- The retained host token backup has format byte 2, avoiding the vendor's explicit version-1 migration blocker. Matching format does not prove matching token layouts. The loader can default records on element-size/type changes and truncate smaller arrays; it rewrites the file.
- Zigbee configuration specifies channel 20 (configured, not independently verified live channel); the live OTBR active dataset reports channel 15. The firmware README says same-channel, but current vendor architecture documentation explicitly supports different channels on xG21 through concurrent listening. The candidate-clean component catalog and linker map include fast channel switching and DMA; generated configuration enables both. There is no demonstrated channel incompatibility and no justification for migrating either network's channel.
- Vendor documentation notes reduced receiver sensitivity with concurrent listening. Test existing marginal devices during the trial; do not assume this is newly introduced relative to the existing firmware.

Source: https://docs.silabs.com/shared-content/1.0.7/multiprotocol-solution-linux/system-architecture
Local evidence: ../firmware/candidate-clean/autogen/sl_component_catalog.h; ../firmware/candidate-clean/config/sl_rail_util_ieee802154_fast_channel_switching_config.h; ../firmware/candidate-clean/config/sl_rail_util_dma_config.h; ../firmware/candidate-clean/artifacts/rcp-uart-802154.map.

## Assessment

Build/package confidence is strong within the checks performed: reproducible application-only GBL, bounded address ranges, compiled host applications, linkage and offline API/service tests. Those tests cannot establish bootloader acceptance, encrypted handshake, radio performance or successful downgrade on this physical dongle.

Successful operation is plausible; a numerical probability or claim of high confidence in recovery is unsupported. The largest remaining consequence is failed state-preserving rollback on the only dongle, not routine build failure. The retained tested old host image and verified host backup improve recovery preparation but do not restore radio flash/NVM through the serial bootloader.

## Targeted next work

1. Compare network-critical host token descriptors with the actual candidate's initialized descriptors. Static ELF inspection cannot provide these dynamically registered tables. A narrow vendor-routine-based extractor is justified; a general migration framework is not. Never run the candidate against the only baseline token copy. Descriptor equality still does not prove semantic compatibility.
2. Prepare explicit pre/post comparisons for network identity, device availability and working Zigbee/Matter control, including marginal devices and restart persistence. Preserve the old image and fresh private state independently. Account for counter advancement before deciding which state to restore.
3. Keep the bootloader unchanged. Hardware boot, CPC binding persistence and old→new→old operation remain hardware-only uncertainties. A production trial still needs an explicit decision that addresses the unresolved longer-recovery case; accepting the ordinary outage alone does not resolve it.

No production firmware, services, binding, channel or network state was changed in this assessment. Evidence is local only; no publication.
