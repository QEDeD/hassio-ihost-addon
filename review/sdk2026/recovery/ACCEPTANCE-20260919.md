# Production acceptance observations — proposed, 2026-09-19

No production trial has run. Fresh read-only baseline evidence selected the following representative devices; recheck immediately before the maintenance window. Never switch a load merely to establish communication.

| Stack | Device / observation | Proposed post-change check |
| --- | --- | --- |
| Zigbee | Computer-ceiling bulb01 (`light.stue_loft_computerbord_bulb_01`); last-seen sensor reported2026-09-19T15:16:31+02:00. Inventory links successful prior non-actuating reads. | One explicit non-actuating OnOff attribute read through existing Z2M request path, plus a newly received last-seen/message timestamp after cutover. HA cached on/off alone is insufficient. |
| Thread/Matter | ALPSTUGA temperature/humidity/CO2 reports at15:16:37+02:00 | Newly received sensor report after cutover and after app restart; preserve existing Matter fabric/device identity. |
| Thread/Matter | GRILLPLATS computer plug power reported203.8W at15:17:35+02:00 | New telemetry or an existing supported non-actuating Matter attribute read. Do not toggle this plug: it supplies an active load. |
| Host consumers | Z2M bridge online and version2.14.1 | Fresh bridge connection plus actual device traffic; started/online is necessary but not sufficient. |

Record private before/after coordinator identity, Zigbee PAN/channel, Thread extended PAN/channel/active dataset identity and actual whole-store filename selection. Compare existing membership rather than interpreting a newly created network as success. Do not print keys/datasets. Keep powered-off devices and previously failing Hue delivery out of the representative pass criterion; separately report new regressions.

## Concrete Zigbee read route

Use HA's existing `mqtt.publish` service with `retain:false` and payload `{"state":""}` on `<current MQTT base>/<current friendly name>/get`. Resolve the current base and friendly name from bridge configuration/device mapping for IEEE `0x94b216fffeb4de94`; do not infer them from the HA entity ID. Subscribe to that device's state topic before sending and correlate a new response/last-seen with the request and Z2M read result. A retained or cached state, service-call success alone, or an unrelated report is insufficient. Only proceed if the installed device exposes state reading.

This uses the documented existing get interface and needs no temporary extension. Alternative direct ZCL read, if required by the installed exposes: publish only `{"read":{"cluster":"genOnOff","attributes":["onOff"]}}` through the documented device set endpoint; verify the explicit ZCL response in the log. Despite that endpoint's name, this particular payload is a read, not an on/off command. Prefer the simpler get route when supported. [Zigbee2MQTT API](https://www.zigbee2mqtt.io/guide/usage/mqtt_topics_and_messages.html).

These are request/response communication checks, not proof of physical actuation. Final trial approval should name any representative physical control and exact restoration step if physical control is part of acceptance; do not silently substitute read success for it. The existing computer plug supplies an active load and must not be switched. Fresh Matter reports and successful subscription recovery establish traffic; a new Matter attribute-read mechanism has not been selected or tested and is not an excuse to add custom tooling before evaluating the existing path.

## Encrypted CPC evidence without secret-bearing tracing

Socket presence is only service readiness. The binding completion marker proves the bounded provisioning operation, not subsequent encrypted application traffic.

Use these combined checks:

1. Exact approved host/firmware identity; compiled host encryptionON and rendered disable_encryption:false; persistent key valid, private and byte-identical to the protected post-binding copy.
2. Existing firmware evidence verifies shared radio endpoint12 opens without the encryption-disable flag and linked CPC security remains enabled/default-unbind-denied. Both host network stacks use this endpoint.
3. Fresh bidirectional radio traffic after the candidate starts: a Zigbee request/response plus Thread/Matter communication. Repeat after one controlled app stop/start with the same saved key and network identities. Mere cached HA state or CPC control socket is insufficient.

Inspected pinned CPCd4.9.1 commit87f6dbda4eef05e4538589c195099c3daf8f6f6b: security/security.c returns NOT_INITIALIZED from encryption/decryption unless session initialization completed; security/private/protocol/protocol.c sets that flag only after successful secondary session response and session-key derivation. Its success message is TRACE_SECURITY, not a guaranteed INFO log. Do not enable security/frame traces merely to obtain a marker. Exact encrypted configuration plus enforced encrypted endpoint and successful fresh traffic supports functional encrypted-session acceptance; this is not independent on-wire cryptographic measurement.

Protocol/session errors or repeated service restarts fail the check. A coherent fresh post-restart state/key backup closes the initial trial. Ten minutes of observation and one app restart do not prove long-term reliability or persistence through dongle power loss; report those limits explicitly.

## Final proposed command checks (require production-trial approval)

The current Zigbee bulb exposes brightness and was on at brightness26 during the September19 read-only check. Its stored endpoint1 advertises OnOff(6), LevelControl(8) and Identify(3). At18:17:06UTC, one explicit non-actuating LevelControl read was published to `zigbee2mqtt/stue_loft_computerbord_bulb_01/set` with `{"read":{"cluster":"genLevelCtrl","attributes":["currentLevel"]}}`, retain false. Z2M recorded the matching read result at20:17:07CEST: currentLevel26. This establishes the real baseline read route, not physical control success. Use this proven direct read for candidate verification; no further exposes investigation is a prerequisite.

After candidate restart, while the bulb is still on, read and save its current level B. Set brightness to B+1 (or B-1 if B is254), transition0, using `light.turn_on` on `light.stue_loft_computerbord_bulb_01`. Require an explicit LevelControl readback of the test value, then restore B immediately and require its readback. Keep on/off and color settings unchanged. This is one small, temporary brightness change and restoration on one named lamp, not a group replay. If the lamp is off, unavailable, or an intervening operator/automation change is detected, do not turn it on or overwrite the newer setting; reselect the check with the operator. A restoration failure is a failed test requiring immediate attention, not something to hide behind an otherwise healthy radio result.

For Matter, use existing `button.alpstuga_air_quality_monitor_identify` through `button.press` once after initial candidate startup and once after the controlled app restart. HA Core2026.9.3's button.py maps this entity to `Identify(identifyTime=15)` and awaits send_device_command through entity.py. It does not send an OnOff command. Check command completion without a Matter error and newly received ALPSTUGA measurements; distinguish protocol success from human observation of its identification display. No plug power is toggled and no persistent identification setting is required. Sources: [button implementation](https://github.com/home-assistant/core/blob/2026.9.3/homeassistant/components/matter/button.py), [command dispatch](https://github.com/home-assistant/core/blob/2026.9.3/homeassistant/components/matter/entity.py). Neither the Identify command nor bulb brightness changes have been executed during preparation.
