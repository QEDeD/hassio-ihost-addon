# Investigation route after the CPC diagnostic — September 20

## Evidence and objective

Deliver the SDK2026.6.1 multiprotocol upgrade, preserving the existing Zigbee/Thread networks. The full candidate uploads but produces no observed serial RX after probe open/flush. The existing CPC-only SDK2026 image returned both version replies on this dongle; official4.6.0 was restored and Zigbee/Matter operation verified. No binding or candidate host startup occurred. The underlying fault remains unproven.

The extra full-image startup includes external crystal initialization, protocol-crypto/RADIOAES work and RAIL/OpenThread initialization. Source and linked code contain waits/traps in these paths; neither missing PSA initialization nor missing radio unlock was established. Clock configuration headers alone were misleading: AUTO enables the crystal only when RAIL is included. See STARTUP-PATH-REVIEW-20260920.md and DIAGNOSTIC-RESULT-20260920.md.

## Chosen route and alternatives

1. **One-setting CPC diagnostic first.** Explicitly enable crystal initialization in the hardware-proven CPC-only image, retaining the other settings, source and non-LTO compiler configuration. It isolates a consequential difference using a supported vendor setting and existing build/package tools. Offline build, source/config comparison and package checks are complete; independent procedure review is required before requesting approval.
2. **Use the result to choose the next experiment.** A successful reply establishes that the HFXO-enabled CPC-only configuration reaches communication under this boot sequence. It makes protocol-crypto/RADIOAES and RAIL/OpenThread startup the next priorities, while retaining inherited-clock/timing interactions: vendor initialization may skip crystal reinitialization if SYSCLK already uses HFXO. Audit component/dependency changes before choosing another minimal variant. If adding a component pulls in several stages or another single-stage test would offer little information, prefer a bounded, retrievable startup trace of the full image. Do not mandate a succession of one-feature service windows.
3. **If the crystal diagnostic is silent**, inspect the added wait/initialization path and differences from SONOFF/vendor working board configuration. Prefer directly observable fault/wait evidence before tuning. Passing CPC without RAIL does not prove sustained crystal/RF operation; failing after one config change still allows timing/layout interactions. A baud sweep, CTUNE128→140, bootloader update or security downgrade has no evidentiary justification yet.
4. **Apply a correction only after identifying a credible mechanism.** Reuse vendor/community fixes if applicable, retain attribution and verify the exact changed path offline. Rebuild the full image and prepare a separately approved version-query/binding/network trial. Preserve the existing host-state compatibility and recovery findings; repeat only checks invalidated by changes.
5. **Qualify the actual upgrade.** Prove encrypted CPC binding, preserved identities/membership and channel25, representative Zigbee/Matter operation, discovery and restart persistence under the reviewed main trial/recovery procedure. Startup diagnostics alone do not satisfy these milestones. Record measured benefits separately from successful upgrade, and reassess all nine prepared upstream contributions against any resulting changes.

**Why not other routes now:** Full-image serial instrumentation could locate several failures in one window, but adds transport/timing and implementation uncertainty before the simple crystal question is answered. Blind clock changes confound diagnosis. Reflashing unchanged controls spends service time without new evidence. Updating bootloader/SE or requiring a spare now would expand risk or operator cost without an established need. A spare remains a useful alternative if repeated disruptive tests or recovery uncertainty become unacceptable; none is assumed available.

## Critical checks and refinements

- Same source headers are insufficient: compare actual generated catalog and linked code. Preserve non-LTO recovery compilation; the full image already differs in optimization/layout.
- Version probing observes only bytes after serial open/flush, and RTS/DTR change on open/close. Use the same tool, timing and DEBUG logging as the demonstrated controls; do not describe it as passive observation.
- Crystal enabled does not mean SYSCLK changed to the crystal. Verify that HFXO initialization is added while SYSCLK/PCLK selection remains unchanged.
- The image initializes persistent storage even without binding. The previous CPC-only→old transition worked, but the new artifact still has residual hardware/recovery risk. Host backups cannot restore dongle NVM.
- Do not overbuild before hardware evidence. Package one diagnostic and review one bounded window; leave follow-on implementation contingent on its result.
- Protect the useful outcome: every diagnostic branch ends on official old firmware; never let a version reply silently authorize binding or normal use.
- No changes to upstream contributions are justified by this diagnostic alone. Startup-related changes will be reassessed when there is a demonstrated corrective patch.

## Deliverables and next action

Prepared firmware and evidence: firmware/cpc-hfxo-diagnostic/README.md. Proposed hardware procedure: HFXO-TRIAL-PLAN-20260920.md. Production flashing and disruption require a new concrete approval; the two earlier September20 trial allowances are consumed. Publication is separate. No unresolved technical choice needs operator input before completing these preparations.

Linked-code caveat: the vendor initializer skips crystal reinitialization when inherited SYSCLK is already HFXO; the full candidate has the same guard. A version reply proves that the configured startup path returns under this boot sequence, not that every crystal wait executed. Record this limitation and retain the same upload/open sequence; a further test is worthwhile only if it resolves the remaining mechanism.
