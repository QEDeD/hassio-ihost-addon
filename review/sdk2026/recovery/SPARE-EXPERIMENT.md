# Proposed spare-radio experiment — approval required

## Decision and purpose

Use one spare SONOFF ZBDongle-E with existing Gecko1.12.00, attached to a dedicated Linux serial endpoint. Keep the production radio and its networks untouched. Reuse the retained vendor firmware, existing application-only SDK2026.6.1 package, existing host images, universal-silabs-flasher and CPCd. Do not build another bootloader, add a custom memory-dump protocol or remove encryption.

External dependency: a spare same-model dongle and an accessible Linux serial connection have NOT been established. The next operator action is to provide/identify that spare and the test host. Physical USB attachment/passthrough and the actual serial-by-id path must be verified before running the commands below. Do not assume Windows Docker can access a USB radio directly. This is a defined experiment, not an executable production cutover.

Why this route: source review narrows network recovery to compatible host stores, effective identities, counters, calibration and CPC transport. Existing vendor token loading supports creator-based restoration/reordering, but rewrites host_token.nvm during startup (sl_zigbee_token_host.c:510–615). Current saved token version2 avoids the explicit v1 rejection, but exact semantics and downtime counter behavior remain untested. Hardware acceptance and encrypted key persistence can now be tested without exposing the only working networks.

## Reused artifacts

- Candidate host local/otbr-sdk2026:encrypted, local image identity sha256:7f6104879bfe004823b03c3db5ba67d90ea1366d854372bba1732baa1e250f6b; CPCd4.9.1/87f6dbda4eef05e4538589c195099c3daf8f6f6b.
- Retained old host ghcr.io/qeded/otbr-integration-test-amd64@sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107; CPCd4.6.1.0/a15eb6b608497535dd1c3d9bd8871f6a4865c443; plaintext baseline.
- Candidate firmware firmware/package/output/rcp-sdk2026-application-only.gbl, SHA256b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50.
- Old SONOFF firmware recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl, SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Published matching artifact, not proven installed bytes.
- Existing universal-silabs-flasher1.1.0, previously used for our probe. Validate installed help/version at execution; do not substitute another flasher or use --force automatically.

Transfer existing images/artifacts to a separate test host if necessary through private local transport (for Docker images use docker save/load); do not publish them. Verify archive/file hashes there. Before export and after import record the selected image architecture, image configuration identity where the engine exposes it, and RootFS layer identities. Compare these platform-specific records; do not require registry RepoDigest/index metadata to survive docker save/load. The baseline digest above identifies an OCI index, not its configuration blob.

## State and isolation

The spare must have no network state the operator wishes to retain. Do not erase it to satisfy that condition. If it is already CPC-bound or owns a wanted network, stop and identify the correct existing key/backup or another spare.

Create a dedicated private test directory outside Git with mode0700, under umask077. Preserve separate old-host and candidate directories. Do not copy production Zigbee tokens, Thread datasets, Matter fabrics or network keys into the spare test: it must never impersonate the production coordinator or border router. Use no production HA app volume, host network namespace or mapped production USB device. Logs and binding credentials remain private, with only redacted results recorded.

Our host recovery reference is backupfeec49c2 (BACKUP-20260914.md), approximately124MiB, root0600, not encrypted. Refreshing a production backup is outside this experiment's execution scope. Do not restore that backup to a live parallel controller. Its existence supports later production planning, not this disposable spare's identity.

## Stages and decision points

1. Verify spare model/serial mapping; record existing bootloader and application versions using the established probe. If its bootloader differs from1.12.00, record the difference and reassess representativeness; do not downgrade/upgrade its bootloader.
2. Establish an old-firmware baseline on the spare using the retained SONOFF GBL if needed. Confirm upload/launch and CPC4.6.0 communication with the retained plaintext host. Preserve logs and effective radio EUI where the standard client exposes it. No networks are formed.
3. Stop and release the baseline serial client. Flash only the candidate application GBL. Confirm bootloader upload completion and launch, then use universal-silabs-flasher with --probe-methods cpc:115200 to inspect CPC version without starting candidate CPCd. Do not run the encrypted daemon, even --secondary-versions, before explicit binding: its missing-key behavior is not safe to assume side-effect-free. Failure to launch is a trial result; do not conceal it with retries or a bootloader change.
4. With all normal clients stopped, explicitly bind ONCE using vendor CPCd ECDH. Preserve the newly created host key immediately in a second private copy. Validate expected format/permissions with the existing candidate preflight; never output the key. If already bound, missing/mismatched credentials or unexpected key creation occurs, stop rather than unbind/erase/retry binding.
5. Start the candidate CPC daemon with that key. Require evidence of a successful encrypted security session, not merely a running process. Stop/restart the host client, then perform one controlled power cycle of the SPARE and reconnect with unchanged key. Record whether the key survives and the same security session can be re-established.
6. Stop the candidate owner and release serial. Return the spare to the old application GBL and retained plaintext host, keeping candidate key backup. Verify old CPC communication. Do not infer from old plaintext success that the encrypted key was preserved.
7. Reflash the candidate application once more and attempt encrypted connection using the SAME retained key without rebinding. This tests whether the intervening old firmware left the candidate binding usable. If the key no longer works, stop and report that failure; do not clear storage or run unbind. Keep the spare isolated for diagnosis.
8. Stop all test clients. Retain artifacts/key privately and state which firmware remains on the spare. A successful run may leave candidate firmware with its matching key; do not introduce an extra downgrade solely for tidiness.

