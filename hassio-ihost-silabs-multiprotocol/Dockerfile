ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bullseye
ARG BUILD_ARCH=amd64
ARG BUILD_TOOL_PLATFORM=linux/amd64
# The Linux SLC CLI is an amd64 build tool; Java never enters target images.
FROM --platform=${BUILD_TOOL_PLATFORM} amazoncorretto:21-al2-jdk@sha256:6bd5dbcb269cbcd5d1470743f5dd9ba4310555d6db55bdc09211971732d792ce AS slc-java

FROM --platform=${BUILD_TOOL_PLATFORM} debian:bullseye AS cross-builder-base

ENV \
    LANG="C.UTF-8" \
    DEBIAN_FRONTEND="noninteractive" \
    CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt" \
    GIT_HTTP_LOW_SPEED_LIMIT="1024" \
    GIT_HTTP_LOW_SPEED_TIME="60"

WORKDIR /usr/src

# Allow to reuse downloaded packages (these are only staged build images)
# hadolint ignore=DL3009
RUN \
    set -x \
    && printf '%s\n' \
       'Acquire::Retries "3";' \
       'Acquire::http::Timeout "60";' \
       'Acquire::https::Timeout "60";' \
       > /etc/apt/apt.conf.d/80-network-retries \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       curl \
       ca-certificates \
       build-essential \
       git

FROM cross-builder-base AS cross-builder-armv7

COPY debian-armv7.cmake /usr/src/debian.cmake

ENV DEBIAN_ARCH=armhf
ENV DEBIAN_CROSS_PREFIX=arm-linux-gnueabihf
ENV SLC_ARCH=linux_arch_32

RUN \
    set -x \
    && dpkg --add-architecture armhf \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       crossbuild-essential-armhf

FROM cross-builder-base AS cross-builder-aarch64

COPY debian-arm64.cmake /usr/src/debian.cmake

ENV DEBIAN_ARCH=arm64
ENV DEBIAN_CROSS_PREFIX=aarch64-linux-gnu
ENV SLC_ARCH=linux_arch_64

RUN \
    set -x \
    && dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       crossbuild-essential-arm64

FROM cross-builder-base AS cross-builder-amd64

COPY debian-amd64.cmake /usr/src/debian.cmake

ENV DEBIAN_ARCH=amd64 \
        DEBIAN_CROSS_PREFIX=x86_64-linux-gnu \
        SLC_ARCH=zigbee_x86_64

RUN \
    set -x \
    && dpkg --add-architecture amd64 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       crossbuild-essential-amd64


FROM cross-builder-${BUILD_ARCH} AS cpcd-builder

ARG CPCD_VERSION
ENV CPCD_DIR=/usr/src/cpc-daemon
RUN \
    set -x \
    && apt-get install -y --no-install-recommends \
       cmake \
       "libmbedtls-dev:${DEBIAN_ARCH}" \
       "libmbedtls12:${DEBIAN_ARCH}" \
    && git clone --depth 1 -b "${CPCD_VERSION}" \
       https://github.com/SiliconLabs/cpc-daemon.git \
    && mkdir $CPCD_DIR/build && cd $CPCD_DIR/build \
    && cmake ../ \
       -DCMAKE_TOOLCHAIN_FILE=../debian.cmake \
       -DENABLE_ENCRYPTION=FALSE \
    && make \
    && make install

FROM cross-builder-${BUILD_ARCH} AS zigbeed-builder

ARG GECKO_SDK_VERSION
ARG SLC_CLI_SHA256

COPY --from=slc-java /usr/lib/jvm/java-21-amazon-corretto /opt/java/openjdk

RUN \
    set -x \
    && apt-get install -y --no-install-recommends \
       python3 \
       python3-jinja2 \
       python3-pip \
       git-lfs \
       unzip \
    && curl --fail --location --show-error \
       --retry 3 --retry-delay 2 --retry-connrefused \
       --connect-timeout 30 --max-time 300 \
       --output slc_cli_linux.zip \
       https://www.silabs.com/documents/login/software/slc_cli_linux.zip \
    && printf '%s  %s\n' "${SLC_CLI_SHA256}" slc_cli_linux.zip \
       | sha256sum --check --strict - \
    && unzip -q slc_cli_linux.zip \
    && cd slc_cli/ && chmod +x slc
 
ENV JAVA_HOME="/opt/java/openjdk"
ENV PATH="${JAVA_HOME}/bin:/usr/src/slc_cli/:$PATH"

