# Route after the successful HFXO diagnostic

## Evidence and remaining question

Original CPC-only and HFXO-enabled CPC-only SDK2026 images both answer on the existing dongle. The full multiprotocol image does not. Original4.6.0 restoration and representative network checks passed after every completed diagnostic; this does not prove recovery after binding or candidate network traffic. Current production remains the original app/firmware. No spare is assumed.

The next exact extra full-image operation is protocol-crypto mask seeding, including a RADIOAES busy wait and PSA/SE randomness. Source review found the required initialization present, including sl_se_init inside the HSE randomness helper. No corrective source defect has been established.

## Selected implementation

Build the proven HFXO+CPC recipe with the existing vendor sli_protocol_crypto component. Actual generation confirms only the component catalog and two service-init calls change; source/configuration remain identical and no radio/Thread stack is introduced. Linked review confirms the target operation survives compilation. This bounded offline implementation and application-only package validation are complete.

Prefer this route now over full-image tracing because it reuses an existing component, avoids sharing diagnostic output with the CPC UART, and tests a concrete startup difference with a small implementation. The hardware question cannot be answered by compilation. A new approved two-upload window would test it once and restore old firmware.

## Critical assessment and decisions

- A pure build success does not locate a runtime fault. This probe supplies a bounded runtime observation of the isolated configuration.
- A passing reply establishes startup including the added crypto initialization returns in this configuration. It does not prove encryption, radio calibration, Thread operation or the full image. Keep inherited-clock, optimization/layout and other full-image differences open.
- A silent diagnostic still cannot distinguish the RADIOAES wait, entropy error trap or another interaction. The diagnostic retains an entropy assertion absent from the full image. If it fails, inspect exact fault/wait evidence before declaring it the original cause or proposing a change.
- Do not add a second non-asserting firmware now merely to match the full image. That changes two variables and adds a service window without current evidence of entropy failure.
- Do not disable crypto, change CTUNE, replace the bootloader or erase state speculatively. Missing PSA/SE initialization is contradicted by source/linked evidence.
- Full-image startup checkpoints could identify several stages in one window, but useful output must be retrievable after a hang without disturbing CPC transport or relying on a debugger the operator does not have. That is greater implementation uncertainty than this already clean vendor split.
- Avoid an indefinite component-at-a-time sequence. If this test passes without revealing a concrete corrective mechanism, prioritize observable full-image startup checkpoints rather than another routine component-by-component outage. A failed test also calls for observing the wait/error boundary before changing settings. Any departure from that route needs new evidence of a material advantage, not momentum from the previous diagnostic.
- Reuse the exact hardware-proven controls without reflashing them. Baseline old-firmware probe, one new image and mandatory old restoration suffice. Fresh backups and actual-state checks remain necessary; unrelated offline suites do not.

## After the next observation

If crypto startup passes, the remaining full-image radio/Thread startup and its different platform/compiler context become the main candidates. If it fails, plan directly observable diagnostics of the wait/entropy outcome before a correction. If output is partial or malformed, analyze that narrower transport/property failure first. If restoration fails, stop candidate work and address the exact production state within separately approved recovery limits.

Once a credible corrective mechanism exists, rebuild the full image and reassess the original binding/network/restart trial against the new firmware. Reuse compatible host-state and recovery evidence; repeat checks invalidated by changes. Preserve identities/membership/channel25 and qualify encrypted CPC, representative Zigbee/Matter operation and restart persistence. Distinguish technical upgrade success from demonstrated reliability gains. Reassess the nine contributions when a correction changes their necessity or implementation; this diagnostic alone changes none.

Next operator boundary: approval of CRYPTO-TRIAL-PLAN-20260920.md after completed independent review (CRYPTO-INDEPENDENT-REVIEW-20260920.md). Preparation needs no further operator choice. Prior physical-test approvals are consumed; current work is offline and local, not publication authority.
