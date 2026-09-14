# SDK 2026.6.1 offline candidate

Offline preparation is verified to the scope below. This is not installation or flashing approval. The next gate is physical hardware identification and a matched recovery decision.

Separate branch: codex/sdk2026-integration, based on fa7819333ffdb97c71279bd01b099c4020f2bebf. The existing followup-integration worktree remains clean at that same base; the prepared nine contributions are unchanged. No publication or production mutation.

## Candidate identities and reproduction

- App image: sha256:7f6104879bfe004823b03c3db5ba67d90ea1366d854372bba1732baa1e250f6b
- Firmware: firmware/candidate-clean/, ELF SHA256 165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74. Provisional ZBDongle-E/EFR32MG21 target; OFFLINE ONLY, NOT FOR FLASHING.
- App: CPC_ENCRYPTION=ON bash review/sdk2026/build-host-sdk2026.sh. Dockerfile.sdk2026 records pinned builder/runtime image digests, SDK2026.6.1, CPCd4.9.1 commit and required patches. recipe/PACKAGE-INPUTS.md records fixed signed Debian snapshots and actual package-install verification.
- Firmware: choose a new FIRMWARE_OUTPUT directory, then bash review/sdk2026/firmware/build-clean.sh. This starts from the pinned pristine builder with explicit package/trust setup; compilation runs without network. See firmware/README.md. This establishes repeatable reconstruction, not bit-identical output.

## Requirement-by-requirement evidence

| Requirement | Current evidence and limit |
| --- | --- |
| Recorded obtainable inputs | Both clean builds passed. Fixed signed package sources, SDK/base image digests and CPC commit recorded; full-image-permanent-failure-fixed.log and firmware/clean-build.log. |
| Required HA API behavior | Live read-only HA Core2026.9.2 confirmed. api-tests/results.json: actual SDK REST server with exact python-otbr-api2.10.0 passed8 grouped sequences, including reset/immediate ID read, JSON/TLV active/pending operations. No legacy dataset DELETE patch needed for those sequences. HDLC simulator excludes CPC/multipan. |
| Service discovery choice | Native OpenThread mDNS removes external daemon/library. All three SDK native mDNS, discovery-proxy and SRP advertising tests passed; evidence/*unit.log. Physical cross-interface discovery remains a live test. |
| CPC security choice | Encrypted candidate, explicit trusted-link binding, persistent private key and no automatic replacement/plaintext fallback. firmware/README.md verifies generated ECDH and linked encrypted endpoint/default-denied unbind. No hardware handshake claim. |
| Assembled artifact checks | evidence/final-7f610-verification.log: all5 application linkages,14 synthetic key tests, complete s6 graph, served root/local QR bytes and9 JS files without legacy external QR request. Reusable verify-image.sh. |
| Failure lifecycle | lifecycle-tests/final-permanent-failure-fixed/results.json: actual final image, no finish override, missing/malformed key each refuses once and exits1 without key changes/disclosure or CPC startup. Genuine s6 fixture; Supervisor and healthy radio startup/shutdown remain untested. Normal/signal finish branches preserved. |
| Independent review | Fresh reviewer challenged recipe, firmware reproduction, security operations and installation proposal. Clean firmware recipe closes retained-container gap. Reviewer independently validated lifecycle fixture, documented finish125 semantics and applied fatal-exit branch. No outstanding offline finding from that review. |
| Next live action and recovery | INSTALLATION-PROPOSAL.md records actual app/consumer topology, explicit gates, key/network-state preservation, binding and matched rollback requirements. Physical identity/bootloader/NVM preservation still need verification before flashing. |

## Useful corrections found

- Clear inherited APT::Snapshot selector when explicit fixed snapshot URLs are used; otherwise update fetched newer indices but install searched old snapshot metadata. Signature requirements unchanged.
- Guard CPC shared-memory cleanup and return documented s6 finish125 after fatal halt. Without it, preflight failures repeatedly restarted while readiness waited; final tests establish the correction.
- Use native mDNS and retain only patches that apply to the new SDK. Avoid a speculative dataset-deletion patch.
- Reconstruct firmware from a pristine builder instead of relying on retained container packages/trust state.

## Live boundary

Read-only inventory confirms local_codex_ihost_otbr_focused0.2.3-ordered is running, stock iHost app stopped; serial115200/no flow control/Thread enabled. Zigbee2MQTT uses its TCP9999 bridge. USB metadata does not identify board revision/MCU/bootloader. Production was not changed.

Before any flash, establish exact hardware and supported update/storage preservation, protect matching host/radio state, identify a recoverable known-good pair and approve the specific maintenance procedure. A VM snapshot cannot restore radio NVM/firmware. No automatic recovery experiments on the only production dongle.

Final image verification from PowerShell:

```powershell
$check = Get-Content -Raw review/sdk2026/verify-image.sh
docker run --rm --network none --entrypoint /bin/bash IMAGE_ID -c $check
./review/sdk2026/lifecycle-tests/run-lifecycle.ps1 -Image IMAGE_ID
```

Use the immutable image ID above. Passing the script via -c avoids PowerShell adding a trailing CRLF to stdin. Lifecycle tests retain stopped synthetic containers for inspection. No attached radio or host networking is used.

## Hardware identification update
Operator confirmed ZBDongle-E. Authorized coordinated probe identified Sonoff v1.0.1 / Gecko Bootloader1.12.00 and returned to existing CPC4.6.0; both apps restored and fresh Thread/Matter reports verified. See bootloader-probe/README.md and probe.log. This supersedes the earlier request for a label/bootloader probe; no further photo is needed. Exact rollback firmware and SDK storage/GBL compatibility remain to be established before any flashing approval.