RUN \
    set -x \
    && git clone --depth 1 -b ${GECKO_SDK_VERSION} \
        https://github.com/SiliconLabs/simplicity_sdk.git gecko_sdk

# zigbeed links against libcpc.so
COPY --from=cpcd-builder /usr/local/ /usr/${DEBIAN_CROSS_PREFIX}/
COPY otbr-patches/0001-Avoid-writing-to-system-console.patch /usr/src
COPY otbr-patches/0001-rest-support-deleting-the-dataset.patch /usr/src
COPY zigbeed-patches/zigbeed_amd64.patch /usr/src/gecko_sdk/zigbeed_amd64.patch

RUN \
    set -x \
    && cd gecko_sdk \
    && patch -p1 < /usr/src/0001-Avoid-writing-to-system-console.patch \
    && patch -p1 < /usr/src/0001-rest-support-deleting-the-dataset.patch \
    && if [ "${DEBIAN_ARCH}" = "amd64" ]; then \
        patch -p1 < zigbeed_amd64.patch; \
        fi \
    && GECKO_SDK=$(pwd) \
    && slc signature trust --sdk=${GECKO_SDK} \
    && cd protocol/zigbee \
    && slc generate \
       --sdk=${GECKO_SDK} \
       --with="${SLC_ARCH}" \
       --project-file=$(pwd)/app/projects/zigbeed/zigbeed.slcp \
       --export-destination=$(pwd)/app/projects/zigbeed/output \
       --copy-proj-sources \
    && cd app/projects/zigbeed/output \
    && make -f zigbeed.Makefile \
        AR="${DEBIAN_CROSS_PREFIX}-ar" \
        CC="${DEBIAN_CROSS_PREFIX}-gcc" \
        LD="${DEBIAN_CROSS_PREFIX}-gcc" \
        CXX="${DEBIAN_CROSS_PREFIX}-g++" \
        C_FLAGS="-std=gnu99 -DEMBER_MULTICAST_TABLE_SIZE=16" \
        debug

FROM zigbeed-builder AS otbr-source

ARG OPENTHREAD_RECOVERY_PATCH_SHA256

COPY openthread-patches/0002-spinel-Clear-source-match-tables-before-restoring.patch /usr/src/openthread-recovery.patch

RUN \
    set -x \
    && cd gecko_sdk \
    && printf '%s  %s\n' "${OPENTHREAD_RECOVERY_PATCH_SHA256}" \
       /usr/src/openthread-recovery.patch \
       | sha256sum --check --strict - \
    && git apply --check --whitespace=error-all \
       --directory=util/third_party/openthread \
       /usr/src/openthread-recovery.patch \
    && git apply --whitespace=error-all \
       --directory=util/third_party/openthread \
       /usr/src/openthread-recovery.patch \
    && grep -Fqx '    IgnoreError(ClearSrcMatchShortEntries());' \
       util/third_party/openthread/src/lib/spinel/radio_spinel.cpp \
    && grep -Fqx '    IgnoreError(ClearSrcMatchExtEntries());' \
       util/third_party/openthread/src/lib/spinel/radio_spinel.cpp

FROM $BUILD_FROM

