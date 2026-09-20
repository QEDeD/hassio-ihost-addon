# Proposed CPC diagnostic window — September 20, 2026

Status: independently reviewed and ready for operator review. Planning only; no production authorization exercised by this document. The earlier trial approval is consumed.

## Purpose and success

Determine whether the SDK2026 candidate fails before producing serial data, returns unusable CPC frames, or fails a specific version query. If necessary, determine whether the existing CPC-only application answers on the same hardware. End on the original working firmware/app with the existing networks intact. A useful diagnostic result plus verified restoration is success for this window; it is not completion of the SDK upgrade.

Do not bind, unbind, start the candidate host, send network commands while diagnostic firmware runs, update the bootloader/SE, change clocks/channels, erase storage or improvise retries. Do not install either candidate/recovery host image: baseline app0.2.3-ordered stays installed and stopped until old firmware is restored. No registry access or host image update is needed for this route.

## Why this sequence

- Full candidate first: detailed capture is the new experiment; its original INFO-only failure was inconclusive. Reusing its exact artifact avoids changing firmware and observability simultaneously.
- Conditional CPC-only second: reuse an already built, inspected vendor sample rather than create a speculative fix. Skip this step when candidate output already gives an actionable protocol/parser failure or when time/recovery conditions are unfavorable.
- Restore old firmware even if either probe succeeds. CPC version success does not qualify binding or network operation, and no upgrade acceptance is included.
- No additional cold-power/reset matrix, baud sweep, tuning changes or firmware variants in this window. Their relevance depends on these observations.

## Exact artifacts and tools

Paths are relative to review/sdk2026. Rehashed September20 during planning; staged HA copies still require verification immediately before the approved window.

| Role | File | SHA256 |
| --- | --- | --- |
| Full candidate | firmware/package/output/rcp-sdk2026-application-only.gbl | b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50 |
| Conditional CPC-only | firmware/cpc-recovery/package/cpc-recovery-sdk2026-application-only.gbl | 22c4d75097b5cda0e8d60634cc1753d9615069398055b81b8c5a219e64f49897 |
| Terminal working firmware | recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl | 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787 |

Use retained universal-silabs-flasher1.1.0 and its already tested offline package bundle: C:/Users/Kristoffer/Git/otbr/sdk2026-flasher-bundle-20260919. Restage the removed temporary runtime using the previous package inventory/install method, without upgrading installed SSH packages. Run CLI help and pip consistency offline; no unchanged rebuild/full test suite required. Hash-check the staged executable dependencies and GBLs against the retained manifest. Serial device remains /dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f21ff7708be7ed11890d646262c613ac-if00-port0,115200,no flow. Verify it has not changed; do not select a different USB device by guessed tty number.

App slugs: radio local_codex_ihost_otbr_focused; Zigbee2MQTT45df7312_zigbee2mqtt; Mattercore_matter_server. Core/SSH remain on their current installed versions. Verify current identities and options before mutation; a changed baseline requires reassessment.

## Logging and observation contract

Source audit completed against the exact retained universal-silabs-flasher1.1.0 and serialx1.10.0 wheels. The essential observations are timestamped TX/RX, frame parsing, first versus second version query, terminal exception/exit, bootloader upload result and RUN command. Preserve whether reset lines were deliberately manipulated. Do not infer application health from the flasher's two-second menu timeout.

Use private logs with umask077, directories0700/files0600 under a new date/run-specific directory on HA and an independent WSL copy. Mark UTC and CEST timezone offsets. Do not overwrite September20 trial records. Before deletion of temporary HA tools, verify copied log checksums. Retain raw logs privately; commit only sanitized findings. A stopped old radio may have buffered application data, so even pre-binding raw serial output is not assumed public. No binding/session keys or dataset dump is requested.

