# Focused HAOS 18 compatibility validation

Validated on 2026-09-08 against source commit
`9de61ea035588e65de3aca803ba1e060284672fa`.

## Results

- Mock lifecycle suite, individual Bash syntax checks and runtime ShellCheck pass.
- The isolated kernel suite passes on Docker Desktop 29.7.2,
  Linux `6.18.33.2-microsoft-standard-WSL2`, using Debian Bookworm's
  `ip6tables v1.8.9 (nf_tables)`.
- The same kernel suite passes with the released iHost 1.0.2 AMD64 image's
  `ip6tables v1.8.7 (nf_tables)` and GNU coreutils 8.32.
- A local image containing only the five focused service files over that release
  passes individual Bash syntax checks and complete s6 service-graph compilation.
  SHA-256 hashes of all five installed files match the focused source.

The kernel suite covers filtering and permissive forwarding, retained foreign
rules/ipsets and FORWARD policy, duplicate cleanup, externally referenced state,
and bounded lock contention. Every kernel test used a private container network
namespace with no host networking or radio access; see [README.md](README.md).

## Released-runtime reproduction

Released image, pinned independently of its mutable version tag:

```text
ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef
```

To repeat the kernel suite using the released tools, use the restricted
`docker run` options in README, override the entrypoint with `/bin/bash`, mount
this add-on directory read-only at `/addon`, and mount
`tests/kernel/ip6tables-lock-probe` read-only at
`/usr/local/libexec/otbr-lock-probe/ip6tables`. Pass the pinned image above and
`/addon/tests/test-otbr-firewall-kernel.sh`.

For the service-file check, build this temporary Dockerfile with the add-on
folder as its context:

```dockerfile
FROM ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef
COPY --chmod=0755 rootfs/etc/s6-overlay/scripts/otbr-agent-common rootfs/etc/s6-overlay/scripts/otbr-enable-check.sh /etc/s6-overlay/scripts/
COPY --chmod=0755 rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish /etc/s6-overlay/s6-rc.d/otbr-agent/
COPY rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish /etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish
```

With the image entrypoint overridden and a writable `/tmp` tmpfs, the compile
command is:

```sh
s6-rc-compile /tmp/otbr-s6-db \
  /package/admin/s6-overlay-3.1.6.2/etc/s6-rc/sources \
  /etc/s6-overlay/s6-rc.d
```

Both source directories are required: omitting the built-in services produces
an undefined `legacy-cont-init` dependency, not an add-on regression.

The local validation image is `local/ihost-otbr-focused:9de61ea`, image ID
`sha256:c6fe65868ed6cc9dc74ef861ec1db7bb0939829e28b78370db86d36eb14fbf14`.
It has not been published or deployed.

## Limits and remaining gate

This validates the focused scripts against real nft kernel operations and the
released AMD64 userspace. It is not a fresh build of all add-on binaries, a test
on the HAOS 18 kernel, an ARM result, or evidence of successful radio/Thread
startup. The baseline source Dockerfile requires an untracked
`slc_cli_linux.zip`; no broad build changes were folded into this fix.

The supported operating constraint remains one OTBR implementation at a time.
The cleanup marker is a lifecycle marker, not a cross-add-on exclusion lock.
Production radio testing needs its own bounded rollback plan and must respect
the operator's current authorization. No production state changed in this
validation cycle.