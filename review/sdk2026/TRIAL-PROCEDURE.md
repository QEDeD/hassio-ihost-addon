# SDK2026 single-dongle trial — operational draft

Preparation only, 2026-09-19. This is not an approval request yet. Use EXECUTION.md for artifact status and current authority. The operator resumed preparation; production actions below are proposed, not authorized. No spare is available.

## Intended result and limits

Keep the existing Zigbee and Thread/Matter networks operating on channel25 through the same app slug and endpoints, using SDK2026.6.1 radio firmware and encrypted CPC. Technical acceptance requires preserved identities and fresh representative traffic after a controlled app restart. It does not establish improved long-term reliability. Avoid a deliberate successful-candidate downgrade solely to test reversibility: that adds another storage transition on the only radio.

## Concrete execution route

- App: `local_codex_ihost_otbr_focused`, source configuration `/local_apps/codex_ihost_otbr_focused/config.json`, existing private `/data` retained by same-slug Supervisor updates. Never uninstall/reinstall or seed from the September14 archive.
- Serial: `/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f21ff7708be7ed11890d646262c613ac-if00-port0`,115200/no flow. Only one serial owner; stop Zigbee2MQTT and Multiprotocol before any flasher or provisioning process.
- Current consumer: `45df7312_zigbee2mqtt`; Matter server `core_matter_server`. Preserve current options and `tcp://local-codex-ihost-otbr-focused:9999`; no endpoint or network-credential migration.
- Candidate radio GBL: `firmware/package/output/rcp-sdk2026-application-only.gbl`, SHA256 b5deda18cba9f07f03f5faeb5d6969e51110bf0bd8450dd00bb3cf14047a9d50.
- Old radio GBL: `recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl`, SHA25640fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Vendor model/version match, not proven identical installed bytes or hardware-tested rollback.
- Recovery-only radio GBL: `firmware/cpc-recovery/package/cpc-recovery-sdk2026-application-only.gbl`, SHA25622c4d75097b5cda0e8d60634cc1753d9615069398055b81b8c5a219e64f49897. Used only for the explicitly approved interrupted-binding branch.
- Host images: candidate0.3.1-sdk2026 ID sha256:f34bcbad0113df786aba81619b8ccf2b580bb1ac56ed8f3b3c23acc99c5c0844; recovery0.3.2-sdk2026-recovery-unbind ID sha256:048dda7c6872f102376dbd2a83aeaa8d93baa1300b42f4ba667cbd82f05cec27. Retained old host0.2.3-ordered is in recovery/REUSE-FINDINGS.md. Record registry/platform identities after authorized delivery.
- Flasher: universal-silabs-flasher1.1.0, the already demonstrated RTS/DTR reset method and `bootloader:115200,cpc:115200` probes. The offline package/firmware bundle is preserved at C:/Users/Kristoffer/Git/otbr/sdk2026-flasher-bundle-20260919, with hashes in evidence/flasher-bundle-20260919.json. In the official SSH10.5.0 image with networking disabled and no radio attached, installation, pip consistency, CLI help and all three GBL parses passed; removing the temporary APK group restored the exact original package inventory. Now staged and checked on the actual SSH app: /tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher and /share/codex-sdk2026-stage-20260919/bundle/firmware/{candidate,recovery,rollback}.gbl. Evidence: evidence/live-staging-20260919.json. Revalidate presence/hashes before downtime, especially after an SSH app restart/update. Do not upgrade existing SSH packages; the rehearsed installer adds only absent packages. Never use a firmware URL during the outage.

Pinned candidate flash command, staged but NOT authorized to execute:

```sh
/tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher \
  --device /dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f21ff7708be7ed11890d646262c613ac-if00-port0 \
  --bootloader-reset rts_dtr --probe-methods bootloader:115200,cpc:115200 \
  flash --firmware /share/codex-sdk2026-stage-20260919/bundle/firmware/candidate.gbl
```

