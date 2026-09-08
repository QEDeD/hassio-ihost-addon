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
- A bounded detached-radio trial on HAOS 18.2 passes CPC/OTBR startup,
  permissive firewall setup, cleanup and restoration of the original services.

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

## Isolated test on the production HAOS kernel

A subsequent authorized test on 2026-09-08 passed the same kernel suite on
Home Assistant OS 18.2, kernel `6.18.39-haos`, with the released image's
`ip6tables v1.8.7 (nf_tables)`. The logged helper SHA-256 was
`aa383a42a12d414a57d6c927c9fc99a004841d3eb6279dce302e5791e513125b`,
matching the focused source.

The temporary local app was built from the same digest-pinned released image,
with only the helper, kernel test, lock probe and a bounded test entrypoint.
It did not start the image's normal radio services. Its manifest used:

```yaml
startup: once
boot: manual_only
init: false
host_network: false
host_ipc: false
host_pid: false
host_uts: false
host_dbus: false
hassio_api: false
homeassistant_api: false
docker_api: false
full_access: false
apparmor: true
privileged: [NET_ADMIN, NET_RAW]
```

There were no device, radio or shared-data mappings. Supervisor reported the
installed app stopped, protected, manual-only and with all host namespaces
and API access disabled before it was started. The wrapper refused interfaces
other than `lo` and `eth0`, printed the namespace/kernel/source identity, and
bounded the test with `timeout --kill-after=3s 45s`. The manifest is the namespace
isolation boundary; the interface check is only additional protection.

The log ended with `PASS: real-kernel OTBR firewall lifecycle`, and the app
exited normally to the stopped state. It was uninstalled, its six generated
staging files were removed, and the local store was reloaded. Both original
radio apps were still reported started afterward, with the original
multiprotocol options unchanged and OTBR disabled. This does not constitute
a device-level Zigbee availability test.

This closes the HAOS-kernel compatibility gap for the firewall helper in a
private container network namespace. It does not exercise host-network radio
startup, CPC, the real `wpan0` interface or Supervisor lifecycle of the OTBR
service.

## Bounded detached-radio trial on HAOS 18.2

A subsequent authorized host-network trial on 2026-09-08 exercised the real
USB radio using the same released AMD64 image and five unchanged focused files.
The operator had created a Proxmox VM snapshot before the trial. That snapshot
was a recovery aid, not a rollback of physical radio or mesh state.

The temporary manual-only app had separate private storage. A guarded importer
copied only the existing Thread settings file and `zigbeed/host_token.nvm` from
a native Supervisor backup, preserving the original app's options and storage.
It verified source/readback hashes, exact paths, types, sizes and modes; refused
unknown or changed destination state; and allowed one trial start. Its 23 local
fixture tests passed under the released image's Python 3.9.2. An import-only
rehearsal on HA completed without launching the radio services. The actual trial
used a new backup created after Zigbee2MQTT and the original Multiprotocol app
were stopped, followed by an ownership/network preflight.

Test-only changes bounded the scope: a binary wrapper forced
`--auto-attach=0`, REST used port 18081, and Supervisor REST discovery was
suppressed. Zigbee2MQTT stayed stopped and never connected to the candidate.
The complete temporary s6 graph compiled; the wrapper's arguments and readiness
metadata were checked with a local stub. A four-minute s6 stop timer provided a
backstop; the normal controller stopped the candidate earlier, so timer expiry
was not exercised during the live trial. These harness changes are not part of
the proposed runtime fix.

Observed results, UTC:

- 18:38:07: handover began; both original consumers were stopped before backup.
- 18:38:21: candidate REST became ready, 14.4 seconds after handover. CPC reported
  successful startup; zigbeed and its TCP 9999 endpoint also became available.
- Eleven checks over approximately one minute kept Thread state `disabled`,
  candidate state started and both original consumers stopped. The log confirmed
  the permissive scoped-forwarding path with `otbr_firewall: false`.
- 18:39:29: the stopped-candidate audit found no `wpan0`, owned chains/ipsets or
  candidate listeners. IPv4 and IPv6 FORWARD policies were still `DROP`, matching
  the pre-trial baseline. OTBR exited with code zero. mDNS registration warnings
  occurred during service shutdown after mDNS began stopping; cleanup still
  satisfied the acceptance checks.
- 18:39:43: the original radio endpoint was ready. By 18:39:54, a fresh
  timestamped Zigbee2MQTT startup and both original app states were verified.
  Total handover-to-restoration time was 107.1 seconds. Original options,
  versions, boot/watchdog settings, protection and update settings were unchanged.

The temporary app was uninstalled, its known staging/control files removed, and
the local catalog reloaded. Absence was checked; both original services remained
started afterward. The quiesced backup was retained privately for recovery.
Private logs, state manifests and device identifiers were not added to this
repository. No trial data was copied back into the original installation.

### Filtering-enabled follow-up

A second bounded detached trial on 2026-09-08 used the same runtime and guards,
with only the candidate option changed to `otbr_firewall: true`. The original
services were stopped before a new backup; its imported Zigbee state differed
from the earlier backup and source/readback verification passed.

Handover began at 19:07:39 UTC. Candidate readiness followed in 14.6 seconds;
the log confirmed `Setting up OTBR ingress filtering.`, CPC startup and the
Zigbee TCP endpoint. Eleven observations over approximately one minute kept
Thread disabled and the original consumers stopped. The post-stop audit at
19:09:03 found no candidate interface, listeners, owned chains or ipsets; both
host FORWARD policies remained `DROP`. Fresh original radio and Zigbee2MQTT
readiness was verified by 19:09:27, 107.7 seconds after handover. Settings were
unchanged. The temporary app and its staging/control files were removed;
both original apps remained started and the recovery backup was retained.

This adds real-radio startup/cleanup evidence for filtering enabled; it does
not add packet-filter behavior under Thread traffic or mesh/coexistence evidence.

## Limits and next gate

The evidence now covers the focused firewall lifecycle on WSL2 and HAOS 18.2,
the released AMD64 userspace, and detached CPC/OTBR startup with the real radio
and host network. It does not establish Thread mesh attachment, commissioning,
Zigbee/Thread coexistence under traffic, long-term reliability or ARM behavior.
Zigbee2MQTT recovery is established by fresh service readiness, not an end-to-end
physical-device actuation test. The temporary wrapper also means this is not an
unmodified default-auto-attach startup test.

This is not a fresh build of all add-on binaries. The baseline Dockerfile
requires an untracked `slc_cli_linux.zip`; no broad build changes were folded
into this fix. The supported operating constraint remains one OTBR at a time;
the cleanup marker is a lifecycle marker, not a cross-add-on exclusion lock.

Both detached-startup configuration gates are complete. A real-network trial
remains a separate gate: traffic can advance security counters accepted by
other devices, and reverting to an older private-state copy can leave resumed
counters behind those peers. A VM snapshot cannot rewind peer state; see the
[Silicon Labs migration guidance](https://docs.silabs.com/zigbee/8.1.3/multiprotocol-solution-linux/host-ncp-rcp-migration).

The existing temporary app has a different Supervisor identity and private
storage from the original app. Before a mesh/coexistence trial, establish a
verified route that preserves current state across code changes, or obtain
specific operator approval for the remaining recovery risk. The completed
service-restoration checks do not establish end-to-end peer counter acceptance.
