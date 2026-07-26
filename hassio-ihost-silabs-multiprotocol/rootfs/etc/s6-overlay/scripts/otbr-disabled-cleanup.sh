#!/usr/bin/with-contenv bashio
# vim: ft=bash
# shellcheck shell=bash
# ==============================================================================
# Reconcile stale OTBR firewall state while the cross-add-on owner gate is held
# ==============================================================================

# shellcheck source=otbr-agent-common
# shellcheck disable=SC1091
. /etc/s6-overlay/scripts/otbr-agent-common

if otbr_firewall_cleanup_is_safe; then
    if ! otbr_firewall_cleanup; then
        bashio::log.warning \
            "Could not completely clean up stale OTBR firewall state while disabling OTBR."
    fi
else
    bashio::log.warning \
        "Skipping stale OTBR firewall cleanup while disabling OTBR: ${otbr_cleanup_guard_reason}."
fi
