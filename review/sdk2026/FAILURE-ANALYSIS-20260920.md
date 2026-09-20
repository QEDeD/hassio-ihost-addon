# SDK2026 initial CPC failure — integrated analysis, September 20

## Conclusion

The candidate upload completed and the flasher commanded application launch, but no successful CPC version exchange was observed. This happened before encrypted binding and before the candidate host application started. The strongest remaining investigation targets are candidate initialization and its UART/CPC response path. No specific firmware root cause or corrective patch is established.

The old firmware and host were restored and representative Zigbee and Matter checks passed. This investigation made no subsequent production changes. The consumed trial approval does not authorize another flash cycle.

## What the logs actually establish

Times here are UTC; the private flasher logs use CEST, two hours ahead.

| Event | Evidence | Interpretation |
| --- | --- | --- |
| 08:08:57 CPC 4.6.0 detection | candidate-flash.log | This is the old application, detected before candidate upload. It is not a candidate success. |
| 08:08:48–08:09:25 candidate flash command, exit 0 | events.jsonl and candidate-flash.log | Pinned flasher requires bootloader upload status `complete`, then sends RUN. It does not independently read back flash or verify CPC afterward. |
| 08:09:50 CPC-only probe, failure | candidate-cpc-probe.log | No successful version exchange at 115200; not proof of electrically silent TX. |
| 08:10:40 bootloader/CPC probe without reset, failure | candidate-boot-check.log | Neither tested protocol answered successfully in this pass. |
| 08:11:23 launch during fallback preparation, CPC probe fails again | rollback-flash.log | Failure persisted through another bootloader-to-application launch attempt before the old firmware was uploaded. |
| 08:11:31 Gecko 1.12.0 detected | rollback-flash.log | RTS/DTR still reached the installed bootloader. |
| After old firmware upload, CPC 4.6.0 responds | rollback-cpc-probe.log | The same serial path and probe can communicate with the working image. |
| 08:13:35 onward restored operation | TRIAL-RESULT-20260920.md and sanitized result JSON | Existing networks recovered without re-pairing; specific pre-binding fallback demonstrated. |

The source audit uses the retained universal-silabs-flasher 1.1.0 wheel in the protected offline tool bundle. `flash.py:332–335` explicitly passes `run_firmware=True`. `flasher.py:445–450` uploads then runs. `gecko_bootloader.py:266–277` requires upload status `complete`; `156–171` sends RUN and interprets absence of a bootloader menu for two seconds as launch success. An application crash or stall can pass that latter check. The INFO message “Launched application from bootloader” is therefore not application-health evidence.

The missing GBL metadata message appears for both candidate and working rollback. It describes an absent optional metadata tag, not an observed rejected firmware upload. There is no upload-rejection exception in the successful command results.

Private source logs: `/home/wsluser/.local/share/ha-recovery/sdk2026-20260920/`. Keep raw backups, complete options and credentials outside Git. The sanitized [trial result](TRIAL-RESULT-20260920.md) records preservation, timestamps and recovery hashes.

## Causes investigated

| Candidate explanation | Evidence and conclusion |
| --- | --- |
| Candidate host, binding wrapper, DNS or HA network changes | These paths had not run. They cannot explain this initial probe failure, although they remain unqualified on hardware. |
| Encryption refuses an unbound version query | SDK `cpc/src/sl_cpc_system_secondary.c:1451–1463` explicitly permits unencrypted system U-frame queries for CPC and application versions. Their response formats at 484–524 match the probe's three little-endian uint32 values and NUL-terminated app version. This specific explanation is unsupported; complete protocol interoperability is not proven. |
| PSA initialized too late | `sl_cpc_security.c:191` calls `psa_crypto_init()` internally before key/storage use. Generated service ordering alone does not establish this defect. An actual initialization failure remains possible. |
| Wrong USART, pins, flow control or simple clock divisor | Linked instructions use USART0, PB1 TX/PB0 RX, no CTS and 115200. PCLK is 40 MHz and the linked divisor uses PCLK, giving nominal 115274 baud, +0.064%. No simple 38.4/80 MHz calculation mix-up. |
| Corrupt vector or obvious incompatible application properties | Candidate reset vector resolves to its reset handlers; origin, initial SP and properties format match working firmware. Application type differs, but no rejection rule or observed rejection was established. |
| Installed bootloader necessarily too old | Both images call resident bootloader initialization and contain old-bootloader security mitigation. No applicable minimum version or matching vendor defect was found. This does not establish universal compatibility. A bootloader update is not a justified fix. |
| External crystal or other startup hang | Possible. Both images use 38.4 MHz HFXO and similar waits/settings. Fallback CTUNE differs: working 140, candidate 128; both prefer stored calibration. Effective calibration and last completed startup stage are unknown. |
| CPC RX/frame handling or response scheduling | Possible. Current INFO logs omit bytes, parser errors and which version request timed out. The bare-metal firmware must reach its service loop to process CPC; RAIL/OpenThread and crypto initialization occur before that loop. |
| General physical serial failure | Less consistent with working old probes, successful upload and immediate working rollback. Candidate-specific UART behavior remains possible. |

