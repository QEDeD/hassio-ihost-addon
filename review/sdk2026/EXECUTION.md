# SDK 2026.6.1 upgrade — execution record

Updated 2026-09-19. This is the current plan and evidence index. Dated reports retain their evidence; superseded recommendations in them do not override this record.

## Outcome and authority

Deliver a maintainable SDK2026.6.1 multiprotocol app and ZBDongle-E firmware combination, preserving Zigbee and Thread/Matter networks without re-pairing. Personal AMD64 qualification comes first. Offline preparation and read-only checks are authorized. Production flashing, CPC binding and disruptive cutover require approval of a concrete procedure. Publication has separate authority. No spare is assumed.

Expected benefits: a current vendor stack and reproducible build, encrypted CPC between host and radio, and newer stack fixes. Offline checks establish preparation, not hardware operation or improved reliability. Do not promise a cure for previous radio failures or missed light commands.

## Established starting point

- September 19 read-only HA check: HAOS18.3, Core2026.9.3, Supervisor2026.09.2, Docker29.7.2, AMD64, running and supported. Actual app package/image identities must be rechecked before the trial.
- Channel25 migration and phone resynchronization are complete. Powered-off devices are not migration failures.
- Hardware: ZBDongle-E; recorded probe Sonoff1.0.1 / Gecko Bootloader1.12.00, CPC4.6.0. Preserve bootloader and Secure Engine.
- September 14 archive covers focused app state, actual Z2M directory, HA and Matter. It is a historical hot backup, not a current coherent recovery point. Fresh stopped-writer capture plus an independent protected copy is required in the approved maintenance window.

## Completed preparation

| Area | Evidence and decision |
| --- | --- |
| Zigbee migration | Found and fixed packed-default indexing in the vendor host-token loader. Exact rebuilt ELF preserves all 26 original nonempty synthetic records and correctly initializes 257 new/expanded elements. Local commit 0719b88; [result](recovery/token-schema/RESULT-20260919.md). |
| Zigbee backward loader | Actual old ELF preserves tested original keys, identity and advanced synthetic counters, but discards newer metadata and child arrays. This is not a lossless downgrade or physical network recovery proof. Retain latest state before any rollback. |
| Thread storage | Actual old/new POSIX backends pass old→new→old→new synthetic reads/writes, including preservation of a newer-only record. Relevant network-info structures unchanged. [Scope and counter reasoning](recovery/thread-state/README.md). Never overwrite latest state with a stale snapshot after candidate traffic. |
| DNS | Reused credited upstream host/RDNSS routing fix rather than the obsolete global binding override. Six actual-source behavioral groups plus negative control pass. Effective binding macro 1 and full image verified. Local commit ffcf252; [tests](dns-tests/README.md). |
| Consumers | Candidate EZSP19 is supported by the previously observed herdsman10.9.2. HA2026.9.3 uses the same python-otbr-api2.10.0 already exercised in the eight API groups. Reverify installed consumer identity before cutover; [record](recovery/CONSUMER-COMPATIBILITY.md). |
| Nine contributions | All nine reassessed against current vendor/HA/community work. Most retained; DNS adapted, external mDNS/SLC input work partly superseded. [Disposition](recovery/UPSTREAM-REASSESSMENT-20260919.md). Publication remains separate. |

The DNS/token-corrected image `local/otbr-sdk2026:state-dns-fixed-20260919` is `sha256:f13e3adaea844f48f9e62b78ef92571a2c2b6790b3bc9da9799098638bf2e115`. [Build](evidence/build-20260919.log), [effective policy](evidence/effective-policy-20260919.json), [assembled verification](evidence/verification-20260919.log), and [missing/malformed-key lifecycle](lifecycle-tests/state-dns-fixed-20260919/results.json) pass offline. It supersedes 7f610 for those changes but is NOT the final trial image: subsequent CPC key-format correction still needs inclusion.

Application-only firmware GBL SHA256: `b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50`. Official SONOFF4.6.0/115200 rollback GBL SHA256: `40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787`. Both rehashed September 19. Packaging details: [candidate](firmware/package/README.md), [rollback](recovery/rollback/README.md). Vendor rollback has not been exercised on this radio after candidate binding.

## Remaining route

1. Finish deployable same-app trial packaging using the existing local-service wrapper. Implement only the missing explicit one-shot binding path if no supported existing path suffices. Preserve current whole /data, existing endpoints and one radio owner; no stale re-import. A newly found vendor ECDH key terminator mismatch is corrected in source and passes 20 fixtures plus an old-checker negative control; include in the next image.
2. Finalize the state-transition and recovery procedure. Host loaders are now tested within the limits above. Persistent radio PSA/NVM behavior after encrypted binding, physical acceptance and old-firmware recovery remain hardware uncertainties. A failed or interrupted bind may already have bound the radio even if the host key is missing; never retry automatically.
3. Verify final wrapper/artifact identities, deployment and latest-state capture routes, protected independent backup destination, pinned recovery tools and actual baseline. Reuse passed checks unless a changed path or concrete gap justifies repetition.
4. Prepare a concrete approval package: exact artifacts and ordered actions; representative acceptance; latest rollback trigger and total interruption proposal; required operator assistance and residual recovery risk. Obtain a fresh-context high-reasoning review before requesting approval. No production mutation before approval.
5. After approval, execute bounded trial, verify encrypted CPC, identities/membership, representative Zigbee controls/reports, Thread/Matter behavior, discovery and restart persistence. Compare baseline and candidate, capture latest state before rollback if needed. Finish only on accepted upgrade, current recovery instructions and experimental cleanup; rollback alone is not goal completion.

## Superseded history and limits

- Older STATUS/INSTALLATION-PROPOSAL reports name identification, missing backup coverage or a spare as the next step. Identification and backup coverage are closed; freshness/coherence remain. A spare is an alternative, not an assumed prerequisite.
- Former channels15/20 and older image identities are historical.
- No physical candidate acceptance, encrypted binding or radio downgrade has been demonstrated. Matching file layouts and synthetic preservation do not establish runtime security semantics or recovery.
- Only the main agent performs production mutations within an approved procedure. Credentials/raw state stay outside Git and ordinary tool output. Offline test containers are stopped after use; historical evidence is retained.
