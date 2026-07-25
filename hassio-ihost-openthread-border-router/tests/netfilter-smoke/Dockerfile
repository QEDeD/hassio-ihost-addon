FROM debian:bookworm-slim@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN printf '%s\n' \
        'Acquire::Retries "3";' \
        'Acquire::Connect::Timeout "30";' \
        'Acquire::http::Timeout "30";' \
        'Acquire::https::Timeout "30";' \
        > /etc/apt/apt.conf.d/80-otbr-smoke \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ipset \
        iptables \
        util-linux \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs/etc/s6-overlay/scripts/otbr-agent-common \
    /usr/local/lib/otbr-agent-common
COPY --chmod=0755 tests/netfilter-smoke/iptables-lock-probe \
    /usr/local/libexec/otbr-lock-probe/iptables
COPY --chmod=0755 tests/test-netfilter-kernel.sh \
    /usr/local/bin/test-netfilter-kernel

ENTRYPOINT ["/usr/local/bin/test-netfilter-kernel"]