DEBUG is limited to standalone flasher operations with sole serial ownership. The normal host's logging remains unchanged. No live terminal stream of frame data; capture stdout/stderr to files and inspect selected status/counters privately. Bound each standalone probe to30seconds; a timeout kills only the probe, never an active upload. Allow16MiB per flash log and1MiB per probe log, with at least128MiB free for diagnostics in addition to the required backup/staging space; check size between commands. If unexpectedly exceeded, stop further diagnostics and restore. Never truncate a running flash log or kill a flash to satisfy a size/time target. Use -vv for flash (DEBUG with progress bar suppressed) and -v for probes. Keep global DEBUG including serialx: filtering only the flasher logger would discard raw short RX chunks. Firmware packet bytes are logged twice; estimated packet representations are about0.96MB for candidate and1.48MB for rollback before overhead/retries. No output truncation pipeline or hard process cap is permitted during flash.

### Exact logging behavior and limits

CPC probe sends only unnumbered system PROP_VALUE_GET for CPC/app versions, with no binding, SET or protocol RESET. Each property already has up to four transmissions with one-second timeout and0.1second gaps. Source: flasher wheel cpc.py:233–300,342–394; absent reset targets return immediately in flasher.py:476–483. Do not add an external retry loop.

Serialx descriptor_transport.py:125–140 logs every raw read before CPC parsing, including a one-byte/partial response. Capture the whole logger stream. However, serial_posix.py:321–324 applies default HIGH RTS/DTR and flushes buffers on open; close defaults LOW with HUPCL (common.py:441–444; serial_posix.py:225–236). “Without deliberate reset” does not mean electrically passive. No Received chunks means no bytes observed after this connection initializes; it does not prove the radio never transmitted. Use the same tool/open pattern for old, candidate and optional CPC-only comparisons. Record this limitation even when the result appears decisive.

Host DEBUG adds formatting and disk I/O, which can alter timing. Limit it to these short commands, verify baseline responsiveness with the same logger, and do not claim to have ruled out a timing-dependent failure. Firmware log level and normal app logs remain unchanged. The upload packet payload is the prebuilt firmware, but incidental serial data remains private.

### Command templates, to run only inside the approved sequence

Resolve these paths once and record them privately. A new RUNLOG directory must be created with umask077; never reuse prior logs. Verify the shell's timeout command supports the shown syntax during tool staging, without opening the radio. Capture each command's exit immediately and record UTC begin/end externally. These are command templates, not a script to run the whole sequence blindly.

```sh
FLASHER=/tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher
DEVICE=/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f21ff7708be7ed11890d646262c613ac-if00-port0
FWROOT=/share/codex-sdk2026-stage-20260919/bundle/firmware
# RUNLOG is a newly created private directory specific to this approved run.

# A: one baseline version probe, then inspect its result before proceeding.
timeout 30s "$FLASHER" -v --device "$DEVICE" \
  --probe-methods cpc:115200 probe >"$RUNLOG/baseline-probe.log" 2>&1

# B: no outer timeout and no output truncation during firmware upload.
"$FLASHER" -vv --device "$DEVICE" --bootloader-reset rts_dtr \
  --probe-methods bootloader:115200,cpc:115200 \
  flash --firmware "$FWROOT/candidate.gbl" >"$RUNLOG/candidate-flash.log" 2>&1
# Run only after upload exits successfully:
timeout 30s "$FLASHER" -v --device "$DEVICE" \
  --probe-methods cpc:115200 probe >"$RUNLOG/candidate-probe.log" 2>&1
```

For conditional stage C use the same flash template with recovery.gbl/recovery-flash.log and recovery-probe.log. For terminal stage D use rollback.gbl/rollback-flash.log and rollback-probe.log. File roles remain as pinned above; do not substitute an image based on a similar filename. Record hash, stage and operation with each command so pre-upload identification cannot be mistaken for post-upload success. If the outer probe timeout fires, verify the probe process has exited and released the serial port before any next owner starts.

## Preparation before downtime

1. Resolve normal HA access through the documented ha-unlock workflow. Confirm operator attendance and no competing maintenance. Existing confirmation applies only to its earlier window; refresh for the actual new scheduled window. No spare assumed.
2. Verify actual current firmware/app identities, serial target, healthy baseline Zigbee and ALPSTUGA reports, saved channel25/network identities and available storage. Preserve complete app options, descriptor, restart/watchdog/update policies privately. No unrelated inventory refresh.
3. Stage and check the tool bundle, all three exact GBLs and logging destinations before stopping services. Ensure existing SSH access survives radio interruption. Reuse the proven cleanup inventory method.
4. Pin representative checks: the existing computer-ceiling bulb must answer a non-actuating genLevelCtrl/currentLevel read; ALPSTUGA must report fresh measurements. Resolve unavailable/powered-off acceptance devices before starting, without switching plug loads.