RUN \
    set -x \
    && printf '%s\n' \
       'Acquire::Retries "3";' \
       'Acquire::http::Timeout "60";' \
       'Acquire::https::Timeout "60";' \
       > /etc/apt/apt.conf.d/80-network-retries \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       libmbedtls12 \
       socat \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/*


COPY --from=zigbeed-builder \
     /usr/src/gecko_sdk/util/third_party/ot-br-posix /usr/src/ot-br-posix
COPY --from=otbr-source \
     /usr/src/gecko_sdk/util/third_party/openthread /usr/src/openthread
COPY --from=zigbeed-builder \
     /usr/src/gecko_sdk/protocol/openthread/platform-abstraction/posix/ /usr/src/silabs-vendor-interface
COPY --from=zigbeed-builder \
     /usr/src/gecko_sdk/protocol/openthread/platform-abstraction/posix/openthread-core-silabs-posix-config.h /usr/src/openthread/src/posix/platform/openthread-core-silabs-posix-config.h
COPY --from=zigbeed-builder \
     /usr/src/gecko_sdk/protocol/openthread /usr/src/protocol/openthread
COPY --from=zigbeed-builder \
     /usr/src/gecko_sdk/protocol/zigbee/app/projects/zigbeed/output/build/debug/zigbeed /usr/local/bin
COPY --from=cpcd-builder /usr/local/ /usr/local/

ENV BORDER_ROUTING=1
ENV BACKBONE_ROUTER=1
ENV WEB_GUI=1
ENV DOCKER=1


# Required and installed during build (script/bootstrap), could be removed

ENV OTBR_BUILD_DEPS="build-essential ninja-build cmake wget ca-certificates \
  libreadline-dev libncurses-dev libcpputest-dev libdbus-1-dev libavahi-common-dev \
  libavahi-client-dev libboost-dev libboost-filesystem-dev libboost-system-dev \
  libnetfilter-queue-dev"

# Build OTBR natively from Gecko SDK sources

WORKDIR /usr/src
RUN \
    set -x \
    && apt-get update \
    # Install npm/nodejs for WebUI manually to avoid systemd getting pulled in \
    && apt-get install -y --no-install-recommends \
       nodejs \
       npm \
       iproute2 \
       patch \
       python3 \
       python3-dev \
       python3-pip \
       python3-aiohttp \
       python3-cryptography \
       python3-yarl \
       lsb-release \
       netcat \
       sudo \
    && cd ot-br-posix \
    && ln -s ../../../openthread/ third_party/openthread/repo \
    && chmod +x ./script/* \
    && RELEASE=1 REFERENCE_DEVICE=1 BACKBONE_ROUTER=1 NAT64=1 DNS64=1 ./script/bootstrap \
    # Mimic rt_tables_install \
    && echo "88 openthread" >> /etc/iproute2/rt_tables \
    # Mimic otbr_install \
    && (./script/cmake-build \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DOTBR_FEATURE_FLAGS=ON \
        -DOTBR_DNSSD_DISCOVERY_PROXY=ON \
        -DOTBR_SRP_ADVERTISING_PROXY=ON \
        -DOTBR_INFRA_IF_NAME=eth0 \
        -DOTBR_MDNS=mDNSResponder \
        -DOTBR_VERSION= \
        -DOT_PACKAGE_VERSION= \
        -DOTBR_DBUS=OFF \
        -DOT_THREAD_VERSION=1.4 \
        -DOT_MULTIPAN_RCP=ON \
        -DCPCD_SOURCE_DIR=$CPCD_DIR \
        -DOT_POSIX_RCP_VENDOR_BUS=ON \
        -DOT_POSIX_CONFIG_RCP_VENDOR_DEPS_PACKAGE=/usr/src/protocol/openthread/platform-abstraction/posix/posix_vendor_rcp.cmake \
        -DOT_POSIX_CONFIG_RCP_VENDOR_INTERFACE=/usr/src/protocol/openthread/platform-abstraction/posix/cpc_interface.cpp \
        -DOT_CLI_VENDOR_EXTENSION=/usr/src/protocol/openthread/platform-abstraction/posix/posix_vendor_cli.cmake \
        -DOT_PLATFORM_CONFIG="openthread-core-silabs-posix-config.h" \
        -DOT_LINK_RAW=1 \
        -DOTBR_VENDOR_NAME="OpenThread" \
        -DOTBR_PRODUCT_NAME="Silicon Labs Multiprotocol" \
        -DOTBR_WEB=ON \
        -DOTBR_BORDER_ROUTING=ON \
        -DOTBR_REST=ON \
        -DOTBR_BACKBONE_ROUTER=ON \
        -DOTBR_DUA_ROUTING=ON \
        && cd build/otbr/ \
        && ninja \
        && ninja install) \
    && apt-get purge -y --auto-remove \
       build-essential \
       patch \
       python3-pip \
       python3-dev \
       git \
       git-lfs \
       libmbedtls-dev \
       ${OTBR_BUILD_DEPS} \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/src/* \
    && ldconfig \
    && touch /accept_silabs_msla 

COPY rootfs /

ENV \
    S6_STAGE2_HOOK=/etc/s6-overlay/scripts/enable-check.sh

HEALTHCHECK --interval=10s --start-period=120s CMD [ "$(s6-svstat -u /run/service/zigbeed)" = "true" ]

# use s6-overlay as init system
WORKDIR /
ENTRYPOINT ["/init"]

# Keep source-specific metadata after expensive build layers so validating a
# new exact commit can reuse the compiled artifacts.
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
