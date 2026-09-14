Current closeout (2026-09-14): see review/sdk2026/recovery/FINAL-ASSESSMENT.md and BACKUP-20260914.md. A new current host backup closes the earlier missing backup coverage; production radio recovery and candidate hardware acceptance remain unverified.

# Installation proposal — recovery gate remains open

Updated2026-09-14. This document supersedes earlier requests for model identification or a bootloader probe. The operator confirmed SONOFF ZBDongle-E; the authorized probe observed Gecko Bootloader1.12.00 / SONOFF1.0.1 and CPC4.6.0, then restored normal operation.

## Current decision

Do not flash production yet. The application-only candidate and a vendor rollback candidate are prepared, but restoration of relevant radio state and a matched current host recovery set are not established. No installation, binding or publication is authorized by this proposal.

See [recovery decision](recovery/DECISION.md), [host state and backup evidence](recovery/HOST-STATE.md), [rollback artifact](recovery/rollback/README.md), and [candidate package](firmware/package/README.md).

## Prepared artifacts

- SDK2026.6.1 encrypted host image: sha256:7f6104879bfe004823b03c3db5ba67d90ea1366d854372bba1732baa1e250f6b.
- Clean firmware ELF: SHA256165a4a603d42eedd346b8e5e881662d41b9689eaecc762848d86535dfe064f74.
- Application-only GBL3: SHA256b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50; reproducible packaging, vendor parsing and independent payload comparison passed. No bootloader or Secure Engine upgrade, compression or firmware-package encryption. CPC link encryption is enabled independently.
- Official SONOFF4.6.0/115200 rollback candidate: SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Strong model/version/baud match; not proven identical to installed bytes or tested rollback.

Offline API, host packaging and failure-path checks are recorded in STATUS.md and linked evidence. They do not establish physical radio compatibility or recovery.

## Facts required before a concrete cutover

1. Actual bootloader acceptance/policy and application erase behavior. Current vendor-tool parsing is not hardware acceptance.
2. Baseline radio storage/startup layout and a supported preservation/restoration method; compare before and after encrypted binding. The candidate stores a persistent radio binding key. A VM snapshot cannot restore it.
3. A matched current host recovery set and immutable installed image identity. The latest inspected Supervisor app backup omits Z2M's real /config/zigbee2mqtt directory and excludes HA/Matter; the operator's separate Proxmox backup has not been assessed here.
4. Protected backups for host Zigbee tokens, Thread datasets, Z2M data, Matter fabric state and any CPC key. Do not print or commit their contents.

## Conditional future sequence

After these facts are established and the operator approves the exact interruption: coordinate with the HA peer; verify protected recovery artifacts and baseline health; stop Z2M then the current Multiprotocol owner; update only the application through the verified method; bind only if explicitly authorized and confirmed unbound; protect the resulting host key; start the matched CPC/zigbeed/OTBR services and then Z2M; verify encrypted CPC and fresh Zigbee/Thread/Matter behavior and persistence.

Preserve the existing Z2M endpoint tcp://local-codex-ihost-otbr-focused:9999 or explicitly include its change. Only one radio owner may run. Stop on failed image acceptance, binding mismatch, missing state or loss of network behavior. Do not automatically erase, unbind, regenerate keys, downgrade or fall back to plaintext. Recovery must use the previously verified matched firmware/host/state procedure.

Exact destructive commands are deliberately not presented as ready to execute while their preservation and recovery prerequisites remain unresolved. The next action is the focused offline investigation in recovery/DECISION.md; a spare equivalent radio is the practical alternative if source/storage evidence cannot establish a credible production recovery route. Successful spare operation alone would not prove preservation of the production dongle's existing state.