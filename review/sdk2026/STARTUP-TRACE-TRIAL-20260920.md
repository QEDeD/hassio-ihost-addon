# Proposed full-image startup trace window — 2026-09-20

**Prepared, not approved or executed.** The user's current instruction authorizes preparation and Git push. Earlier hardware allowances are consumed. This document is the exact new procedure to approve.

## Outcome and scope

Capture the full SDK2026 image's startup checkpoints on the existing flasher connection, then restore official SONOFF4.6.0 and original app0.2.3-ordered regardless of diagnostic outcome. This is a localization test, not an upgrade deployment.

Approval covers coherent backups with brief Core/Matter interruption, stopping radio/Z2M, exactly one diagnostic upload and one mandatory old-firmware upload, private DEBUG capture and the same non-actuating Zigbee read plus ALPSTUGA Identify15seconds used in the completed trial. No binding/unbind, candidate host installation/start, network commands on diagnostic firmware, channel/clock tuning, erase, bootloader/SE update, extra image or retry cycle. No spare assumed. Prior successful restoration reduces uncertainty but does not guarantee recovery; host backups cannot recreate lost dongle NVM.

Target15–25minutes, reserve45minutes. Start terminal rollback by T+15 after first writer stop. Never interrupt an active upload to meet a deadline. If the established rollback fails, stop and obtain a separate recovery decision rather than extending scope.

## Exact artifacts and established mechanics

Paths are relative to review/sdk2026:

| Role | File | SHA256 |
| --- | --- | --- |
| Startup diagnostic | firmware/startup-trace/package/startup-trace-sdk2026-application-only.gbl | e5eba832d7eecac5870f0db2d47ce9725e5c1d6c7ad4f15c1783c4e9fb59dbe6 |
| Mandatory rollback | recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl | 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787 |

Use the actual USB by-id, app identifiers, flasher1.1.0/serialx1.10.0 offline bundle, backup coverage, independent-copy checks, ordinary flash/probe command flags and package cleanup from CRYPTO-TRIAL-PLAN-20260920.md and DIAGNOSTIC-PLAN-20260920.md. Those are technical references; their consumed image sequences/authority do not apply. Latest successful recovery evidence is CRYPTO-TRIAL-RESULT-20260920.md.

New capture wrapper: firmware/startup-trace/capture-launch.py. It requires exact reviewed flasher module hash0bf3416d42ec8bd658cdf892e5b83ee2eccac3cfd69836b82a8b70b9a872b9ee. Replace only the CLI entry point of the established diagnostic flash command with the same venv Python plus this wrapper, retaining all device, reset, DEBUG, flash and firmware arguments. It extends every RUN wait in that invocation to30seconds; there is no active-upload timeout. Ordinary control/probe/rollback use the unmodified flasher entry point. There is only one serial owner at a time.

Raw DEBUG may contain firmware bytes and arbitrary RX; store only in fresh protected HA/WSL run directories. Stage/hash-check the GBL, wrapper, parser, rollback and tool inputs under unique names with a separate manifest. Do not overwrite earlier manifests. Sanitized parser output contains fixed markers only and does not replace private raw evidence.

## Sequence

1. **Before stopping anything:** confirm operator availability, no conflicting maintenance, current baseline health/versions/configuration, exact serial identity/ownership, storage, independent recovery access and available Zigbee/Matter acceptance devices. Reuse still-valid authorization but refresh time-sensitive facts. Restage the removed offline flasher tools without upgrading existing packages. Verify capture wrapper version/hash guards using --help and record exact tool/package inventory and original policies.
2. **Protect current state by T+8:** apply the previously demonstrated manual-boot/watchdog protections; stop radio and Z2M. Briefly stop Core/Matter for the supported three-app backup plus stopped HA configuration archive covering real Z2M/HA storage, excluding history. Independently copy and verify hashes/coverage before flashing. If incomplete by T+8, abort before flash and restore original services/policies. Restart Core/Matter; keep radio/Z2M stopped.
3. **Old-firmware control:** one ordinary private DEBUG CPC version probe,30second outer timeout, requiring both4.6.0 replies. Failure aborts candidate testing without flashing. The control uses the established serial-open behavior and is not a test of marker capture.
4. **Diagnostic once, begin by T+10:** run the existing upload command with the capture wrapper and exact startup diagnostic. Capture the whole upload and30second post-RUN receive interval on that connection. Record exit, timings and bytes privately. Do not run a parallel reader or reset the device to recover missing markers. After successful command exit, run one ordinary bounded CPC version probe, expecting4.9.1; the completed30second capture replaces the earlier25second settling wait. Skip this probe if upload failed, ownership is uncertain or recovery time is insufficient. Preserve logs; do not analyze at length while services are down.
5. **Mandatory old-firmware upload by T+15:** use the unmodified flasher to restore official4.6.0 once. Preserve latest stopped host stores only if it cannot delay restoration; do not restore stale host data. After the established25second settling time, require the ordinary4.6.0 probe, then start original radio/Z2M with their unchanged original image/options. No candidate host or binding operation has run.
6. **Closeout:** confirm saved network identities, channel25 and HA Thread dataset; one non-actuating Zigbee level read, fresh changing ALPSTUGA reports and one15second Identify with device result after subscription recovery. Compare availability with baseline; permit one non-actuating read of a newly unavailable device as in the completed trial. Observe five minutes for recovery and repeated new failures. Restore original policies; remove temporary flasher/APK group and verify every original package version. Independently retain logs/backups and update result/EXECUTION before declaring restoration complete.

If rollback upload/probe or production checks fail, preserve evidence, report exact state and stop additional mutation. No second fallback/reset experiment/erase is included. Physical intervention or replacement might be needed if established software recovery fails.

## Interpretation after restoration

Expected marker order is00,09,0A,01–08,0B–26,FF. Use the generated map. Inspect only RX after final RUN; parser rejects missing RUN, ignores TX and combines split chunks. Check raw launch/reset/timestamp evidence privately.

A missing after-marker narrows an interval including the vendor call and trace/capture machinery; it is not a proven defective function. No00 remains inconclusive. FF plus valid CPC replies demonstrates instrumented startup/communication only, not the unchanged firmware, encryption or network operation. Repeated sequences may indicate reset. Early raw output could have been lost in previous standalone probes, so report new evidence without retrospectively claiming those probes captured launch.

The diagnostic's own guard can deliberately stop startup, and its RAM fault code is unavailable through UART. If evidence remains ambiguous, do offline analysis and reconsider hardware debug access before requesting another outage. Do not automatically add variants or speculative fixes.

Preparation review and validation are recorded in STARTUP-TRACE-REVIEW-20260920.md. Approval must apply to this procedure and its recovery limits; accepting the expected duration does not accept unlimited recovery risk.
