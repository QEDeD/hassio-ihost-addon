#!/bin/bash
# Runs only while assembling Dockerfile.sdk2026, after the existing app rootfs.
set -euo pipefail
case "${CPC_ENCRYPTION:?}" in ON) disabled=false ;; OFF) disabled=true ;; *) exit 2 ;; esac
install -Dm755 /sdk2026-runtime/cpc-key-preflight.py /usr/local/bin/cpc-key-preflight
install -m755 /sdk2026-runtime/cpcd-run /etc/s6-overlay/s6-rc.d/cpcd/run
install -m755 /sdk2026-runtime/cpcd-finish /etc/s6-overlay/s6-rc.d/cpcd/finish
printf '%s\n' "$CPC_ENCRYPTION" >/usr/share/sdk2026-build/cpc-mode
sed -i "s/^disable_encryption: true$/disable_encryption: $disabled/; s|^binding_key_file: .*|binding_key_file: /data/cpc/binding.key|" /usr/local/share/cpcd.conf
# Native OpenThread mDNS runs inside otbr-agent, with no external daemon.
rm /etc/s6-overlay/s6-rc.d/user/contents.d/mdns
rm /etc/s6-overlay/s6-rc.d/otbr-agent/dependencies.d/mdns
rm -r /etc/s6-overlay/s6-rc.d/mdns
sed -i '\|rm /etc/s6-overlay/s6-rc.d/user/contents.d/mdns|d' /etc/s6-overlay/scripts/otbr-enable-check.sh
