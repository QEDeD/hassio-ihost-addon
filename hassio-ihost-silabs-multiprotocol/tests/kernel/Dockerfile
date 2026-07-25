FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

RUN \
    set -eux \
    && printf '%s\n' \
       'Acquire::Retries "3";' \
       'Acquire::http::Timeout "30";' \
       'Acquire::https::Timeout "30";' \
       > /etc/apt/apt.conf.d/80-network-bounds \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       coreutils \
       ipset \
       iptables \
       util-linux \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /addon

COPY rootfs/etc/s6-overlay/scripts/otbr-agent-common \
    rootfs/etc/s6-overlay/scripts/otbr-agent-common
COPY --chmod=0755 tests/kernel/ip6tables-lock-probe \
    /usr/local/libexec/otbr-lock-probe/ip6tables
COPY tests/test-otbr-firewall-kernel.sh \
    tests/test-otbr-firewall-kernel.sh

ENTRYPOINT ["/bin/bash", "/addon/tests/test-otbr-firewall-kernel.sh"]
