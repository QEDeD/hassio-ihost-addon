# Zigbee consumer protocol check — 2026-09-19

The SDK 2026.6.1 candidate's `zigbee/app/util/ezsp/ezsp-protocol.h:33` defines EZSP_PROTOCOL_VERSION `0x13` (19).

The previously observed production Zigbee2MQTT 2.14.1 / zigbee-herdsman 10.9.2 combination has corresponding support: the pinned `v10.9.2` source in `src/adapter/ember/ezsp/consts.ts` declares minimum `0x0d` and latest `0x13`.

Primary source: https://github.com/Koenkk/zigbee-herdsman/blob/v10.9.2/src/adapter/ember/ezsp/consts.ts

This removes an apparent protocol-version prerequisite for this candidate. It does not prove command behavior or runtime negotiation; the approved trial must verify the actual reported protocol, firmware version and resumed network. A September 19 request for selected startup lines from the live app log returned none (log history had no matching lines), so it did not independently reverify today's herdsman version. Reconfirm the installed package or startup version before the trial; do not substitute this source check for that observation.

## HA OTBR client

On September19, the official HA Core2026.9.3 OTBR manifest was retrieved and declares python-otbr-api==2.10.0, the same client exercised by the existing eight candidate API test groups. The Core patch-version change alone does not justify duplicating those unchanged-source API tests. Live cross-interface discovery remains separate. Source: https://github.com/home-assistant/core/blob/2026.9.3/homeassistant/components/otbr/manifest.json
