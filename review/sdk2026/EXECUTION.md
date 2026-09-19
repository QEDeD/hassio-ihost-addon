# SDK 2026.6.1 upgrade — execution record

Updated 2026-09-19. This is the current plan and evidence index. Dated reports retain their evidence; superseded recommendations in them do not override this record.

## Resumption and compression correction

The operator explicitly resumed execution on 2026-09-19. Their earlier statement that the goal was paused was descriptive, not a pause request; the agent's subsequent pause was a mistake. Do not revive that interpretation. Only an explicit operator request authorizes pausing. The goal service was verified active on resumption.

Read this record and the saved goal after compression. Summaries are navigation aids, not authority. Reconcile conflicting summaries against actual operator instructions and update this record. Resume from verified evidence; do not replace execution with another goal-writing exercise or repeat completed checks without a concrete reason.

Current status: execution resumed. September19 read-only checks establish HA has rebooted and is reachable with the original app versions and fresh representative Zigbee/Matter reports. Local Docker has been started for offline checks. All child agents are completed. The live SSH-app flasher is staged and validated without radio access; production flashing/cutover still requires concrete approval. Image publication awaits an explicit confirmation requested after a second automatic-review rejection.

Resume from the remaining route below. Preserve the distinction between completed SSH tool staging and unstarted radio upgrade. Revalidate the baseline/artifacts immediately before any approved cutover; do not repeat unchanged offline tests.

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

The DNS/token-corrected image `local/otbr-sdk2026:state-dns-fixed-20260919` is `sha256:f13e3adaea844f48f9e62b78ef92571a2c2b6790b3bc9da9799098638bf2e115`. [Build](evidence/build-20260919.log), [effective policy](evidence/effective-policy-20260919.json), [assembled verification](evidence/verification-20260919.log), and [missing/malformed-key lifecycle](lifecycle-tests/state-dns-fixed-20260919/results.json) pass offline. It supersedes 7f610 for those changes; the final images below also include the subsequent CPC key-format correction.

Application-only firmware GBL SHA256: `b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50`. Official SONOFF4.6.0/115200 rollback GBL SHA256: `40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787`. Both rehashed September 19. Packaging details: [candidate](firmware/package/README.md), [rollback](recovery/rollback/README.md). Vendor rollback has not been exercised on this radio after candidate binding.

## Latest artifacts and operational evidence

- Corrected runtime image: `local/otbr-sdk2026:key-format-fixed-20260919`, ID `sha256:eb72da990dd231d4cd30134f8af8fb162e7cca2330700635b375c99819d61aea`. Includes vendor CPC key terminal-NUL compatibility, local commit e9efddd. Twenty key-format fixtures and assembled verification pass.
- Final same-app trial image: `local/otbr-sdk2026-trial:0.3.1-sdk2026`, ID `sha256:f34bcbad0113df786aba81619b8ccf2b580bb1ac56ed8f3b3c23acc99c5c0844`. [Final identities](evidence/final-images-20260919.json), [installed files](evidence/final-trial-files-20260919.json), [32 installed-wrapper tests](evidence/trial-final-tests-20260919.log), [assembled check](evidence/trial-final-assembly-20260919.log), [packaging and limits](trial/README.md). Built locally only; not published or installed in HA.
- HA local app staging is accessible through SSH at `/local_apps/codex_ihost_otbr_focused/config.json`; prior `/addons/` paths are superseded. Live version is 0.2.3-ordered, running, boot auto, watchdog/automatic updates false, serial 115200/no flow. Configuration SHA256 ce1e51ff7913a377f7f43903dbe411cf3ef6b711e00514fe28adb9ac28f3a50b. Fresh running immutable image identity remains to verify; version/config alone do not prove it.
- Recovery firmware has built successfully, application-only GBL SHA256 `22c4d75097b5cda0e8d60634cc1753d9615069398055b81b8c5a219e64f49897`. Committed locally as fb64912 with provenance/package evidence. No hardware recovery claim. Removing its automatic boot-time unbind leaves an explicit vendor CPCd --unbind operation; normal candidate security remains unchanged.
- Separate recovery host0.3.2-sdk2026-recovery-unbind: `sha256:048dda7c6872f102376dbd2a83aeaa8d93baa1300b42f4ba667cbd82f05cec27`.23 packaged tests pass; [installed files](evidence/final-recovery-files-20260919.json) match. Explicit unbind and separately selected whole-CPC-directory archival; no normal startup, automatic retry or binding. [Route](trial/RECOVERY-HOST.md).
- [Independent review](recovery/INDEPENDENT-REVIEW-20260919.md) found three material documentation/transition issues, now corrected: shared prepare mode before schema changes, no unimplemented transport-only state, and honest unbound-confirmed evidence. [Operational draft](TRIAL-PROCEDURE.md) and [acceptance observations](recovery/ACCEPTANCE-20260919.md) are not yet an approval request.
- Historical backup independent protected copy is now hash-verified on WSL; [record](evidence/independent-backup-copy-20260919.json). Fresh stopped-writer capture remains required before flash. Selected current Supervisor update/options/backup functions match the previous rehearsal; [source comparison](evidence/supervisor-update-source-20260919.json), so no duplicate rehearsal was run.

