# Changelog

## 1.0.3

- Fix OTBR startup on Home Assistant OS 18 when ingress filtering is disabled
- Replace the obsolete legacy iptables and host-wide forwarding-policy changes with scoped `wpan0` rules
- Recover stale OTBR chains and keep firewall cleanup within the service shutdown deadline
- Treat absent owned chains as a clean state with nft-backed iptables
- Clean stale OTBR firewall state when OpenThread is disabled unless `wpan0` may have another active owner
- Restore image builds with the current SLC CLI by supplying its required Java 21 runtime

## 1.0.2

- fix ASH_ERROR_TIMEOUTS error on Zigbee2MQTT first launch
- fix zigbee.conf not found

## 1.0.0

- initial version
- Use Silicon Labs Simplicity SDK 2024.12.01
