FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef AS build
ENV DOCKER=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    git patch build-essential ninja-build cmake pkg-config ca-certificates \
    libreadline-dev libncurses-dev libcpputest-dev libdbus-1-dev libavahi-common-dev \
    libavahi-client-dev libboost-dev libboost-filesystem-dev libboost-system-dev \
    libnetfilter-queue-dev nodejs npm python3 python3-dev python3-pip \
    python3-aiohttp python3-cryptography python3-yarl lsb-release netcat sudo
COPY otbr-patches/ /probe-patches/
COPY tests/nat64-probe/build.sh /probe-build.sh
RUN bash /probe-build.sh

# Test the rebuilt binaries against the unchanged released runtime libraries.
# No application service is started and no replacement is installed in /usr.
FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef
COPY --from=build /probe /probe
COPY tests/nat64-probe/check.sh /probe/check.sh
HEALTHCHECK NONE
ENTRYPOINT ["/bin/bash", "/probe/check.sh"]
