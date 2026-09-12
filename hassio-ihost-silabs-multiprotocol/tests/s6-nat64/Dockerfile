FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef
# Same released-init isolation as tests/s6, with the normal shutdown grace.
ENV S6_STAGE2_HOOK=""
HEALTHCHECK NONE
RUN rm -rf /etc/s6-overlay/s6-rc.d /etc/cont-init.d /etc/cont-finish.d /etc/services.d \
    && mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d \
        /etc/s6-overlay/s6-rc.d/user2/contents.d \
        /etc/s6-overlay/s6-rc.d/otbr-agent/data /fixture/bin /data \
    && printf 'bundle\n' > /etc/s6-overlay/s6-rc.d/user/type \
    && printf 'bundle\n' > /etc/s6-overlay/s6-rc.d/user2/type \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent \
    && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/otbr-agent/type
COPY rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/notification-fd rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-kill /etc/s6-overlay/s6-rc.d/otbr-agent/
COPY --chmod=0755 rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish /etc/s6-overlay/s6-rc.d/otbr-agent/finish
COPY --chmod=0755 rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/data/check /etc/s6-overlay/s6-rc.d/otbr-agent/data/check
COPY rootfs/etc/s6-overlay/scripts/otbr-agent-common /etc/s6-overlay/scripts/otbr-agent-common
COPY --chmod=0755 tests/s6-nat64/run /etc/s6-overlay/s6-rc.d/otbr-agent/run
COPY --chmod=0755 tests/s6-nat64/ot-ctl /fixture/bin/ot-ctl
COPY tests/s6-nat64/daemon.py tests/s6-nat64/assert.py /fixture/
RUN s6-rc-compile /tmp/fixture-s6-db \
        /package/admin/s6-overlay-3.1.6.2/etc/s6-rc/sources /etc/s6-overlay/s6-rc.d \
    && rm -rf /tmp/fixture-s6-db
ENV PATH="/fixture/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENTRYPOINT ["/init"]
