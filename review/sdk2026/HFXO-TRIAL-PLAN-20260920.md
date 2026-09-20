# Proposed crystal-startup diagnostic window — September20

Status: prepared offline; not approved or executed. Previous diagnostic approval is consumed. This proposal adds exactly one new firmware test and a mandatory return to the working system.

## Purpose and authorized scope to request

Determine whether explicitly initializing the external high-frequency crystal prevents the otherwise working CPC-only SDK2026 firmware from replying. End on official SONOFF4.6.0/app0.2.3-ordered with the original networks working. No binding, unbinding, candidate host install/start, network commands on diagnostic firmware, tuning/SYSCLK/channel changes, storage erasure, bootloader/SE update or additional variants.

The user would approve brief Core/Matter interruption for coherent backup; radio/Z2M interruption; one diagnostic upload and one terminal old-firmware upload; private DEBUG capture; a non-actuating Zigbee level read and ALPSTUGA Identify15seconds; the timing/recovery limits below. No spare is assumed. A physically unrecoverable failure remains possible; previous fallback success is evidence, not a guarantee.

## Exact artifacts

Paths relative to review/sdk2026:

| Role | File | SHA256 |
| --- | --- | --- |
| Crystal diagnostic | firmware/cpc-hfxo-diagnostic/package/cpc-hfxo-sdk2026-application-only.gbl | fcd9addc9323d92f23013056e93689e43213709f896c99a733348398d3283cb8 |
| Mandatory old firmware | recovery/rollback/donglee_mg21_multipan_beta_4.6.0_115200.gbl | 40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787 |

Diagnostic ELF fa14fd55f8e16ef6729572eb4d1dbc63c0b17762b6da640bf34352cbb4f3f913. It changes only HFXO_EN relative to the working CPC-only recipe. CTUNE128/stored calibration selection, UART115200/no flow, security/storage, SYSCLK/PCLK, generated startup and compiler configuration are retained. It still initializes NVM/PSA and has an explicit unbind endpoint, which must not be used. Packaging excludes bootloader/SE and NVM programming pages; runtime storage writes remain possible.

## Reused mechanics, with explicit changes

Reuse DIAGNOSTIC-PLAN-20260920.md sections “Logging and observation contract”, “Exact logging behavior and limits”, “Command templates” and the demonstrated backup/cleanup mechanics. Those sections specify flasher1.1.0/serialx1.10.0, actual USB serial by-id, private DEBUG, probe30second timeout, no active-upload timeout, single serial owner, archive coverage and package inventory restoration. They are technical references; their old multi-image sequence/authorization does not apply here.

Use a new run-specific private directory on HA and independent WSL storage. Stage the new GBL under an unambiguous hfxo-diagnostic.gbl name and hash-verify it immediately before use. Do not overwrite the earlier candidate.gbl or recovery.gbl, or silently modify their manifest. Write a separate manifest for the new diagnostic plus unchanged rollback/tool inputs. Use the prior flash command with this exact new file and hfxo-flash.log/hfxo-probe.log. There is no full-candidate or ordinary CPC-only flash in this procedure.

Same serial target: /dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_f21ff7708be7ed11890d646262c613ac-if00-port0. Radio app local_codex_ihost_otbr_focused; Z2M45df7312_zigbee2mqtt; Mattercore_matter_server. Baseline options/policies/descriptor and actual versions must still match before proceeding. Verify attendance and no conflicting maintenance for this window, normal SSH access and independent recovery access.

## Ordered sequence and timing

Target15–25minutes; reserve45minutes for the whole window. Begin the terminal old-firmware upload byT+15. These are operational bounds for deciding actions, not guaranteed recovery times. Downtime starts at the first writer stop. Never interrupt an active upload to meet a deadline.

