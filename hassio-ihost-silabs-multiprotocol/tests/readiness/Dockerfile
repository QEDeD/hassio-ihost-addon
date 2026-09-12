FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef

# Keep the released init/tools but remove every radio and application service.
RUN rm -rf /etc/s6-overlay/s6-rc.d /etc/cont-init.d /etc/cont-finish.d /etc/services.d \
    && mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d /etc/s6-overlay/s6-rc.d/user2/contents.d \
        /etc/s6-overlay/s6-rc.d/zigbeed /etc/s6-overlay/s6-rc.d/zigbeed-tcp /fixture \
    && printf 'bundle\n' > /etc/s6-overlay/s6-rc.d/user/type \
    && printf 'bundle\n' > /etc/s6-overlay/s6-rc.d/user2/type \
    && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/zigbeed/type \
    && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/zigbeed-tcp/type \
    && printf '#!/bin/sh\nexec sleep infinity\n' > /etc/s6-overlay/s6-rc.d/zigbeed/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/zigbeed/run \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/zigbeed \
        /etc/s6-overlay/s6-rc.d/user/contents.d/zigbeed-tcp \
    && printf '9999\n' > /fixture/port
COPY --chmod=0755 tests/readiness/listener-run /etc/s6-overlay/s6-rc.d/zigbeed-tcp/run
COPY --chmod=0755 rootfs/etc/s6-overlay/scripts/zigbeed-healthcheck /etc/s6-overlay/scripts/zigbeed-healthcheck
RUN command -v ss && command -v s6-svstat && command -v socat && s6-rc-compile /tmp/fixture-s6-db /package/admin/s6-overlay-3.1.6.2/etc/s6-rc/sources /etc/s6-overlay/s6-rc.d
ENV S6_STAGE2_HOOK=""
HEALTHCHECK --interval=1s --timeout=2s --start-period=0s --retries=1 CMD /etc/s6-overlay/scripts/zigbeed-healthcheck
ENTRYPOINT ["/init"]
