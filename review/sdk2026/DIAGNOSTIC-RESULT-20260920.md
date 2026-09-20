# CPC diagnostic trial — September 20, 2026

Status: completed at09:10:52UTC. Original firmware/app restored and verified; temporary tooling removed. The approved single diagnostic sequence is consumed. The SDK upgrade itself remains incomplete.

## Diagnostic result

| Image/probe | Result | Raw RX chunks / parsed CPC frames |
| --- | --- | --- |
| Working SONOFF4.6.0, before flashing | Version exchange passed | 2 / 2 |
| Exact full SDK2026 candidate | Failed first version query; no bytes observed in probe connection | 0 / 0 |
| Exact CPC-only SDK2026 application | Version exchange passed, CPC4.9.1 | 2 / 2 |
| Official SONOFF4.6.0 restored | Version exchange passed | 2 / 2 |

DEBUG observability was useful: the full candidate transmitted probe requests with four unsuccessful request attempts and received no bytes after the probe opened/flushed the serial connection. There was no malformed frame or parser exception to explain that timeout. This does not establish that the dongle never transmitted before the connection opened, nor does it establish which initialization stage failed. Serial RTS/DTR effects and logging overhead remain qualifications.

The existing CPC-only image can boot far enough for SDK2026 CPC4.9.1 system communication on this dongle and resident bootloader. This reduces suspicion of a universal SDK/bootloader/CPC-probe incompatibility and focuses investigation on differences in the full image: external-crystal activation, additional protocol crypto and RAIL/OpenThread initialization, component selection and binary layout. It does not uniquely identify the clock or Thread code. No encrypted binding/session or full candidate network behavior was tested.

The three uploads were completed once each in the approved order: full candidate, conditional CPC-only, official working firmware. Each bootloader upload reported completion; the flasher commanded RUN. No extra retry cycle, unbind, binding, erase, bootloader/SE update, app image update, clock/channel change or plug/light switching occurred. Candidate/recovery host images were never started or installed during this diagnostic window.

## Preservation and recovery

Fresh stopped-writer three-app and direct HA configuration archives were independently copied and hash/coverage checked before flashing. The direct archive remains a configuration archive, not a Supervisor-restorable Core backup. Latest stopped radio host token/Thread files before fallback were byte-identical to the initial copies; recovery reused the live stores. No stale archive was restored.

Original app0.2.3-ordered and Z2M2.14.1-1 restarted about7minutes54seconds after the first writer stop. The restored Zigbee attribute read returned currentLevel1; ALPSTUGA Identify completed. Saved Zigbee identity/PAN/extended PAN/channel/network key and HA Thread dataset data match; channel25 retained.

During startup the old radio logged mDNS interface errors and Thread fragment/reassembly drops. Matter subscriptions recovered gradually: one plug was initially unavailable, then reconnected at approximately09:07:38UTC. ALPSTUGA renewed its subscription and subsequently supplied changed temperature, humidity and CO2 values. At09:08:10UTC and final closeout there were no newly unavailable entities compared with baseline. At09:10:44UTC ALPSTUGA supplied further changed humidity/CO2 measurements. The final check covered326seconds after radio/Z2M service restoration, with no observed repeated service restart. Startup logs also contain an old-system CLI broken-pipe warning and a ping failure for the previously troublesome/offline dining-room bulb; these were not evidence of a new candidate runtime fault. These observations must not be described as an entirely error-free restart.

Original app options, source descriptor and boot/watchdog/update policies were verified restored. All113 original SSH package versions were restored exactly; temporary flasher runtime and APK group removed. Independent protected DEBUG copies passed checksums. About13minutes21seconds elapsed from first stop through observation and cleanup, within the45minute allowance. Radio/Z2M were started after about7minutes54seconds; one Matter plug needed additional reconnection time as recorded above.

This adds physical fallback evidence after initialization of the particular CPC-only image without an unbind command. It does not establish fallback after new binding credentials, candidate network activity or every persistent-storage state. Host backups still cannot restore dongle NVM.

## Next investigation

The next useful firmware investigation is the additional startup path in the full candidate. Separate external-crystal initialization from the subsequent radio/protocol initialization with an observable, narrowly changed diagnostic if source analysis does not identify a defect. Reuse the now working CPC-only image as a hardware control; do not repeat a broad baseline or infer that disabling encryption/erasing storage/upgrading the bootloader is the fix.

Further production flashes are outside this consumed diagnostic sequence. The original SDK upgrade remains incomplete; these results alone do not change the nine upstream contribution dispositions or qualify their candidate runtime behavior.

## Evidence

- Structured sanitized evidence: evidence/diagnostic-result-20260920.json, including UTC operation events, private log checksums and backup references.
- Protected raw logs/backups: /home/wsluser/.local/share/ha-recovery/sdk2026-diagnostic-20260920.
- HA private log directory: /share/codex-sdk2026-diagnostic-20260920.
- Exact firmware identities and reviewed scope: DIAGNOSTIC-PLAN-20260920.md.
- Logs use HA's CEST clock; operation events use workstation UTC. Small clock differences exist; infer exact ordering within each source and use recorded operation events for approximate elapsed outage.
