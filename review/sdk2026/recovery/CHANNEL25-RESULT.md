# Channel25 production migration — 2026-09-14

## Authority and resulting state

Operator approved compatibility checks, sequential Thread then Zigbee migration, verification and recovery; resumed with unlocked credentials. Live firmware was not changed. Thread and Zigbee now both report channel25; HA preferred Thread dataset was explicitly refreshed from live TLVs and now reports25. Network identity and Thread keys compared equal before/after (values kept private). Zigbee PAN/extended PAN/coordinator identities are unchanged.

## Recovery material

Fresh partial Supervisor backup550048aa, before-channel25-20260914,36495360 bytes, includes HA excluding history database and focused multiprotocol/Zigbee2MQTT/Matter apps. Outer members verified. SHA2564657a9f6802c8298a73cf915ba914d34243afdd1e011b4584173964219e9368e. Stored /backup/550048aa.tar, not password encrypted. Separate original Zigbee configuration /config/zigbee2mqtt/configuration.yaml.before-channel25-20260914 mode0600. Private runtime baseline and verification files under WSL /tmp/ha-channel25-*.json; include secrets in baseline, never publish them. VM/host backups are not a network-wide channel undo.

## Sequence and observations

- HA otbr/set_channel accepted25 with300-second delay, pending dataset target verified. Thread initially had two identify timeouts; all four devices subsequently recovered, including fresh ALPSTUGA and computer-plug reports and successful identify responses, before Zigbee migration.
- Changed exactly saved Zigbee channel20 to25 and restarted only Zigbee2MQTT. Actual bridge/info reported25 and all31 entries (coordinator+30devices).
- Initial read-only checks then showed widespread Zigbee delivery failures and all four Matter identify failures. This was not accepted as success.
- One controlled recovery: stop Zigbee2MQTT, restart focused multiprotocol app, start Zigbee2MQTT. No radio flash/reset/erase, re-pairing or plug load interruption. Firmware remained SL-OPENTHREAD2.6.1.0_GitHub-7f6723ffb with host zigbeed8.1.1.
- After recovery, all four Matter identify commands completed.19 of24 Zigbee routers produced fresh messages in a paced state-read observation window. Actual Thread channel still25.
- HA preferred saved Thread dataset remained15 after the live change. Used thread/add_dataset_tlv with the actual current dataset, source otbr; result stored; readback preferred25. This is an observed synchronization gap worth investigating separately, not a proven upstream defect.

## Unmet verification

Five mains-powered Zigbee devices did not produce fresh replies: Bryggers, Iris bordlampe, Iris værelse_loft_bulb, entre_loft_glaslampe_bulb, stue_loft_kattetræ_kontakt_01. Targeted retry still failed for four; no corresponding reply found for Iris bordlampe. Their pre-migration powered/reachable state was not individually established; do not call these confirmed regressions or assume powered off.

Six end devices remain individually unverified: bryggers_gulv_water-leak, motion-sensor-entre,0xcc86ecfffea38d2f,badeværelse,0x54ef4410006940ee,Hue remote stue. Water sensor and motion sensor announced during migration, but that does not establish all functional reports. Operator wake/physical observations needed before deciding any re-pairing.

Companion's phone-side dataset sync and normal physical controls are not verified. Do not claim whole-home recovery, long-term stability or reduced interference from these checks.

## Compatibility/power scope

Zigbee2MQTT supports channel change on ember and lists25 among recommended ZLL channels; actual stock firmware accepted25. Device-specific channel-change behavior remains a runtime check. There is no explicit Zigbee transmit_power override; no power setting was increased. Exact effective per-channel firmware power and every endpoint's power limits were not measured; do not claim exhaustive power validation.

## Next action

Keep current channels while operator confirms power/wakes unverified devices; perform targeted reads/actions afterward. Do not mass reset/re-pair. If genuine remaining regressions persist, choose controlled recovery based on reachable partition/device state; stale dataset restoration alone is not coordinated rollback. SDK integration work remains separate. Other HA peer was notified to avoid changes during cutover.
