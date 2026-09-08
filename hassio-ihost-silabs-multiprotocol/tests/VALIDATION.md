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

## Approved live-network trial

After explicit operator approval of the state/counter recovery risk, a bounded
trial on 2026-09-08 used the same released binaries and focused files with
`otbr_firewall: false`. The temporary wrapper initially kept Thread disabled.
The controller compared all parsed active-dataset TLVs against Home Assistant's
preferred dataset before using the pinned REST API's `PUT /node/state` with
`"enable"`. No dataset was commissioned or overwritten, and no radio firmware
was changed. The original Z2M endpoint and configuration remained unchanged.

Device acceptance used Zigbee2MQTT 2.14.1's correlated
`bridge/request/device/reporting/read` request for `genOnOff.onOff`, with a fresh
transaction ID and a successful physical ZCL response required. This reads
reporting configuration; it does not change device attributes or bindings.
An Aqara SP-EUC01 and IKEA LED2201G8 passed baseline probes and were selected.
A different plug failed its baseline probe and was excluded. See the
[versioned handler](https://github.com/Koenkk/zigbee2mqtt/blob/2.14.1/lib/extension/bridge.ts#L508-L544).

An initial attempt stopped before candidate radio startup because of an operator
logging argument collision after backup creation. Both original services and
device probes recovered in 35 seconds. The collision was fixed and covered by
a local regression check; seven mocked controller/recovery checks passed before
the successful retry. The trial runtime source was unchanged.

Observed results for the retry, UTC:

- 19:30:35: handover began; a fresh original-app backup was taken while stopped.
- 19:30:50: the candidate dataset matched the preferred dataset, then Thread was
  enabled. It reached leader role at 19:31:25.
- Both selected Zigbee devices returned successful physical responses at
  19:31:41 and again at 19:32:32 while Thread remained active. Eight role/service
  checks over approximately 45 seconds passed.
- Two active Thread diagnostic requests returned only the candidate's own
  response, with one router reported. Its outgoing MAC broadcast counter rose
  from 70 to 82; incoming packet counters and reported errors remained zero.
  This is concurrent Thread broadcast activity and Zigbee request/response
  evidence, not a remote Thread-peer exchange.
- After stopping Zigbee2MQTT, disabling Thread and stopping the candidate, a
  native backup retained the candidate's post-test state and local image.
  Both Thread and Zigbee file hashes differed from the pre-test backup; their
  retained contents and sizes were verified without publishing keys or IDs.
- At 19:32:51, cleanup showed no candidate interface, listeners, chains or ipsets.
  Both host FORWARD policies remained `DROP`.
- The first selected-device read after restoring the original app failed with
  a delivery error. One planned original-radio/Z2M restart followed. Both device
  reads passed at 19:33:50, with unchanged original settings. Handover through
  verified recovery took 196.6 seconds. Both reads passed again at 19:37:30.

The delivery failure was not isolated to a specific cause. It must not be
reported as proof of a counter regression, nor should recovery of two devices
be represented as proof of counter-safe rollback for every peer. The temporary
app, staging/control files and MQTT test credentials were removed after the
follow-up checks. The post-test state/image backup remains available privately;
its newer Thread state was not copied into the original installation.

## Limits and next gate

Evidence now covers both detached firewall configurations, Thread activation
with the existing dataset, and physical Zigbee reads during concurrent Thread
broadcast activity on the released AMD64 runtime and real HAOS 18.2 radio.
Remote Thread-peer communication remains unverified. Default automatic attach,
commissioning, application traffic to a Thread device, filtering behavior under
Thread unicast load, long-term reliability and ARM behavior remain outside the
evidence. No physical device actuation was used as a test.

This is not a fresh build of all add-on binaries. The baseline Dockerfile
requires an untracked `slc_cli_linux.zip`; no broad build changes were folded
into this fix. The supported operating constraint remains one OTBR at a time;
the cleanup marker is a lifecycle marker, not a cross-add-on exclusion lock.

The next meaningful functional gate requires a known reachable Thread peer on
the intended dataset. Plan state continuity before another activation: the
original app retains older Thread settings while the post-trial backup contains
newer state. Do not assume a VM rollback rewinds other devices' accepted security
counters; see the [Silicon Labs migration guidance](https://docs.silabs.com/zigbee/8.1.3/multiprotocol-solution-linux/host-ncp-rcp-migration).
A future test must use an appropriate current-state/recovery route and remain
within the operator's applicable authorization.
