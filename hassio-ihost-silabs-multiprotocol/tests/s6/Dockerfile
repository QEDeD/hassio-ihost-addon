FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef

# Remove all application/legacy services. The released /init and s6 built-ins
# remain; this image cannot launch radio, discovery or add-on initialization.
RUN rm -rf /etc/s6-overlay/s6-rc.d /etc/cont-init.d /etc/cont-finish.d /etc/services.d \
    && mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d \
        /etc/s6-overlay/s6-rc.d/otbr-agent /fixture/bin \
    && printf 'bundle\n' > /etc/s6-overlay/s6-rc.d/user/type \
    && touch /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent \
    && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/otbr-agent/type

COPY --chmod=0755 rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish /etc/s6-overlay/s6-rc.d/otbr-agent/finish
COPY rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish /etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish
COPY --chmod=0755 rootfs/etc/s6-overlay/scripts/otbr-agent-common /etc/s6-overlay/scripts/otbr-agent-common
COPY --chmod=0755 tests/s6/run /etc/s6-overlay/s6-rc.d/otbr-agent/run
COPY --chmod=0755 tests/s6/ip6tables tests/s6/ipset tests/s6/timeout /fixture/bin/
ENV PATH="/fixture/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
# Let the service's 10-second finish timeout expire before global shutdown grace.
ENV S6_SERVICES_GRACETIME=15000
ENTRYPOINT ["/init"]