1. **Before downtime:** verify artifact/tool hashes, storage, current baseline and serial ownership; prepare private logs/independent backup destination; restage the removed temporary flasher runtime with the previous offline bundle, without upgrading existing packages. Record original package inventory and app policies. Pin the same available acceptance bulb and ALPSTUGA; do not actuate plug loads. If the baseline changed materially, reassess before stopping services.
2. **Protect state, byT+8:** set radio/Z2M manual boot and watchdog/updates off; stop them. Stop Core/Matter for coherent capture. Make the supported three-app Supervisor backup and direct stopped HA config archive covering real Z2M/HA storage, excluding history. Copy independently and verify hashes/coverage. If not complete byT+8, abort before any flash and restore original services/policies. Restart Core/Matter; radio/Z2M remain stopped.
3. **Baseline probe:** one standalone private DEBUG CPC version probe,30second outer timeout, expected4.6.0. Require interpretable TX/RX and both replies. If it fails, do not flash; restore baseline services and diagnose separately. Same serial-open behavior as the earlier test, including RTS/DTR and buffer flushing.
4. **Diagnostic upload/probe:** start only if control passed and byT+10, leaving at least five minutes before recovery must start. Upload the exact new GBL once with RTS/DTR bootloader entry and DEBUG. After successful command exit, wait25seconds and issue one identical bounded version probe. Record both returned version properties, RX byte/chunk/frame counts and exit/timing. Expected CPC4.9.1. Do not retry externally or vary reset/baud. If upload fails, time/log reserve is insufficient, or ownership is uncertain, skip the probe and go directly to terminal recovery. An active upload must finish before changing ownership.
5. **Mandatory restoration, start upload byT+15:** whether probe succeeds or fails, restore official4.6.0 once. Before upload, copy latest stopped radio host stores using the prior bounded method only if it cannot delay restoration; otherwise retain the verified initial copy and unchanged live stores. No candidate host has run; do not restore stale host data. After upload exit and25second settling, require one CPC4.6.0 version probe. Then start original radio app and Z2M with unchanged original image/options.
6. **Verify and close:** confirm network identities/channel25, successful non-actuating currentLevel read, fresh ALPSTUGA measurements and one15second Identify completion. Compare availability against pretest baseline; previously powered-off devices are not new failures. Observe for five minutes, including recovery of subscriptions and absence of repeated new service failures. Restore original policies, independently copy logs, remove temporary flasher/APK group and verify original package versions. Update the result and EXECUTION.md. A successful diagnostic alone is not enough to close without recovery verification.

If old upload/probe or restored service checks fail, stop further mutations, preserve evidence and report exact state. Keep serial/network clients stopped where needed. No second fallback, reset experiment, unbind, erase or bootloader/SE operation is included. Obtain an explicit additional recovery decision rather than extending risk silently. Operator might need physical access if the established software recovery path fails; no safe physical recovery can be guaranteed.

## Decisions from the result

- Both new version queries succeed: the HFXO-enabled CPC-only startup reaches CPC communication under this boot sequence. This reduces the priority of a general failure caused by enabling HFXO, but does not exonerate every crystal path: vendor initialization can skip reinitialization when inherited SYSCLK already uses HFXO. Investigate later full-image startup differences first, retaining inherited-clock/timing interactions as alternatives. No tuning, binding or full-image acceptance follows automatically.
- No raw RX after open/flush: the added initialization or its interaction becomes the primary suspect. Investigate exact waits and actual calibration/board configuration before changing tuning. It does not prove no bytes were ever transmitted.
- Partial/malformed RX, one reply only, reset/fault output: inspect those bytes privately against the exact ELF/tool, which may give a narrower cause than either broad branch.
- Baseline or recovery failure: suspend candidate investigation and address the concrete production state under a separately approved recovery route.

The earlier CPC-only→old transition passed with no binding. This decreases uncertainty for shared storage initialization, but enabling HFXO changes execution and the new transition is untested. No host backup can restore lost dongle NVM. This residual risk and the45minute target must remain explicit in approval.

Linked-code caveat: the vendor initializer skips crystal reinitialization when inherited SYSCLK is already HFXO; the full candidate has the same guard. A version reply proves that the configured startup path returns under this boot sequence, not that every crystal wait executed. Record this limitation and retain the same upload/open sequence; a further test is worthwhile only if it resolves the remaining mechanism.

Independent fresh-context GPT-6 Astra/high review completed; see HFXO-INDEPENDENT-REVIEW-20260920.md. Its interpretation correction is incorporated. No substantive unresolved procedure finding remains. This does not authorize execution.
