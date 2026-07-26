# check=error=true
ARG BUILD_FROM=ghcr.io/home-assistant/armv7-base-debian:bookworm
ARG BUILD_IMAGE_PLATFORM=linux/arm/v7
FROM --platform=${BUILD_IMAGE_PLATFORM} $BUILD_FROM

ARG OTBR_VERSION
ARG UNIVERSAL_SILABS_FLASHER

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV \
    BORDER_ROUTING=1 \
    BACKBONE_ROUTER=1 \
    PLATFORM=debian \
    RELEASE=1 \
    WEB_GUI=1 \
    REST_API=1 \
    DHCPV6_PD_REF=0 \
    DOCKER=1 \
    GIT_HTTP_LOW_SPEED_LIMIT=1024 \
    GIT_HTTP_LOW_SPEED_TIME=60

COPY 0001-channel-monitor-disable-by-default.patch /usr/src
COPY 0002-spinel-Clear-source-match-tables-before-restoring.patch /usr/src
COPY 0003-nat64-handle-ipv4-options.patch /usr/src
COPY openthread-core-ha-config-posix.h /usr/src
# Required during OTBR and armv7 Python-extension builds; removed after build
ENV OTBR_BUILD_DEPS="build-essential ninja-build cmake wget ca-certificates \
  libreadline-dev libncurses-dev libcpputest-dev libdbus-1-dev libavahi-common-dev \
  libavahi-client-dev libboost-dev libboost-filesystem-dev libboost-system-dev \
  libnetfilter-queue-dev python3-dev libffi-dev pkg-config"

# Installed during build (script/bootstrap) but unused in our configuration
ENV OTBR_UNUSED_DEBS="libavahi-client3 avahi-daemon rsyslog"

WORKDIR /usr/src

# Fail source builds before apt and clone if the builder omitted a required,
# reproducibility-sensitive input from build.yaml.
RUN \
    test -n "${OTBR_VERSION}" \
    && test -n "${UNIVERSAL_SILABS_FLASHER}"

# Install npm/nodejs for WebUI before calling script/bootstrap to avoid
# systemd getting pulled in
RUN \
    set -x \
    # Bound mirror failures for this layer and apt calls made by bootstrap. \
    && printf '%s\n' \
       'Acquire::Retries "3";' \
       'Acquire::http::Timeout "30";' \
       'Acquire::https::Timeout "30";' \
       > /etc/apt/apt.conf.d/80-network-bounds \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       iproute2 \
       python3 \
       python3-dev \
       python3-pip \
       libffi-dev \
       libffi8 \
       pkg-config \
       lsb-release \
       netcat-openbsd \
       socat \
       sudo \
       git \
       nodejs \
       npm \
    && git clone --depth 1 -b main \
       https://github.com/openthread/ot-br-posix.git \
    && cd ot-br-posix \
    && git fetch origin ${OTBR_VERSION} \
    && git checkout ${OTBR_VERSION} \
    && git submodule update --init \
    && ( \
        cd third_party/openthread/repo \
        && git apply --whitespace=error-all \
           /usr/src/0001-channel-monitor-disable-by-default.patch \
        && git apply --whitespace=error-all \
           /usr/src/0002-spinel-Clear-source-match-tables-before-restoring.patch \
        && git apply --whitespace=error-all \
           /usr/src/0003-nat64-handle-ipv4-options.patch \
        && grep -Fqx \
           '    IgnoreError(ClearSrcMatchShortEntries());' \
           src/lib/spinel/radio_spinel.cpp \
        && grep -Fqx \
           '        VerifyOrExit(!HasSourceRouteOption(aMessage));' \
           src/core/net/ip4_types.cpp \
        && grep -Fqx \
           '    aMessage.RemoveHeader(ip4Header.GetHeaderLength());' \
           src/core/net/nat64_translator.cpp \
        && grep -Fqx \
           '                              ip4Header.GetTotalLength() - ip4Header.GetHeaderLength());' \
           src/core/net/nat64_translator.cpp \
        && grep -Fqx \
           '                                       ip4Header.GetTotalLength() - ip4Header.GetHeaderLength());' \
           src/core/net/nat64_translator.cpp \
        && cp /usr/src/openthread-core-ha-config-posix.h . \
       ) \
    # Apply source backports before the expensive bootstrap so an incompatible \
    # pinned revision fails quickly instead of after cross-architecture setup. \
    && ./script/bootstrap \
    # Mimic rt_tables_install \
    && echo "88 openthread" >> /etc/iproute2/rt_tables \
    # Mimic otbr_install \
    && (./script/cmake-build \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DOTBR_FEATURE_FLAGS=ON \
        -DOTBR_DNSSD_DISCOVERY_PROXY=ON \
        -DOTBR_SRP_ADVERTISING_PROXY=ON \
        -DOTBR_MDNS=mDNSResponder \
        -DOTBR_VERSION= \
        -DOT_PACKAGE_VERSION= \
        -DOTBR_DBUS=OFF \
        -DOT_POSIX_RCP_BUS_UART=ON \
        -DOT_LINK_RAW=1 \
        -DOTBR_VENDOR_NAME="Home Assistant" \
        -DOTBR_PRODUCT_NAME="OpenThread Border Router" \
        -DOTBR_WEB=ON \
        -DOTBR_BORDER_ROUTING=ON \
        -DOTBR_REST=ON \
        -DOTBR_BACKBONE_ROUTER=ON \
        -DOTBR_TREL=ON \
        -DOTBR_NAT64=ON \
        -DOT_POSIX_NAT64_CIDR="192.168.255.0/24" \
        -DOTBR_DNS_UPSTREAM_QUERY=ON \
        -DOT_CHANNEL_MONITOR=ON \
        -DOT_COAP=OFF \
        -DOT_COAPS=OFF \
        -DOT_DNS_CLIENT_OVER_TCP=OFF \
        -DOT_THREAD_VERSION=1.3 \
        -DOT_PROJECT_CONFIG="../openthread-core-ha-config-posix.h" \
        -DOT_RCP_RESTORATION_MAX_COUNT=2 \
        && cd build/otbr/ \
        && ninja \
        && ninja install) \
    && pip install --retries 3 --timeout 60 --break-system-packages \
       universal-silabs-flasher==${UNIVERSAL_SILABS_FLASHER} \
    && apt-get purge -y --auto-remove \
       git \
       nodejs \
       npm \
       ${OTBR_BUILD_DEPS} \
       ${OTBR_UNUSED_DEBS} \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/* \
    && python3 -c "from cffi import FFI; FFI(); import gpiod" \
    && universal-silabs-flasher --help >/dev/null

COPY rootfs /

ENV \
    S6_STAGE2_HOOK=/etc/s6-overlay/scripts/enable-check.sh

# Keep publisher metadata last so release version changes do not invalidate
# the expensive OTBR compilation layer.
ARG BUILD_ARCH
ARG BUILD_COMMIT
ARG BUILD_VERSION
RUN \
    test -n "${BUILD_ARCH}" \
    && test -n "${BUILD_COMMIT}" \
    && test -n "${BUILD_VERSION}"
LABEL \
    io.hass.version="${BUILD_VERSION}" \
    io.hass.type="app" \
    io.hass.arch="${BUILD_ARCH}" \
    org.opencontainers.image.version="${BUILD_VERSION}" \
    org.opencontainers.image.source="https://github.com/iHost-Open-Source-Project/hassio-ihost-addon" \
    org.opencontainers.image.revision="${BUILD_COMMIT}"
