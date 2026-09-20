# Protocol-crypto startup diagnostic — September20,2026

Completed10:44:00UTC. The diagnostic passed, original production firmware/app was restored, and representative operation was verified. This physical-test allowance is consumed; the SDK upgrade remains incomplete.

## Observation

The original4.6.0 control, crypto diagnostic4.9.1 and restored4.6.0 each returned both version queries with two raw RX chunks/two parsed CPC frames. No diagnostic/recovery parse errors. One diagnostic upload and one mandatory restoration completed; no binding, unbind, candidate host, channel/clock change, bootloader/SE update or erase.

Crypto GBL SHA256 a7684fe05c9d31fccb311ba9f895769087a040f6525d2163c8c6311ebffe91ee. Original GBL40fd84de70686326e76b4836c765255f7b50a26a22c1c17ca40af770eadea787. Exact recipe, component differences and limitations: firmware/cpc-crypto-diagnostic/README.md and CRYPTO-COMPONENT-REVIEW-20260920.md.

This proves the added protocol-crypto initialization returns in the isolated configuration under the tested boot/probe sequence. It does not establish encrypted CPC binding, radio operation, full-image startup or a root cause. The successful CPC-only, HFXO+CPC and crypto+HFXO+CPC tests make another routine component-only outage less useful than observing where the full image actually stops. Optimization, layout, MPU and inherited-clock interactions remain alternatives; do not simply declare RAIL/Thread defective.

## Recovery and acceptance

First writer stop10:32:53UTC; independent coherent backups verified10:33:57. Crypto upload10:34:52–10:35:12; probe10:35:40–41. Stopped radio host stores unchanged. Original upload10:36:08–10:36:57; probe10:37:23–24. Original radio/Z2M restarted10:37:57/10:38:09 and original policies restored. Services returned after about5m16s. Saved Zigbee identities/key/channel25 and HA Thread dataset match. No older state was restored.

Zigbee currentLevel read returned1. ALPSTUGA Identify15seconds received explicit Matter Success(0); sensor reports resumed. Most initial availability recovered automatically. The remaining sofa lamp answered genBasic.zclVersion with8 at10:40:28 approximately. Private diagnostic logs independently copied/hash-verified; temporary tools removed10:39:45 with all113 original package versions restored.

Final observation covered349seconds after policies were restored. No newly unavailable entities remained; all original app versions/options/policies were verified. ALPSTUGA measurements continued changing through10:43:49UTC. Total window was about11m08s. Original services returned after about5m16s.

The restored old stack logged startup security/DUA/reassembly warnings, unavailable-device pings and two CLI daemon connection-reset warnings. No Matter error lines or new persistent functional failure was demonstrated; this is not an error-free-log claim. Preserve these observations without attributing them to the short diagnostic, which ran no networks.

## Next investigation

Bounded source-review worker candidate_boot_failure reports existing full-image RAIL assertion callbacks retain error/line in RAM before halting; halCrashInfo is another existing facility. Retrieval would require a debug connection not established here. The retained full image has OpenThread log output and crash dumping disabled; its weak debug-UART fallback is a no-op. These are source findings, not evidence an assertion actually occurred.

Next authorized work is offline evaluation of a retrievable full-image startup observation route. Prefer vendor facilities, validate exclusive UART handoff to CPC and capture across actual application startup before proposing another outage. Increasing host logs alone cannot show execution before transport initialization. No additional physical test is authorized by this result. Reuse VENDOR-STARTUP-FINDINGS-20260920.md and refresh online evidence for any new mechanism.

Private authoritative logs/backups/events: /home/wsluser/.local/share/ha-recovery/sdk2026-crypto-20260920; HA /share/codex-sdk2026-crypto-20260920. Source timestamps differ slightly; durations use operation events. Goal and nine-contribution reassessment remain open; this diagnostic alone changes no contribution disposition.

Sanitized machine-readable record: evidence/crypto-result-20260920.json. All work saved locally; no publication or additional production change.
