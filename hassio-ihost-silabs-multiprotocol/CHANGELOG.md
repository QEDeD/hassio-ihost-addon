# Changelog

## 1.0.3

- Fix OTBR startup on Home Assistant OS 18 when ingress filtering is disabled
- Replace the obsolete legacy iptables and host-wide forwarding-policy changes with scoped `wpan0` rules
- Recover stale OTBR chains and bound firewall cleanup retries
- Clean stale OTBR firewall state when OpenThread is disabled

## 1.0.2

- fix ASH_ERROR_TIMEOUTS error on Zigbee2MQTT first launch
- fix zigbee.conf not found

## 1.0.0

- initial version
- Use Silicon Labs Simplicity SDK 2024.12.01
