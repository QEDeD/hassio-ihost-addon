# Crystal-startup diagnostic result — September20,2026

Completed at09:54:39UTC. The approved diagnostic passed, and the original production firmware/app was restored and verified. This test allowance is consumed. The SDK2026 upgrade itself remains incomplete.

## Result and interpretation

| Probe | Result | Observed raw RX chunks / parsed CPC frames |
| --- | --- | --- |
| Original SONOFF4.6.0 before test | Both version queries passed | 2 / 2 |
| CPC-only SDK2026 with HFXO_EN=1 | Both queries passed; CPC4.9.1 | 2 / 2 |
| Restored official SONOFF4.6.0 | Both queries passed | 2 / 2 |

One diagnostic upload and one mandatory original-firmware upload completed successfully. No additional firmware variant, binding, unbind, candidate host, bootloader/SE update, storage erase, clock tuning or network change was performed. The diagnostic GBL was fcd9addc9323d92f23013056e93689e43213709f896c99a733348398d3283cb8; the old GBL was40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Exact source/build comparison is in firmware/cpc-hfxo-diagnostic/.

This establishes that the HFXO-enabled CPC-only configuration reaches communication under the tested upload/boot/probe sequence. The vendor initializer can skip crystal reinitialization if inherited SYSCLK already uses HFXO; the result does not prove every crystal wait executed. Later protocol-crypto/RADIOAES and RAIL/OpenThread startup differences in the silent full candidate are now the next priorities, with inherited-clock/timing/layout interactions retained as alternatives. There is still no proven defect or corrective firmware patch.

## Recovery and acceptance

- Fresh coherent three-app and direct HA configuration archives were independently copied and hash/coverage verified before flashing. Latest stopped radio host stores remained byte-identical to the initial copies. No stale state was restored.
- Original radio/Z2M services restarted after about5m25s. Saved Zigbee identity/key/channel25 and HA Thread dataset data match. Original app versions/options/policies/descriptor were verified.
- Representative Zigbee currentLevel read returned1. ALPSTUGA resubscribed and supplied changed temperature/humidity/CO2 through09:54:18UTC. Identify completed after resubscription.
- Several Zigbee entities initially returned unavailable. All recovered within observation. The last lamp, stue_loft_sofa_rispapir, answered a non-actuating genBasic.zclVersion read with8 at approximately09:52:36UTC and returned online; no power/brightness change was made. This was an additional read to verify a newly unavailable device, not a firmware retry.
- Final observation covered308seconds after radio/Z2M restart, with no newly unavailable entities. All original services remained started. Temporary flasher/runtime removed and all113 original SSH package versions restored exactly.
- Actual first writer stop09:44:07UTC; closeout09:54:39UTC, about10m33s total. These timings exclude preparation while normal services were running.

The restored old stack logged startup ping failures, Thread fragment/reassembly drops and a CLI broken-pipe warning. Reassembly drops also occurred later during observation; this was not an error-free log. Similar warnings were observed after the earlier restored baseline; current checks establish representative operation and availability recovery, not their cause or absence of all transport loss.

Two execution corrections are retained: an initial wrong Supervisor policy path returned403 before any service stopped, so its premature downtime marker is excluded from outage duration; the corrected /options request succeeded. An early Identify service request returned an empty list before Matter integration resubscription, so it was not claimed as completed; the later confirmed request is the acceptance evidence.

## Next investigation

Audit whether the vendor protocol-crypto mask initialization can be isolated on this now proven HFXO-enabled CPC baseline without importing broader RAIL/Thread startup. Existing linked evidence identifies a RADIOAES busy wait and subsequent PSA/SE random generation; PSA initialization already precedes them, so no ordering fix is justified. If dependency coupling prevents a clean split, compare the cost/information value of bounded startup checkpoints in the full candidate instead of accumulating service windows. No new production flash is authorized by this result.

Worker candidate_boot_failure supplied this bounded read-only next-step assessment; the parent verified production results and owns the interpretation. The nine upstream contributions have no changed disposition from this diagnostic alone.

Evidence: evidence/hfxo-result-20260920.json. Private raw logs/backups and operation events: /home/wsluser/.local/share/ha-recovery/sdk2026-hfxo-20260920; HA copies under /share/codex-sdk2026-hfxo-20260920. Raw DEBUG and network credentials remain outside Git. Clocks differ slightly; use event timestamps for approximate duration and each source's own ordering for detailed log analysis.
