FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef AS build
ENV DOCKER=1
# Retry transient snapshot gateway failures within the existing bounded CI job.
RUN printf 'Acquire::Retries "3";\n' > /etc/apt/apt.conf.d/80-probe-retries
# Freeze the build-only Bullseye package inputs at the final LTS day. The live
# mirrors no longer serve some indexed security packages. Keep signature/hash
# checks; only snapshot metadata expiry is disabled for these immutable URLs.
# The release has no CA bundle. Signed APT metadata authenticates this initial
# HTTP bootstrap; ca-certificates is installed before later HTTPS source access.
RUN rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources \
    && printf '%s\n' \
      'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260831T235959Z/ bullseye main' \
      'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20260831T235959Z/ bullseye-security main' \
      > /etc/apt/sources.list
RUN apt-get update -o APT::Update::Error-Mode=any && apt-get install -y --no-install-recommends \
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
