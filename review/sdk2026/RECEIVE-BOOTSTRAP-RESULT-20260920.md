# Receive bootstrap trial result — September 20, 2026

The approved single RXB1 diagnostic passed. The first CPC version query received a valid matched4.9.1 reply in8.44milliseconds; no retry was needed. Both receive-transfer adjustments succeeded, with no checksum failures or receive overflow. Mandatory original4.6.0 restoration and representative recovery checks passed. Radio-service interruption was285.6seconds (about4m46s). The SDK upgrade itself remains incomplete.

## Evidence and conclusion

Candidate GBL9b88fe804f87897091fee0a140dc68440ea26c170a36cae706ac38245b5dde60 produced a valid929byte RXB1 record. snapshot_valid127, takeover7,289051 completed loops, two completed receive callbacks, one valid U-frame and two completed transmissions. resize_calls2/resize_ok2/resize_fail0/resize_already0; invalid header/payload CRC counts0; first_bad_seen0; UART.IF0x2002 without overflow. The host request has independently valid header/payload CRCs and the lifecycle capture matched the reply to sequence0. The response duration is one diagnostic observation, not a reliability or performance benchmark.

The previous otherwise comparable receive diagnostic failed both resize operations and rejected its only frame, then overflowed. Preparing a static bootstrap descriptor before the load eliminated those failures in this instrumented test. This strongly supports the initialization correction and the proposed ordering hazard. It does not independently prove every internal bus event or all prior failures' causes; layout/timing changed and general restart/resize synchronization remains unqualified.

## Recovery

- Fresh window approval applied to this one corrected diagnostic and mandatory restoration. Access and baseline checks passed; tooling setup had two harmless preflight command corrections before downtime (checksum manifest location and unsupported flasher --version replaced by package metadata).
- Writers stopped16:06:27–16:06:59UTC; fresh coherent backups independently verified16:07:04. Core/Matter restarted16:07:32; original control passed16:07:46.
- One candidate upload16:07:59–16:08:38. Mandatory original restoration16:08:54–16:09:41; settled original control passed16:10:11.
- Radio/Z2M restarted16:11:03/12, policies restored16:11:13. Network identities/PAN/key/channel25/Thread dataset match the stopped backup. No stale host state was restored.
- Initial Matter availability gate waited for reconnection; no commands were sent while unavailable. Zigbee read returned currentLevel1 and Matter Identify returned Success(0) at16:12:10. ALPSTUGA temperature/humidity/CO2 reports updated16:16:30.
- Temporary tools removed16:12:34; all113 original SSH package versions match. Four original app versions/options/policies/running states match at final observation16:16:48, after333.1seconds.
- No newly unavailable radio-device entities. Two Home Connect dishwasher option switches became unavailable while its connectivity remained on and programme progress advanced33→58. This is separate from the radio recovery; the cause of those option availability changes was not investigated. Logs retain Thread fragment/reassembly messages and Zigbee ping failures; no error-free or long-term reliability claim.

Event timestamps and durations use WSL UTC, not the differing Windows/tool clock. Sanitized exact evidence: [receive-bootstrap-result-20260920.json](evidence/receive-bootstrap-result-20260920.json). Raw logs/backups remain private at /home/wsluser/.local/share/ha-recovery/sdk2026-bootstrap-20260920 and HA /share/codex-sdk2026-bootstrap-20260920. Helper flash/backup actions are consumed and must not be replayed.

## Next milestone

A normal, non-halting firmware candidate with only the tested initialization change is being prepared offline in firmware/receive-fix. It must independently pass package/source/linked checks and then a separately approved hardware/service trial. Encrypted CPC binding, preserved networks with the new host/firmware pair, discovery, restart persistence and recovery still require qualification. This successful diagnostic does not authorize leaving a candidate installed or broadening production changes.
