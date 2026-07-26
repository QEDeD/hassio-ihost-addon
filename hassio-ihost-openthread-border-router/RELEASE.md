# OpenThread Border Router release procedure

The implementation described here targets **2.14.0**. Keep `config.yaml` at
the published 2.13.0 version until an exact-source candidate passes CI and
hardware acceptance; promote the add-on metadata in the final release pull
request.

The repository workflow validates the armv7 release image but deliberately has
read-only permissions and does not publish to GHCR. Publishing must therefore
use the maintainers' trusted release environment. Never publish credentials or
images from a pull request raised by a fork.

Before automating publication, an iHost organization administrator must confirm
that this repository has **Manage Actions access** to the existing GHCR package
and protect the release environment. Do not add `packages: write` to a workflow
until those permissions and the package owner are verified.

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

3. Merge the implementation without changing `config.yaml`'s version. Record
   the resulting commit as `SOURCE_SHA`, then require the `master` push jobs at
   that exact SHA to pass:

   ```bash
   SOURCE_SHA="$(git rev-parse HEAD)"
   test -n "${SOURCE_SHA}"
   ```

4. Keep the full build logs with the release record. Record the resolved base
   image and final image digests and confirm that both OpenThread backport
   patches were applied during the image build.

## Build the release candidate

From a clean detached checkout of `SOURCE_SHA`, build the next version with
`BUILD_COMMIT=${SOURCE_SHA}` and `BUILD_VERSION=<next-version>`. First publish
an immutable candidate tag such as `sha-${SOURCE_SHA}`. Do not update
`config.yaml` yet.

If the resolved base-image digest differs from the exact-SHA CI evidence, rerun
the image gate before hardware acceptance.

## Hardware acceptance

Test the exact candidate image digest on HAOS 18 or newer with a supported armv7
host and radio. Record `SOURCE_SHA`, the candidate digest, HAOS/Supervisor
versions, radio and firmware, link type, backbone interface, and all add-on
options.

- Exercise start, add-on restart, stop, and full host reboot for every
  `firewall`/`nat64` combination. Confirm no owned rules, chains, marks, or
  ipsets accumulate and that the host IPv4 and IPv6 `FORWARD` policies remain
  unchanged.
- With NAT64 enabled, test real Thread traffic through DNS64 to an IPv4-only
  destination and its return path. Rule inspection alone is insufficient.
- Compare `ip -6 route` before start, after start, after restart, and after stop,
  especially on ULA/VLAN and multi-interface hosts.
- Exercise an explicit `backbone_interface` and Supervisor primary-interface
  discovery. A missing interface must fail clearly and must not fall back to
  `eth0`.
- Exercise local serial and TCP `network_device` configurations. The network
  case must not require a dummy serial device and must skip firmware flashing.
- Validate flow-control guidance on each supported radio/firmware combination.
- Force an RCP reset or stall and confirm the source-match-table recovery patch
  restores service without losing the Thread dataset.
- Confirm the OTBR web UI and REST API become ready after configuration on
  repeated restarts.

Also run a bounded TCP-RCP outage/restore test and a 24-hour soak while recording
restart counts and file-descriptor usage. Reconnect/backoff design changes are a
separate follow-up if transient outages exhaust Supervisor's restart limit.

## Promote and expose the version

1. Promote the already tested candidate digest, without rebuilding, to
   `ghcr.io/ihost-open-source-project/openthread-border-router:<version>`.
2. Record the immutable image digest and source commit. Verify the remote tag by
   digest, not only by tag name. Inspect the image labels and any provenance
   attestation: the iHost package name, release version, and source revision
   must match the recorded candidate. Reject an empty source revision, a
   subject pointing at another namespace/version, or inherited base-image
   version metadata.
3. Verify the release tag resolves to the tested candidate digest. Then open a
   metadata-only pull request that changes `config.yaml` to that version.
   Record its merged commit as `RELEASE_SHA`; it is intentionally distinct from
   `SOURCE_SHA`.
4. After merge, confirm a fresh repository reload offers the version and repeat
   one start/stop/NAT64 smoke test using the published image.

If candidate verification fails, leave repository metadata on the previous
version. Never overwrite a published version tag: after publication, correct a
bad release with a new patch version.
