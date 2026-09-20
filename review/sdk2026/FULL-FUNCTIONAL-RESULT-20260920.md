# SDK2026 full upgrade accepted live — September20

The normal receive-corrected application and encrypted host app are now running on the existing SONOFF ZBDongle-E. The approved representative acceptance checks and controlled app restart passed. The existing Zigbee/Thread/Matter networks were retained without pairing or channel changes. No rollback or recovery firmware was used.

## Exact deployed combination

- Host same slug local_codex_ihost_otbr_focused, version0.3.1-sdk2026, published index sha256:f34bcbad0113df786aba81619b8ccf2b580bb1ac56ed8f3b3c23acc99c5c0844. Manifest retrieved and verified from HA immediately before deployment.
- Normal application-only firmware firmware/receive-fix/package/receive-fix-sdk2026-application-only.gbl, SHA256713d18d799727d4b85cd2fd657617522f4adc3bb62e79d83758d782dc261f604. One successful pinned-flasher upload. CPC4.9.1 normal response, no diagnostic instrumentation. Bootloader/SE unchanged.
- Host Zigbeed9.1.1, negotiated EZSP19, Z2M2.14.1-1, Matter9.2.0. Existing TCP9999 endpoint and all other radio options retained. NAT64 remains off.

## What passed

Fresh stopped-writer three-app and separate HA configuration backups were copied to independent protected WSL storage and hash-verified before flash. Candidate host updated while stopped, before firmware change. One bind-ecdh succeeded; the durable private key and intent/completion markers were verified in a complete independent focused-app backup before networks started. CPC use_encryption=true and fresh bidirectional Zigbee/Thread traffic establish functioning encrypted operation on this pair.

All30 Zigbee device registrations remain. Coordinator identity, PAN/extendedPAN, key and channel25 match baseline. The active live Thread network's identity/key/PSKc/prefix/channel match the preferred saved dataset; its entire active JSON dataset and node identity match across restart. The existing actual network store data/thread/0_b43522fffec11b30.data remains selected. All four Matter devices are available and reported after cutover; no previously available MQTT/Matter entity was unavailable in the final comparison.

Explicit Zigbee LevelControl reads returned currentLevel1 before and after restart. ALPSTUGA15second Identify returned Matter Success before and after restart, with fresh changing measurement reports. OTBR REST returned200 and joined the original partition as router. No plugs or lighting groups were toggled. These checks establish representative communication, not every device's physical actuation or future commissioning.

Observed616.6seconds after the first successful requests before controlled restart. At the restart stop, a coherent full candidate-state backup confirmed the identical CPC binding key; services then resumed and the same checks passed. Intended automatic boot/watchdog/update policies were restored. Only the temporary flasher/venv/APK group was removed; all113 original SSH packages exactly match the baseline. Accepted app, Z2M and Matter are running.

Service interruption was approximately4m52s for deployment and3m02s for the controlled restart, including investigation of the guard described below. See structured evidence for exact timestamps and scope.

## Findings and limits

- Eight Link Accept - Security warnings occurred in one228ms burst after initial child-to-router promotion. One occurred after the controlled restart. Fresh traffic/attachment continued, with no unexpected detachment observed. Independent bounded review found this can represent an unmatched/superseded link challenge, not necessarily a wrong network key; exact cause is unproven. Preserve as startup anomaly, not a demonstrated reliability regression or baseline-equivalent warning.
- The restart helper initially refused an extra32byte data/thread/0_0-tmp.data. Pinned vendor tmp_storage.cpp/.hpp define a separate temporary store for boot time and radio Spinel metrics; actual records matched keys1/2 and lengths8/16. The original network settings store and CPC key were intact. The check was corrected to distinguish these file roles; no file was deleted/restored. The zero-EUI temporary basename is recorded without inventing its initialization cause.
- Existing unreachable Zigbee-device pings remain; powered-off devices are not reclassified as upgrade regressions. A dishwasher option and iPhone camera-motion entity changed availability outside MQTT/Matter; their causes were not investigated here.
- App-restart persistence passed. Power loss, host reboot, long-term reliability/performance improvement, every multicast/discovery scenario and NAT64 on the new SDK were not tested. There is no claim of error-free logs.
- Recovery after candidate-created PSA state is still untested. Retain the matching key and latest stores; never overwrite advanced counters with the initial backup. Old firmware/application artifacts remain available, but old-radio storage compatibility is not guaranteed. The old recovery-only22c4 firmware retains uncorrected UART startup and is excluded from qualified recovery paths.

## Maintenance and recovery references

Authoritative private evidence/backups: /home/wsluser/.local/share/ha-recovery/sdk2026-functional-20260920 (0700; backup/key material0600). HA staging: /share/codex-sdk2026-functional-20260920. Initial, bound and accepted-pre-restart backups are separate immutable captures; their manifests/hashes are private. They are evidence/recovery materials, not permission to restore stale network counters. The temporary flasher runtime has been removed and must be staged again if needed.

Normal firmware reproduction and source/linked checks: firmware/receive-fix/README.md and RECEIVE-FIX-REVIEW-20260920.md. Revised trial and independent review: FULL-FUNCTIONAL-TRIAL-20260920.md and FULL-FUNCTIONAL-REVIEW-20260920.md. Structured sanitized result: evidence/full-functional-result-20260920.json. All nine contribution dispositions: recovery/UPSTREAM-REASSESSMENT-20260920.md. No upstream public comment/PR was posted.
