# Shared-channel investigation and conditional trial plan — 2026-09-14

## Outcome and reviewed approach

Investigate whether aligning Thread with Zigbee improves the shared dongle, choose a channel from local RF evidence, and prepare a separately approved migration. No channel, dataset, firmware, permissions or firewall changes were made. Plan review retained existing HA/OpenThread facilities and rejected a custom migration tool or inference of current interference from old AP configuration.

## Evidence obtained

- HA access check passed. Current OTBR role GET /node/state returned router; GET /node/dataset/pending returned HTTP 204 (no pending dataset). Prior active dataset observation was channel 15; Zigbee configuration and inventory evidence specify 20.
- Local Realtek 8922AE Wi-Fi adapter exists and is disconnected, radio enabled. netsh wlan show networks mode=bssid was refused: Windows requires location permission and reports elevation required. No scan results obtained; privacy settings left unchanged.
- June 4 FortiGate sanitized snapshot allows Wi-Fi channels 1/6/11. This is historical configuration, not current channel, width, utilization or neighbour evidence. Existing FortiGate reader only covers firewall/network configuration; wireless telemetry is outside its catalogue. No tooling expansion attempted.
- Silicon Labs reports both arrangements perform well in most tests; its heaviest fragmented Thread traffic caused Zigbee loss/latency on dual channels. Test UART was 921 kbps with flow control, unlike this setup. Do not promise equivalent gains here.
- Candidate radio_channel_switching.cpp:68 onward reports multi-channel enabled only when initialized PAN channels differ. radio_interface.cpp:275 onward conditionally configures RX channel switching based on that result. This supports a real operational distinction when aligning channels; absolute sensitivity gain remains unmeasured and PHY selection requires further verification before promising it.
- HA 2026.9.2 otbr/websocket_api.py exposes otbr/set_channel; it invokes python_otbr_api set_channel with the standard pending-dataset delay. It rejects is_multiprotocol_url(data.url), but that helper compares the hostname specifically with the official Silicon Labs app hostname. Our local-codex-ihost-otbr-focused hostname differs; source-level guard is not a demonstrated blocker. No mutation call was made to test it.
- Existing api-tests/results.json already verifies nested pending dataset writes and reads using the candidate API. This is serialization/API evidence, not a multi-device migration or test of the current live build.
- Current HA documentation specifies a roughly five-minute scheduled transition. OpenThread documents propagation through a pending dataset and a delay long enough for sleepy devices. Do not edit the local active dataset or create a replacement network.

## Decision

Thread 15 to 20 remains the lowest-disruption candidate, not a measured optimal channel. Leave Zigbee on 20 unless RF evidence clearly supports a larger migration. Candidate channels 15/20/25 should be compared; 26 can be assessed for Thread alone but requires explicit Zigbee/device and power compatibility consideration before proposing it as a shared channel. Do not infer a channel is quiet from its nominal Wi-Fi overlap alone.

## Remaining measurement work

Obtain permitted Wi-Fi scans near the dongle and weak devices, including channel, width, signal and activity where exposed; one workstation scan alone cannot establish whole-home conditions. Windows location permission or existing AP wireless telemetry access is needed. Prefer AP telemetry over building tooling. For 802.15.4 energy scans, first establish available live CLI/commissioner access and bound off-channel time; ordinary SSH app has neither ot-ctl nor Docker. Candidate REST supports commissioner energy scan actions, but that does not establish the current deployed version supports them. Do not install the candidate merely to survey.

## Conditional migration and verification

1. Confirm active channel, no pending dataset, selected border router/network and all four expected Matter devices healthy; save fresh private network/HA state. Record normal Zigbee failures/retries and representative command latency. No concurrent firmware/network work.
2. Choose channel from measurements and request the reserved live cutover approval with expected brief disruption and device-recovery limits. Prefer HA's existing otbr/set_channel flow if runtime eligibility agrees with reviewed source. No raw active-dataset write or factory reset.
3. Request one scheduled update with the existing five-minute delay; verify pending target/timestamps without exposing keys. Keep devices powered and do not restart OTBR or issue competing updates during the delay.
4. Verify active channel afterward, unchanged network identity/keys, pending state cleared, all four Matter devices reporting, and representative Thread control plus Zigbee remote/group reliability. Compare like-for-like conditions, then normal use; a handful of successes is not proof of improvement.
5. If the mesh remains reachable but worsens, reverse through a NEW coordinated pending update to channel 15 with newer timestamps. A stale backup is not a network-wide undo. If devices are stranded, stop competing changes and diagnose reachability; physical power cycling or re-commissioning may be necessary and is not an automatic authorization. Preserve membership and avoid resets.
6. Verify HA's saved Thread dataset follows the new revision and assess Companion credential synchronization for future commissioning; existing Matter fabric membership should be preserved by a channel-only change, but device continuity must be observed.

No optimal channel selected and no live before/after trial completed. The immediate missing input is access to useful current RF observations, not more generic documentation.

Sources:
- https://www.home-assistant.io/integrations/thread
- https://raw.githubusercontent.com/home-assistant/core/2026.9.2/homeassistant/components/otbr/websocket_api.py
- https://raw.githubusercontent.com/home-assistant/core/2026.9.2/homeassistant/components/homeassistant_hardware/silabs_multiprotocol_addon.py
- https://openthread.io/reference/cli/commands
- https://openthread.io/reference/cli/concepts/dataset
- https://docs.silabs.com/shared-content/1.0.3/multi-pan-rcp-performance-for-openthread-and-zigbee/06-test-results-summary
