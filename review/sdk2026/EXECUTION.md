# SDK2026.6.1 upgrade — current execution record

Updated September20 after accepted full-functional production upgrade. Read this file and saved goal after compression. Actual operator instructions take precedence over compressed summaries. Earlier descriptions of paused status were not pause requests; do not revive that mistake.

## Objective and outcome

The personal SDK2026.6.1 multiprotocol app + SONOFF ZBDongle-E firmware upgrade is accepted live. Existing Zigbee and Thread/Matter networks are retained without re-pairing, on channel25, using encrypted CPC. Representative operation and a controlled app restart passed. All nine prepared upstream contributions have been reassessed. Technical upgrade success does not establish improved long-term reliability/performance.

Authoritative result: [FULL-FUNCTIONAL-RESULT-20260920.md](FULL-FUNCTIONAL-RESULT-20260920.md), [structured evidence](evidence/full-functional-result-20260920.json). Current contribution disposition: [reassessment](recovery/UPSTREAM-REASSESSMENT-20260920.md). No further production action is necessary for the approved trial.

## Current production pair

- Same app local_codex_ihost_otbr_focused, version0.3.1-sdk2026; image index sha256:f34bcbad0113df786aba81619b8ccf2b580bb1ac56ed8f3b3c23acc99c5c0844.
- Normal application-only firmware713d18d799727d4b85cd2fd657617522f4adc3bb62e79d83758d782dc261f604, from firmware/receive-fix/package/receive-fix-sdk2026-application-only.gbl. Only the reviewed bootstrap UART receive correction is added to original full configuration. No diagnostic instrumentation.
- CPC4.9.1 encrypted; host Zigbeed9.1.1/EZSP19; Z2M2.14.1-1 and Matter9.2.0. Original boot/watchdog/update policies restored, services running. NAT64 remains off. Original113SSH packages exactly restored; temporary flasher/venv removed.
- Existing coordinator/PAN/key/channel25 and30Zigbee registrations preserved. Live Thread identity/key/PSKc/prefix/channel match saved preferred dataset; full active dataset and node identity match across restart. All4Matter devices available. ZigbeeLevelControl1 and ALPSTUGAIdentifySuccess plus fresh measurements before/after restart.

## Authority and consumed work

Operator explicitly approved proceeding including deploying everything to HA and firmware testing. The reviewed full-functional procedure ran once and succeeded: backup, same-slug host update, one normal candidate flash, one encrypted bind, independent key backup, normal networks,616.6seconds observation, one controlled stop/backup/restart, acceptance, policy/tool cleanup. No terminal fallback/R1/unbind/rebind occurred. Do not replay completed scripts or ask for duplicate deployment approval.

Parent owns production mutations. No arbitrary erase, bootloader/SE update or unlimited retry authority. Existing permitted Git pushes/registry uploads do not authorize public upstream comments or PRs. No public upstream posting occurred. The user's no-spare assumption still applies.

## Recovery evidence and boundaries

Private authoritative events/backups: /home/wsluser/.local/share/ha-recovery/sdk2026-functional-20260920 (0700, protected backup/key files0600). HA staging: /share/codex-sdk2026-functional-20260920. Fresh coherent initial three-app backup + direct HAconfig archive; separate bound and accepted-pre-restart focused-app backups independently copied/hash-verified. Entire CPC directory, key and intent/completion markers retained; same key across restart. Latest coherent candidate stores are in accepted-pre-restart-apps.tar. Never overwrite advanced counters with initial/stale stores.

Original4.6.0 GBL40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787 and host0.2.3-ordered are retained. Prebinding physical restoration was demonstrated historically; post-binding old-radio PSA/storage compatibility remains untested. Old recovery-only22c4 firmware retains stock faulty receive initialization and is not a qualified recovery route. Keep current matching key/stores; do not improvise unbinding or erasure. Any future flashing needs a concrete applicable scope and staged tools; none is currently needed.

## Observations that remain qualified

Eight LinkAcceptSecurity warnings in228ms after initial router promotion, one after restart. No unexpected detachment or lost representative traffic observed. Vendor/upstream semantics permit challenge/state mismatch; exact cause unproven. Record as startup anomaly, not proven regression or guaranteed harmlessness.

The restart guard initially stopped on extra32byte Thread0_0-tmp.data. Exact pinned tmp_storage.cpp/.hpp and actual record keys/lengths establish boot-time/radio-metrics storage, separate from original network store. Kept all files, corrected role-based check and resumed. Zero-EUI temporary basename initialization cause not investigated. No state was erased/restored.

Some historically unreachable Zigbee devices still failed pings. Final new unavailable entities were outside MQTT/Matter (dishwasher option and iPhone camera motion); causes not investigated. App restart passed; power-cycle/HAOS reboot, long-term reliability, new-SDK NAT64 and exhaustive discovery/commissioning remain outside these acceptance claims.

## Useful follow-up, not unfinished deployment

Upstream the narrowly evidenced receive correction only under applicable publication authority. Keep the nine contribution dispositions/attribution in the linked reassessment; SDK native mDNS/new builder supersede some legacy implementation details. Qualify a corrected recovery-only firmware only if its additional recovery value warrants the work. Revisit startup warnings if they recur after settling or correlate with lost traffic. Do not repeat completed broad investigations merely because context was compressed.

Historical evidence: RECEIVE-BOOTSTRAP-RESULT-20260920.md and RECEIVE-FIX-REVIEW-20260920.md establish diagnosis and normal artifact. Earlier trial documents preserve consumed experiments/authority; they do not describe current production. Live access follows the main HA repo runbook and interactive ha-unlock --check-access; shared credentials can relock.