Inspection of the pinned1.1.0 wheel confirms the global parser is shared by the top-level and flash parsers, so the command above accepts options before flash. The additional mocked parser check now passes with the installed pinned wheel for both argument placements; no hardware action was invoked (evidence/flasher-cli-parse-results.log). The pinned1.1.0 CLI validates the GBL then uploads and runs it; it has no flash cross-upgrade/downgrade override flags. Do not copy flags from older tool versions or add `write-ieee`/`--force`. Physical bootloader acceptance remains untested. [Pinned implementation](https://raw.githubusercontent.com/NabuCasa/universal-silabs-flasher/v1.1.0/universal_silabs_flasher/flash.py).

## Preparation remaining before approval

1. Recovery-only host and explicit archival are built;23 recovery tests and32 normal-wrapper tests pass. Integrate independent review and final manifests. Normal trial startup must never invoke recovery or new binding automatically.
2. Choose and prepare image delivery to HA. Existing GHCR/Supervisor route is proven historically; publication authority must be reconciled separately. A local Windows image alone is not deployable HA state. Do not widen SSH privileges merely for Docker access. Stage actual execution-host availability before downtime.
3. Confirm current running image identity if available without additional access changes; otherwise explicitly retain the distinction between observed live version and the exact previously tested rollback image. Do not manufacture digest certainty from an app version.
4. Prepare private backup capture using existing Supervisor backup and SSH-copy operations. A historical124MiB archive was copied and hash-verified at `/home/wsluser/.local/share/ha-recovery/sdk2026-20260919/historical-feec49c2.tar` with0700 directory/0600 file. This demonstrates the independent copy path only. Fresh capture is required below; secrets remain outside Git/log output.
5. Record baseline powered-device evidence, network identities and full Thread store selection privately; pin a small representative acceptance set from devices that are currently responsive. Do not classify powered-off devices as regressions. Coordinate the maintenance window with the other HA task before executing.

## Proposed maintenance sequence

1. Confirm exact approved artifact hashes, serial target, working recovery tools, image availability and operator attendance. Save the complete existing app source configuration, runtime options and boot/watchdog/update settings privately. Set affected radio app boot to manual, watchdog/updates off for the window.
2. Start downtime clock when the first relevant writer is stopped. Stop Z2M, the radio app, Matter and Core long enough to take a coherent initial backup of the three apps plus the HA configuration folder (including actual zigbee2mqtt data); exclude history with explicit `--homeassistant-exclude-database=true`. Use Supervisor CLI over SSH while Core is stopped. Confirm stopped state, backup success, required members and independently copied checksum before flashing. Restart Core and Matter after the backup; keep radio owner/Z2M stopped. Restore unchanged operation and abort if capture cannot finish within the preparation allowance.
3. Install the reviewed candidate host while the app is stopped, retaining complete `/data` and all runtime options. Change only the explicitly needed provisioning mode. Verify the new version and stopped state, preserved options and target before starting anything. Supervisor updates preserve the stopped/running entry state; only different versions are accepted. Existing2026.09.0 rehearsal is reusable because selected current2026.09.2 update/backup/options functions are unchanged: evidence/supervisor-update-source-20260919.json. [Manager source](https://raw.githubusercontent.com/home-assistant/supervisor/2026.09.2/supervisor/apps/manager.py), [app source](https://raw.githubusercontent.com/home-assistant/supervisor/2026.09.2/supervisor/apps/app.py).
4. Upload the approved candidate application once. No bootloader/SE update, mass erase, identity write or automatic retry. Allow an in-progress upload to finish or fail normally; do not remove power because a planning timer elapsed. Require application CPC response before binding.
5. Select `bind-ecdh` and start the one-shot app once. It records intent before CPCd, has a120-second process bound and exits without starting networks. Require confirmed success, valid durable host key and stopped app. Take a new stopped focused-app backup including the complete CPC directory and markers; verify and preserve its independent protected copy before normal startup. A failure is ambiguous even if the host key is missing; follow only the approved recovery branch.
6. Select `run`, preserve established network options, and start the normal candidate. Verify encrypted CPC and expected identity/store selection immediately, then start Z2M. Treat this as the first network-active point and retain the latest whole stores for any recovery. No transport-only mode is claimed. First normal start is network-active even if readiness fails; recovery must use latest stores.
7. Verify existing network IDs/channel25, fresh reports from a currently powered Zigbee device and a Thread/Matter device, and one non-actuating request/response on each stack where supported. Check intended HA discovery/API access and absence of repeated service failures. Do not toggle plugs or lighting groups. Use the existing ALPSTUGA Identify button (15seconds) and fresh measurements for the Matter command check. Observe for ten minutes, then perform one controlled app restart and require the same saved CPC key, identities and fresh traffic again. After restart, perform the specified one-step brightness change/restoration on already-on Computer-loftlampe01 with explicit LevelControl readback; repeat ALPSTUGA Identify. Exact commands, baseline evidence and restoration/skip conditions are in recovery/ACCEPTANCE-20260919.md. These visible command checks are included in the proposed trial approval, not authorized by preparation alone.
8. Capture post-trial state, restore intended boot policy and remove temporary maintenance-only material after acceptance. Remove the named .codex-sdk2026-flasher APK group and exact /tmp/codex-sdk2026-flasher venv; compare the package inventory to the staged packages-before.txt. Keep the independent protected backups and recovery bundle. Do not remove unrelated SSH packages/files. Retain exact recovery artifacts and protected keys. Reassess nine contributions from the observed upgrade result. No broad HA reboot or deliberate dongle power cycle is necessary to claim only app-restart persistence; power-loss persistence remains untested unless separately included.

## Explicit image and mode transitions

Before each stopped image update, select `prepare` through the current schema and verify complete options. It is accepted by all three image schemas. Do not start prepare against existing state: it is only the shared mode for update validation, not an import request. Boot remains manual and watchdog off.

| Transition | Before update | After verified stopped update |
| --- | --- | --- |
| Baseline0.2.3 → candidate0.3.1 | prepare | Approved firmware upload, bind-ecdh once, key backup, then run |
| Candidate0.3.1 → recovery0.3.2 | prepare | Approved recovery firmware, then recover-unbind once |
| Recovery image stays installed | stopped, confirmed unbind | Explicit archive-binding once; preserve entire CPC directory |
| Recovery0.3.2 → candidate0.3.1 | prepare | Approved candidate firmware return, bind-ecdh once, backup, then run |
| Candidate/recovery → baseline0.2.3 | prepare and compatible saved options | Latest-state capture first, approved old firmware return, then run |

Supervisor's manager rejects equal versions, not lower version ordering; the selected local-store version controls the same-slug update. Never uninstall/reinstall. Recovery output deliberately records only unbound-confirmed, not whether a key was deleted or already absent; both vendor successes satisfy that checkpoint.

## Failure boundaries and proposed time budget

Reserve60minutes of attended radio interruption, with a decision to accept or begin recovery by T+35. This is an operational target, not a guarantee: failed bootloader/storage recovery can exceed the window. Initial stopped backup has a10-minute abort allowance before flash. No new build/download or broad investigation during downtime.

- Failure before radio changes: restore the saved same-app configuration/options and original running state; no state restore should be necessary.
- Failed candidate startup after traffic: stop writers and capture the latest full focused-app state and key before switching back. Restore the old application and retained old host once against latest stores; never rewind counters with the pre-trial backup. Confirm identities and fresh Zigbee/Thread/Matter behavior. Old firmware initialization after new PSA storage is a residual risk, not an established recovery result.
- Interrupted/missing-key bind: optional R1 requires its own explicit approval and time allocation. Flash the separate recovery application; install stopped recovery-only host; explicitly run one unbind, require confirmation; explicitly archive original CPC directory intact; return to candidate application and host; explicitly bind once and back up the matching key before networks start. No deletion/retry/rearm occurs on normal startup. Preserve failed key evidence.
- Permit at most one terminal old-host/old-firmware fallback, including after an early R1 failure only if fallback begins by T+35. Never return to the candidate after that fallback. R1 is for ambiguous/interrupted CPC binding only, not arbitrary storage or radio failure. Host backups cannot restore radio NVM.

| Elapsed interruption | Required result / action |
| --- | --- |
| T+10 | Coherent initial backup independently verified; otherwise restore unchanged operation before flashing. |
| T+20 | Normal candidate has binding, protected key copy and healthy initial traffic; alternatively enter the specifically approved R1 branch by this deadline. |
| T+30 | Normal path finishes ten-minute observation and begins its controlled app restart. |
| T+35 | Normal path passes restart checks or begins terminal old fallback. R1 must have completed its firmware/host transitions, explicit unbind/archive, candidate binding and protected key copy; otherwise use terminal fallback now if still feasible. |
| T+40 | Successful R1 has healthy existing-network traffic. |
| T+50–55 | Successful R1 completes observation and controlled restart. |
| T+60 | Target closeout, not guaranteed recovery. |

The old fallback allowance is20minutes plus5minutes margin, requiring a start byT+35. A failure during late R1 observation/restart cannot fit that allowance inside the same60minutes. Stop the affected services, preserve current state and obtain a concrete extension/recovery decision; do not conceal another firmware cycle inside the original budget. Never interrupt an in-progress flash because a timer expires. Bootloader inaccessibility, failed storage or old-radio initialization after candidate PSA changes may exceed the target or require network repair. The final approval must explicitly cover this residual risk; earlier acceptance of estimated downtime does not do so.

## Approval status

Still preparation. Remote image delivery/identities remain before requesting production approval. Representative controls are now concretely specified: one-step brightness change/restoration on Computer-loftlampe01 and ALPSTUGA Identify, with no plug switching. Post-reboot baseline and live flasher staging have passed; the direct Zigbee LevelControl read has passed against the unchanged live baseline (currentLevel26 at20:17:07CEST). Bounded R1 timing and the completed independent review are incorporated. A successful build is not deployment readiness. The meaningful operator decision will be acceptance of the concrete single-dongle trial and its residual recovery risk, not mechanics we can resolve ourselves.
