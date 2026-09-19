# Independent procedure review — 2026-09-19

Fresh-context GPT-6 Astra/high worker review, read-only. The parent integrated its findings; the worker did not independently rerun the parent-built final normal image tests. This is preparation review, not production approval or a declaration that staging is complete.

| Material finding | Resolution |
| --- | --- |
| P1: recovery-only mode values could prevent return to the candidate schema during downtime. | Added an explicit image/version/mode table. Set the shared prepare value while stopped before every update; never start import mode against existing stores. |
| P1: transition record required an unimplemented transport-only reconnect and cited superseded host. | Reconciled S2/S3 with real wrapper behavior. Incomplete bind blocks normal run; successful bind is backed up before first normal startup, which immediately enters network-active S4. No new transport-only subsystem. |
| P2: documents promised deletion-vs-already-unbound detail that the wrapper discards. | Adopted the honest narrower unbound-confirmed outcome for either successful vendor status. No raw log retention or warning parser added. |
| Socket readiness is not encrypted-session evidence. | Added ACCEPTANCE-20260919.md: exact encrypted host/config/firmware endpoint, private key continuity and fresh bidirectional traffic after normal startup and app restart. TRACE_SECURITY is intentionally not enabled. |

Reviewer independently rehashed all three GBL artifacts, inspected the bounded recovery wrapper, and accepted same-slug stopped updates/current-state preservation and ordinary ordered startup as the simpler route. Actual flashing/binding, radio persistence and old-firmware startup remain hardware uncertainties requiring an explicit risk decision, not more synthetic tests or an assumed spare.

Remaining readiness work: finish delivery/staging and final execution-host identities, stage the pinned flasher before downtime, confirm the named baseline observations and request paths, and freeze combined R1/old-firmware branch timing. Fresh coherent backups are taken inside the approved window before flash. The parent still owns final integration and approval request. Repeat review only for material changes or unresolved concerns.
