#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Disable OTBR if not enabled
# ==============================================================================

if bashio::config.false 'otbr_enable'; then
    # shellcheck source=otbr-agent-common
    # shellcheck disable=SC1091
    . /etc/s6-overlay/scripts/otbr-agent-common

    if otbr_firewall_cleanup_is_safe; then
        if ! otbr_firewall_cleanup; then
            bashio::log.warning "Could not completely clean up stale OTBR firewall state while disabling OTBR."
        fi
    else
        bashio::log.warning "Skipping stale OTBR firewall cleanup while disabling OTBR: ${otbr_cleanup_guard_reason}."
    fi

    rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent
    rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-web
    rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent-rest-discovery
    rm /etc/s6-overlay/s6-rc.d/user/contents.d/mdns
    bashio::log.info "The otbr-agent is disabled."
    bashio::exit.ok
fi

if bashio::var.has_value "$(bashio::addon.port 8080)" \
     && bashio::var.has_value "$(bashio::addon.port 8081)"; then
    bashio::log.info "Web UI and REST API port are exposed, starting otbr-web."
else
    rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-web
    bashio::log.info "The otbr-web is disabled."
fi