Detailed instruction addresses, clock calculations and qualified vendor research are in [BOOT-COMPARISON-20260920.md](BOOT-COMPARISON-20260920.md) and [VENDOR-STARTUP-FINDINGS-20260920.md](VENDOR-STARTUP-FINDINGS-20260920.md). Neither review identified a proven correction. The existing vendor fixes for HFXO/SE initialization are included in this SDK; their release-note presence alone does not explain our failure.

## Best next route

Prepare a short diagnostic procedure instead of another full acceptance trial. Its purpose is to distinguish causes before attempting binding or network startup.

1. Reuse the pinned flasher's `-v` DEBUG mode for **CPC-only system-version probes**, first against the baseline as a positive control within an approved maintenance window. Keep the log private. It records sent/received bytes, parse failures, sequence matching and retries; `cpc.py:233–291` queries CPC version then application version. This can distinguish no received bytes, invalid framing, and a failure at the second query. Do not run concurrent radio owners or extend frame tracing into binding or normal traffic.
2. If a candidate repeat is approved, capture the upload/run exchange and that same detailed probe from the first attempt. Repeating unchanged firmware would be justified only by this new diagnostic capture, not as a hopeful retry. Stop short of binding even if it answers unless the new procedure explicitly includes further steps.
3. If logs still cannot locate the failure, consider the already-built CPC-only recovery image as one conditional split-test, using only the ordinary version query. **Do not run its recovery host, unbind, bind, or normal networks.** It has no automatic boot-time unbind, but initialization can write persistent storage and its explicit local unbind endpoint exists. It is a temporary diagnostic image, not a harmless read-only firmware.
4. If even that split cannot provide an actionable boundary, select an accessible startup/fault diagnostic mechanism before building an instrumented image. Reuse vendor hooks. No arbitrary printf text on the live CPC stream; no new debug image without an agreed way to retrieve its evidence.
5. Fix only the failure supported by that evidence, then return to the original encrypted-CPC and preserved-network acceptance criteria. Keep the known-good rollback and latest-state recovery discipline.

This is the selected investigation route, not an executable production approval package. Before another hardware operation, freeze the exact image sequence, sole-owner/service-stop scope, logging, stop conditions, coherent backup/independent copy, terminal fallback and combined outage allowance; obtain the independent review required by the goal and approval of that concrete procedure. No additional operator facts are needed to finish this offline preparation. No spare is assumed.

### Important limitation of the existing CPC-only image

Its Clock Manager tree and oscillator headers are byte-identical to the candidate:

- Tree header SHA256 `05ce9ee7912c3549f2fdeee01a2871171c22e65c9980fec437c8569b59c3b548`.
- Oscillator header SHA256 `3c98ff81ad1a679d57969b2eafdecf4378084db6bb6e5f9967247db52c5cb9c9`.

But `SL_CLOCK_MANAGER_HFXO_EN_AUTO` resolves through `SL_CATALOG_RAIL_LIB_PRESENT`: enabled in the full candidate, disabled in the CPC-only recovery build. Therefore a successful recovery-image probe would narrow the problem to differences including **external-crystal initialization as well as RAIL/OpenThread**, plus changed layout/components. It would not prove HFXO works or uniquely blame the Thread stack. A failed recovery-image probe would keep common initialization/transport causes in play. Both outcomes are narrower evidence than “SDK2026 works/does not work.”

## Procedure improvements already justified

- **Backup sequencing:** stopped Core cannot service Supervisor's Core backup preparation API. The trial resolved this before flashing using the supported stopped three-app backup plus a direct stopped configuration archive and independently verified copies. Use that explicit method when stopped-writer coherence is required. The direct archive is not a Supervisor-restorable Core backup; retain restoration instructions and do not mislabel it.
- **Update selection:** store `version` is installed version; verify `version_latest` after changing/reloading the local descriptor, then verify installed version/stopped state after update.
- **Failure observability:** use private detailed logs for the bounded pre-binding version probe. The original INFO gate correctly stopped the trial but did not preserve enough evidence to diagnose why it failed.
- **Recovery scope:** successful old-firmware fallback before binding does not demonstrate fallback after new binding keys or network activity. Preserve that boundary in every readiness claim.

No firmware, bootloader, SE, tuning, encryption or network configuration was changed by this analysis. The nine contribution dispositions remain unchanged: this failure predates their candidate runtime behavior and supplies no basis for discarding or qualifying them.
