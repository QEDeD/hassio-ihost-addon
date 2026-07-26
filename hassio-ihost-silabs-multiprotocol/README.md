# TEST/EXPERIMENTAL — Silicon Labs Zigbee/OpenThread candidate 186eac8

> [!CAUTION]
> Fork-only AMD64 hardware candidate. Back up Home Assistant, record the
> original options and consumer endpoints, stop every existing radio/OTBR
> owner, and follow the
> [candidate runbook](https://github.com/QEDeD/hassio-ihost-addon/blob/codex/otbr-candidate-feed/HARDWARE-TEST-RUNBOOK.md)
> before starting it.

![Supports amd64 Architecture][amd64-shield]

This feed resolves version `1.0.2` to the unique image associated with
canonical source `186eac8354fdcab9c224ec840989da1fd86af882`. Any passing
hardware report is limited to this statement:

> The required issue #83 firewall/lifecycle matrix passed on the recorded hardware for canonical source 186eac8354fdcab9c224ec840989da1fd86af882.

That scoped result is not complete broad-head hardware acceptance and does not
validate any future scope-specific upstream head. Complete broad-head hardware
acceptance additionally requires the remaining
[`RELEASE.md`](./RELEASE.md) gates:

- local serial and TCP `network_device` coverage;
- multi-interface/backbone routing;
- 24-hour concurrent Zigbee/Thread load;
- RCP reset/link-interruption and source-match recovery; and
- two-owner Silicon/standalone contention testing.

## About

This add-on allows you to use Zigbee and OpenThread protocol simultaneous on a 
single Silicon Labs based radio. The radio needs the RCP Multi-PAN firmware 
installed to support multiple IEEE 802.15.4 Personal Area Networks (PAN). The 
addon is modified based on the Silicon Labs Multiprotocol Addon. Targeted
hardware includes the SONOFF [ZBDongle-E](https://sonoff.tech/products/sonoff-zigbee-3-0-usb-dongle-plus-zbdongle-e)
and [iHost MG21 chip](https://sonoff.tech/products/sonoff-ihost-smart-home-hub).

[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

### NOTICE

1. Use a ZHA or Zigbee2MQTT version that supports the EZSP version provided by
the installed MultiPAN firmware. The configuration example in the add-on
documentation uses Zigbee2MQTT.
2. Before using this add-on, you must first flash the MultiPAN firmware via [SONOFF Dongle Flasher][sonoff-dongle-flasher] or [SONOFF Dongle Flasher Add-on](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/tree/master/hassio-ihost-sonoff-dongle-flasher).


[sonoff-dongle-flasher]: https://dongle.sonoff.tech/sonoff-dongle-flasher
