# Production acceptance observations — proposed, 2026-09-19

No production trial has run. Fresh read-only baseline evidence selected the following representative devices; recheck immediately before the maintenance window. Never switch a load merely to establish communication.

| Stack | Device / observation | Proposed post-change check |
| --- | --- | --- |
| Zigbee | Computer-ceiling bulb01 (`light.stue_loft_computerbord_bulb_01`); last-seen sensor reported2026-09-19T15:16:31+02:00. Inventory links successful prior non-actuating reads. | One explicit non-actuating OnOff attribute read through existing Z2M request path, plus a newly received last-seen/message timestamp after cutover. HA cached on/off alone is insufficient. |
| Thread/Matter | ALPSTUGA temperature/humidity/CO2 reports at15:16:37+02:00 | Newly received sensor report after cutover and after app restart; preserve existing Matter fabric/device identity. |
| Thread/Matter | GRILLPLATS computer plug power reported203.8W at15:17:35+02:00 | New telemetry or an existing supported non-actuating Matter attribute read. Do not toggle this plug: it supplies an active load. |
| Host consumers | Z2M bridge online and version2.14.1 | Fresh bridge connection plus actual device traffic; started/online is necessary but not sufficient. |

Record private before/after coordinator identity, Zigbee PAN/channel, Thread extended PAN/channel/active dataset identity and actual whole-store filename selection. Compare existing membership rather than interpreting a newly created network as success. Do not print keys/datasets. Keep powered-off devices and previously failing Hue delivery out of the representative pass criterion; separately report new regressions.

## Encrypted CPC evidence without secret-bearing tracing

Socket presence is only service readiness. The binding completion marker proves the bounded provisioning operation, not subsequent encrypted application traffic.

Use these combined checks:

1. Exact approved host/firmware identity; compiled host encryptionON and rendered disable_encryption:false; persistent key valid, private and byte-identical to the protected post-binding copy.
2. Existing firmware evidence verifies shared radio endpoint12 opens without the encryption-disable flag and linked CPC security remains enabled/default-unbind-denied. Both host network stacks use this endpoint.
3. Fresh bidirectional radio traffic after the candidate starts: a Zigbee request/response plus Thread/Matter communication. Repeat after one controlled app stop/start with the same saved key and network identities. Mere cached HA state or CPC control socket is insufficient.

Inspected pinned CPCd4.9.1 commit87f6dbda4eef05e4538589c195099c3daf8f6f6b: security/security.c returns NOT_INITIALIZED from encryption/decryption unless session initialization completed; security/private/protocol/protocol.c sets that flag only after successful secondary session response and session-key derivation. Its success message is TRACE_SECURITY, not a guaranteed INFO log. Do not enable security/frame traces merely to obtain a marker. Exact encrypted configuration plus enforced encrypted endpoint and successful fresh traffic supports functional encrypted-session acceptance; this is not independent on-wire cryptographic measurement.

Protocol/session errors or repeated service restarts fail the check. A coherent fresh post-restart state/key backup closes the initial trial. Ten minutes of observation and one app restart do not prove long-term reliability or persistence through dongle power loss; report those limits explicitly.