## Service-window checkpoint — 2026-09-19

- Local commits before this checkpoint: fb64912, 0f13d45, 87ba0cf. Final normal/recovery images and all three firmware files remain unchanged; no image was published or installed.
- Offline flasher bundle prepared and copied out of temporary storage to `C:/Users/Kristoffer/Git/otbr/sdk2026-flasher-bundle-20260919`. [Manifest](evidence/flasher-bundle-20260919.json) records every package, wheel and GBL hash. Universal Silabs Flasher1.1.0 runs with Python3.14.7 in the official SSH10.5.0 image. With Docker network disabled and no radio device mounted, pip consistency, CLI help and all three GBL metadata parses passed. All three metadata outputs are null (no metadata), not device-compatibility evidence. The APK virtual group added only absent packages; removal restored the original113-package version inventory exactly. No live HA tool installation occurred.
- CLI placement concern resolved by direct inspection of the manifest-pinned1.1.0 wheel: both the top-level parser and flash subparser inherit the same global parser. Existing before-subcommand syntax is supported by source. The hardware-mocked parser test now passes using the installed pinned wheel (evidence/flasher-cli-parse-results.log). Its initial fixture used a nonexistent enum attribute; corrected to the actual enum value before successful rerun. No production radio access.
- Same-tag baseline registry identity rechecked unchanged:0.2.3-ordered index0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107, AMD64manifest3214cb9e1e42f8da631134f4177779ea9acd366273c00c901affab65efb9a4df. This still does not establish the live container digest.
- Automatic approval review rejected the candidate image publication before the command executed. No local tag/push was performed. The stated reason was missing exact authority for external GHCR publication and an asserted local-only restriction. Actual historical operator messages expressly approve `ghcr.io/qeded/otbr-integration-test-amd64` and replacement images under the two-week authorization; verify their dates/scope and review image contents before a legitimate retry, or obtain concrete clarification if unresolved. Do not bypass rejection. This is a publication blocker, not authority to pause the goal on its own.
- Latest tool-runtime goal status was already paused when read, despite the user's preceding execution instruction. No new pause was issued until this NEW service-window request. On resumption follow the actual user instruction; goal tools cannot themselves resume a paused status.

### Retained timing recommendation (proposed, not approved)

