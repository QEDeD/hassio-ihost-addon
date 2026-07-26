# Silicon Labs Multiprotocol release procedure

The repository workflow validates release images but deliberately has read-only
permissions and does not publish to GHCR. Publishing must therefore use the
maintainers' trusted release environment. Never publish credentials or images
from a pull request raised by a fork.

Before automating publication, an iHost organization administrator must confirm
that this repository has **Manage Actions access** to each existing GHCR
package and protect the release environment. Do not add `packages: write` to a
workflow until those permissions and the package owner are verified.

## Validate the implementation source

Keep `config.yaml` on the currently published version while the implementation
pull request is reviewed. The changelog may contain the upcoming release
section, but advertising the new version is a separate, final release pull
request.

1. Confirm the implementation tree is clean:

   ```bash
   test -z "$(git status --porcelain)"
   ```

2. Open or update the pull request and require all of these jobs to pass:

   - `Actionlint`
   - `Lifecycle regression tests`
   - `Add-on configuration`
   - `Build armv7 image`
   - `Build aarch64 image`
   - `Build amd64 image`

3. Merge the implementation without changing `config.yaml`'s version. Record
   the resulting commit as `SOURCE_SHA`, then require the `master` push jobs at
   that exact SHA to pass:

   ```bash
   SOURCE_SHA="$(git rev-parse HEAD)"
   test -n "${SOURCE_SHA}"
   ```

4. Keep the full build logs with the release record. In particular, record the
   resolved base-image digests and verify that the downloaded SLC CLI matches
   `args.SLC_CLI_SHA256` in `build.yaml`. Also verify that the embedded
   OpenThread recovery patch matches `args.OPENTHREAD_RECOVERY_PATCH_SHA256`
   and applies cleanly to the configured Simplicity SDK revision.

## Build the release candidate

From a clean detached checkout of `SOURCE_SHA`, build the next version with
`BUILD_COMMIT=${SOURCE_SHA}` and `BUILD_VERSION=<next-version>`. First publish
immutable candidate tags such as `sha-${SOURCE_SHA}` for all three
architectures. Do not update `config.yaml` yet.

If a resolved base-image digest differs from the exact-SHA CI evidence, rerun
the image gates before hardware acceptance.

## Hardware acceptance

Test the exact candidate image digests on HAOS 18 or newer with a supported
radio. Record `SOURCE_SHA`, every candidate digest, the host, architecture,
radio firmware, link type, and option values.

- Reproduce the reported HAOS 18 path first: MG24-class radio,
  `otbr_enable: true`, `otbr_firewall: false`, `baudrate: 115200`, and
  `flow_control: false`. Require OTBR REST/discovery and Zigbee to remain
  available without a legacy-iptables error or restart loop.
- Exercise start, add-on restart, stop, and full host reboot with
  `otbr_firewall` both enabled and disabled.
- Disable and re-enable OTBR, confirming that Zigbee remains available and no
  stale OTBR chains, jumps, or ipsets accumulate.
- Confirm the host IPv4 and IPv6 `FORWARD` policies are unchanged.
- Exercise both a local serial radio and a TCP `network_device` when available;
  no dummy serial device should be needed for the network case.
- On a multi-interface host, verify the configured or Supervisor-selected
  backbone interface and compare `ip -6 route` before start, after start, after
  restart, and after stop.
- Run concurrent Zigbee and Thread traffic for at least 24 hours. Record CPC
  endpoint state, file-descriptor counts, and recovery after an RCP reset or
  link interruption.
- Trigger RCP recovery while Zigbee and Thread sleepy end devices are active.
  Require source-match restoration to complete without table-capacity errors
  and confirm that all devices remain reachable afterward.

The Home Assistant upstream add-on deprecated shared-radio multiprotocol
operation, so hardware acceptance is a release requirement for this downstream
fork, not an optional smoke test.

## Promote and expose the version

1. Promote the already tested candidate digests, without rebuilding, to the
   same release version for all configured architectures:

   - `ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-armv7`
   - `ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-aarch64`
   - `ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64`

2. Record each immutable image digest and its source commit in the release
   record. Verify the remote tags by digest, not only by tag name. Inspect the
   image labels and any provenance attestation: the iHost package name, release
   version, and source revision must match the recorded candidate. Reject an
   empty source revision, a subject pointing at another namespace/version, or
   inherited base-image version metadata.
3. Verify every release tag resolves to its tested candidate digest. Then open
   a metadata-only pull request that changes `config.yaml` to that version.
   Record its merged commit as `RELEASE_SHA`; it is intentionally distinct from
   `SOURCE_SHA`.
4. After merge, confirm a fresh repository reload offers the version and repeat
   one start/stop smoke test using the published image.

If candidate verification fails, leave repository metadata on the previous
version. Never overwrite a published version tag: after publication, correct a
bad release with a new patch version.