## One bounded service window

Downtime starts when the first writer stops. Target20–30minutes, reserve45minutes total, and start terminal recovery byT+20 at the latest. These are operational targets, not a guaranteed repair time. Previous pre-binding fallback succeeded; the CPC-only image has not run on this dongle and adds hardware uncertainty.

### A. Protect state and establish the diagnostic control — by T+10

- Save original policies, set radio/Z2M manual boot and watchdog/auto-update off, then stop Z2M and radio. Prevent any competing serial owner. Do not disable unrelated automations globally.
- Stop Matter/Core long enough for coherent capture. Create the supported stopped three-app Supervisor backup plus a separate direct stopped HA config archive covering actual Z2M data and HA .storage, excluding history. Do not request Supervisor Core backup preparation while Core is stopped.
- Independently copy both archives to private WSL storage and verify hashes and required coverage. Record source/copy identities. If incomplete byT+8, abort before flashing and restore original services/policies.
- Restart Core/Matter, keep radio/Z2M stopped. Obtain a CPC-only DEBUG probe of the old firmware. It must return the expected4.6.0 and provide interpretable diagnostics. If it fails, do not flash: preserve evidence and restart the old app/services. A baseline failure invalidates this comparison.

### B. Full candidate — aim to decide by T+14

- Flash the exact candidate once using the previously demonstrated RTS/DTR method. Capture detailed upload/run logs. The flasher's normal internal transport retransmissions are not extra flash cycles; do not manually retry a failed upload.
- Once the command exits successfully, record its exit time, allow a fixed25second settling interval (close to the first trial's post-upload interval), then run one CPC-only DEBUG probe at115200, without an explicit bootloader-reset sequence. Record probe connection/query times; serial open/close still changes RTS/DTR and may affect this board's reset state. Tool-native bounded request retries are allowed. Capture exit and elapsed time.
- If upload fails, output is unexpectedly large, serial ownership is unclear, or time reserve is insufficient: skip all additional diagnostics and enter terminal recovery.
- If both version queries complete, record actual response versions and restore old firmware. Do not bind or call this an accepted upgrade; the earlier failure may be intermittent or reset-dependent.
- If captured output identifies an actionable protocol/parser/query failure, preserve that evidence and restore. Investigate the narrow path offline.
- Only if there is no useful response/diagnostic boundary and the baseline logging control passed, consider stage C. A small static log inspection is permitted; no source research or rebuild during downtime.

### C. Optional CPC-only split — start only by T+15, finish by T+18

- Flash the exact existing CPC-only recovery firmware once, use the same25second post-command settling interval, and run the same bounded CPC-only DEBUG version probe. Never run the recovery host or send unbind. The retained cpc_app_init() is empty; linked evidence confirms no automatic boot-time key deletion.
- This firmware still initializes NVM/PSA and can write storage. Its unauthenticated explicit unbind endpoint exists; keep all normal clients stopped and leave it deployed only for this probe. Do not describe it as a read-only image.
- Both outcomes lead directly to old firmware restoration. No return to the candidate within this window and no extra variant/test cycle.

### D. Terminal recovery and acceptance — begin by T+20

- Preserve latest stopped radio host stores before old firmware restoration, using the existing focused backup/copy method; never replace them with an old snapshot. Budget at most two minutes for this redundant capture and skip/stop it if it would delay starting the old-firmware upload byT+20. If it fails, retain the verified initial copies and current live stores, record the failure and proceed with the approved firmware-only restoration. The relevant facts are that no candidate/recovery host ran and baseline radio/Z2M remained stopped; Core/Matter did resume and may have updated their own host state. No older archive is restored or live data deleted. “Begin recovery byT+20” means begin the old-firmware upload, not begin an unbounded backup.
- Upload the exact official working4.6.0 firmware once. After the same25second settling interval, require CPC4.6.0 reply before starting the baseline radio app. Baseline host image/options were never replaced; do not update or reinstall it.
- Start the original radio then Z2M. Check identities/channel25 and no new network creation; verify an explicit Zigbee currentLevel read, fresh ALPSTUGA measurements, and one ALPSTUGA Identify15seconds command completion. No light brightness/on-off or plug power changes.
- Observe fresh reports and no repeated service errors for five minutes. Restore original policies, verify actual running services, copy final logs/status independently, remove only the temporary flasher runtime/APK group and verify the original package inventory. Retain recovery copies and staged GBLs.
- If terminal flash/probe or restored service checks fail, stop further mutations, preserve evidence, keep network/radio clients stopped where necessary, and report exact state. No second fallback flash, unbind, mass erase, bootloader/SE update or automatic spare assumption. Additional recovery needs a concrete operator decision; acceptance of45minutes does not authorize unlimited recovery risk. Never interrupt an active flash at a deadline.

## Interpretation and next action

| Observation | What it supports | Next offline work |
| --- | --- | --- |
| Old control fails | Comparison/control path unhealthy today | Diagnose baseline access/serial ownership without candidate flashing. |
| Candidate sends bytes but parsing fails | Receive path is active; framing/baud/protocol remains suspect | Inspect bytes and exact parser; distinguish malformed frame from reset/bootloader output. |
| Candidate CPC version answers; application version does not | Initialization reached useful CPC processing | Inspect that property handler/response/probe behavior; do not treat as total boot failure. |
| Candidate fully answers | This boot reached CPC processing | Compare reset/timing against first trial; qualify only version exchange. Prepare separately approved binding/upgrade trial. |
| Candidate fails; CPC-only answers | SDK common CPC path can work in this image | Focus on differences including HFXO activation, protocol crypto, RAIL/OpenThread, layout and initialization. |
| Both new images have no observed RX after open/flush, old restores | Common startup or candidate-specific transport remains unresolved | Choose retrievable startup/reset/fault instrumentation before another build/window. |
| Any image produces a fault/reset indication | Direct fault evidence | Decode against exact ELF/source before changing firmware. |

The CPC-only image omits RAIL, which changes HFXO AUTO from enabled to disabled despite identical clock headers. Its success cannot prove the external crystal works or uniquely blame Thread. Its generic MCU app type/layout also differs. No uncontrolled setting sweep follows from a success or failure.

## Closeout and authority to request

Record exact artifacts, command exits, chronological timing, decision branches, log hashes, concise sanitized interpretations and restored baseline evidence in one run report. Update EXECUTION.md. Keep the existing goal active in intent; a diagnostic result is not the upgrade. Reassess upstream changes only if the new evidence affects them.

HA/host backups cannot restore the dongle's NVM. The previous fallback succeeded after the full candidate before binding; fallback after this CPC-only image has not been demonstrated. Its similar storage configuration and absent auto-unbind support the plan but do not remove that additional storage-transition risk on the only radio. This specific uncertainty must be accepted if optional stage C is included. An operator may approve stages A/B/D alone; in that case inconclusive candidate logs lead directly to restoration, with stage C deferred.

The later approval request must explicitly cover: brief Core/Matter stop for backup; radio/Z2M outage; one candidate upload, at most one conditional CPC-only upload, and one terminal working upload; private DEBUG captures; non-actuating Zigbee read and ALPSTUGA Identify; the45minute target and unresolved recovery risk without a spare. Approval does not cover binding, key deletion, bootloader/SE changes or a full candidate deployment. Independent review and source-level command/logging audit are complete; refresh actual baseline/access/staged files immediately before the approved window. No production operation has run during planning.

## Independent review incorporated

Fresh-context GPT-6 Astra/high reviewer review_diagnostic_window supported the sequence without requiring extra variants or tests. Five material corrections were accepted: serial-open/reset caveat and timestamp boundaries; CPC-only-specific NVM recovery uncertainty; accurate host-store preservation rationale despite Core/Matter restart; redundant capture included inside the recovery deadline; and actionable malformed output also skips the optional image. Logging audit by candidate_boot_failure established raw RX logging in serialx, exact verbosity/probe behavior, packet log volume and bounded internal retries. The parent integrated both reports; no unresolved review finding requires another review cycle.