## Applicable command forms (not executed)

Resolve SPARE_UART to the verified test device only, CANDIDATE_GBL and OLD_GBL to the hashed local copies. Each flash requires a stopped serial owner. These are command forms for the bounded approved experiment, not a blind unattended script.

    universal-silabs-flasher --device "$SPARE_UART" --bootloader-reset rts_dtr --probe-methods bootloader:115200,cpc:115200 probe
    universal-silabs-flasher --device "$SPARE_UART" --bootloader-reset rts_dtr flash --firmware "$CANDIDATE_GBL" --allow-cross-flashing
    universal-silabs-flasher --device "$SPARE_UART" --bootloader-reset rts_dtr flash --firmware "$OLD_GBL" --allow-cross-flashing --allow-downgrades

Allow one initial attempt per stage. On failure stop the experiment; the separately described old-firmware recovery attempt is permitted only within the approved spare recovery scope. Further retries need a diagnosed cause and reassessment. If firmware metadata/policy prevents an operation, inspect the actual failure and stop; no automatic --force. Bootloader-reset is a spare-only interruption here.

Inside an isolated container using the selected immutable host image, map only the spare to /dev/ttySPARE and the corresponding private directory to /data. Override the entrypoint to CPCd so the HA app's normal service graph does not start. Use separate baseline/candidate configs, with UART115200, flow control false, cpcd_0 instance, tracing disabled, and /dev/ttySPARE. Baseline uses disable_encryption:true; candidate uses false and binding_key_file:/data/cpc/binding.key. The candidate /data/cpc directory is0700 and key0600.

Vendor command forms verified by final-image --help:

    # Candidate version check BEFORE binding: use the flasher CPC probe, not CPCd.
    universal-silabs-flasher --device "$SPARE_UART" --probe-methods cpc:115200 probe
    /usr/local/bin/cpcd --conf /data/cpcd.conf --bind ecdh --key /data/cpc/binding.key
    # Candidate normal start AFTER successful binding and protected key copy:
    /usr/local/bin/cpc-key-preflight /data/cpc/binding.key && /usr/local/bin/cpcd --conf /data/cpcd.conf

Binding intentionally provisions a new transport credential only at stage4. Normal starts must use the existing candidate key preflight before CPCd; no implicit key creation is acceptable. Execute one owner at a time, stop it gracefully and confirm it has exited before flashing or switching images.

## Success, abort and recovery

Success for this experiment: bootloader1.12 accepts/launches the exact candidate; encrypted CPC establishes and survives host restart/spare power cycle; old firmware communicates with its matched host; returning to the candidate reuses the original binding without rebind. Record any identity changes and version discrepancies. This does NOT prove live network traffic, production token migration, counter-safe production rollback, or manufacturing calibration equivalence.

Abort on wrong device mapping, unwanted existing network/binding, unexpected bootloader policy, failed image validation, failure to release serial, key mismatch/loss, a failed startup attempt or unexpected erase request. Never update bootloader/SE, mass erase, unlock debug, unbind or copy production secrets to continue.

Recovery on upload/launch failure: retain the bootloader; release all clients; use documented RTS/DTR or physical boot/reset entry on the SPARE, then attempt the retained old application GBL. If bootloader is unreachable or rejects that artifact, stop with spare unusable pending separately reviewed physical recovery. Do not perform an experimental debug unlock.

Worst case: the spare becomes unusable or remains bound without a usable host key, requiring additional recovery work or replacement. No production network outage/re-pairing should result because production radio, credentials and services are excluded. USB targeting is therefore a hard check. No power-loss injection is included.

## Subsequent production gate

Use the measured results to decide whether a production trial is proportionate. Preserve untouched matched host stores before first candidate start; assess token semantics and counter-safe return using supported procedures. A successful spare test does not waive these requirements. If old firmware/key round-trip fails, investigate that observed failure instead of commissioning production. If the spare is unavailable, the alternative is a narrowly scoped request for SONOFF's baseline storage/startup/bootloader configuration; no external message is authorized or sent.

The nine existing contributions remain unchanged. No new migration infrastructure or competing PR is proposed.
## Independent review and scope audit
The independent reviewer read this proposal, FUNCTIONAL-STATE.md and REUSE-FINDINGS.md. Accepted the defined spare experiment with explicit limitations; requested pre-binding version-probe correction, one-attempt rule and correct image transport identity checks. Those corrections are incorporated. The reviewer did not rerun underlying source checks or commands. Goal outcome is a defined experiment with a concrete hardware/authorization dependency, not execution or proof of production preservation. Baseline artifacts, host/radio state, separate flash/start/bind/downgrade stages, commands, backup requirements, abort/recovery/worst-case and independent challenge are covered here and in the linked evidence. No new competing implementation or public contribution was created.