Use one normal trial, optional early interrupted-binding recovery R1, and at most one terminal old-firmware/old-host fallback. No candidate retry after old fallback. Downtime begins with the first writer stop. Backup independently verified byT+10 or abort unchanged. Candidate initial traffic or R1 entry byT+20. Normal path: ten-minute observation then restart, accept or begin old fallback byT+35. Reserve20minutes for old fallback and5minutes margin. R1 must finish recovery flash, one explicit unbind, whole-CPC archival, candidate return, one bind and protected key copy byT+35; fresh traffic byT+40, observation/restart byT+50–55. Early R1 failure may use the one terminal fallback if it can begin byT+35. Late R1 failure cannot fit both full acceptance and that fallback allowance in60minutes: preserve current state and obtain an explicit extension/recovery decision. Never interrupt an active flash to meet a timer. Old radio startup after candidate PSA changes remains unproven. This recommendation is now integrated into TRIAL-PROCEDURE.md; do not present the target as a guaranteed outage limit.

## Remaining route

Latest progress: all63 flasher bundle files rehashed with no mismatch. Local Docker started; parser test passed. HA rebooted about72minutes before the18:09UTC check; old multiprotocol0.2.3/Z2M/Matter running, channel25, exact serial target and fresh reports confirmed. Flasher staged and tested in SSH app with original package versions preserved; evidence/live-staging-20260919.json contains exact paths, checksum and cleanup. The radio, networks and app configuration were not changed.

Publication authority audit located original user messages: September13 09:41:55Z approves the exact GHCR destination;10:26:57Z grants two weeks;10:35:03Z explicitly includes replacement images. Date is within that period. Targeted image content checks found no production state/credential directories and no credential environment; fixed USB target identifier is intentionally present (evidence/publication-content-check-20260919.json). Nevertheless automatic review rejected the retry, treating historical evidence as insufficient authority for the exact payload. No tag/push executed. A new user confirmation request is pending for candidate0.3.1-sdk2026 and recovery0.3.2-sdk2026-recovery-unbind at ghcr.io/qeded/otbr-integration-test-amd64. Do not retry through another route or conflate this with production approval.

1. Final normal/recovery wrappers are built and tested. Preserve their exact hashes, source manifests and local commits; do not repeat the completed build or fixture work without a changed path or concrete gap.
2. Finish deployment readiness: resolve the pending publication confirmation, establish exact image delivery to HA and record platform image identities. Flasher/GBLs are already staged and validated; recheck before downtime. Current SSH exposes local app source but not Docker or another app's private data; reuse same-slug Supervisor updates and stopped backups, not new privileged access.
3. The bounded recovery decision tree/time budget is incorporated. The standard Zigbee MQTT get/read route is now documented in recovery/ACCEPTANCE-20260919.md; resolve its actual post-maintenance topic/exposes and confirm Matter fresh-report checks. Read success is not physical control evidence: name any bounded physical control/restoration in the final approval if required, without switching the active computer plug. Incomplete binding remains blocked; R1 and old-firmware fallback must not be stacked opportunistically. Actual radio persistence and old-firmware-after-new-PSA remain hardware uncertainties, not gaps that more synthetic tests can close.
4. Freeze the concrete approval package from TRIAL-PROCEDURE.md with artifacts, staged tools, checks, combined timing and residual risk. Independent review is already integrated; repeat only for material unresolved changes. Obtain production flashing/binding/cutover approval before mutation. Fresh coherent backups and independent protected copies are made in that approved window before flash.
5. After approval, execute bounded trial, verify encrypted CPC, identities/membership, representative Zigbee controls/reports, Thread/Matter behavior, discovery and restart persistence. Compare baseline and candidate, capture latest state before rollback if needed. Finish only on accepted upgrade, current recovery instructions and experimental cleanup; rollback alone is not goal completion.

## Superseded history and limits

- Older STATUS/INSTALLATION-PROPOSAL reports name identification, missing backup coverage or a spare as the next step. Identification and backup coverage are closed; freshness/coherence remain. A spare is an alternative, not an assumed prerequisite.
- Former channels15/20 and older image identities are historical.
- No physical candidate acceptance, encrypted binding or radio downgrade has been demonstrated. Matching file layouts and synthetic preservation do not establish runtime security semantics or recovery.
- Only the main agent performs production mutations within an approved procedure. Credentials/raw state stay outside Git and ordinary tool output. Offline test containers are stopped after use; historical evidence is retained.
