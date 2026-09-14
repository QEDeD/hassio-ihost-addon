# SDK2026 Debian package inputs

Validated 2026-09-14 with fresh containers from both digest-pinned images in
`Dockerfile.sdk2026`. Package repositories are fixed at **20260914T000000Z**.
The old snapshot-looking comments in those images did not configure their live
`URIs:` fields; `pin-debian-snapshot.sh` replaces the actual fields.

## Effective sources

| Archive URL | Preserved suites | Preserved components |
| --- | --- | --- |
| https://snapshot.debian.org/archive/debian/20260914T000000Z/ | trixie, trixie-updates | main |
| https://snapshot.debian.org/archive/debian-security/20260914T000000Z/ | trixie-security | main |

Both retain `Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp`.
APT verifies InRelease signatures, index hashes and package hashes normally.
`Check-Valid-Until: no` applies only to these historical source stanzas;
global validity checking is enabled. Insecure repositories, downgrade to
insecure repositories and unauthenticated packages remain disabled.
`APT::Update::Error-Mode "any"` makes any metadata retrieval failure fatal;
there is no live mirror or alternative timestamp fallback.
The script refuses a different source-file layout or unexpected URI/keyring.

## Verification

- Pristine builder and runtime images both completed signed `apt-get update`
  successfully against all three suites. No application build was launched.
- In the pristine runtime image, `apt-get --download-only -y
  --no-install-recommends install` with the union of every explicitly declared
  builder and runtime package completed successfully: **523 package downloads,
  192 MB, 38 seconds**, exit 0. This also verifies resolution and retrieval of
  the additional transitive dependencies, without installing them.
- Requests used a 30-second HTTPS timeout and zero retries for this bounded
  availability check. The normal build uses standard APT retry behavior and
  still fails if its update fails.
- [Metadata update output](snapshot-update.log) and
  [full package selection/download output](snapshot-download.log) preserve the
  exact retrieved package versions and archive URLs.
- Shell syntax and whitespace checks passed. The image must be rebuilt to
  establish the resulting installed package manifest and run application checks.

Representative candidate versions from the validated metadata:

| Package | Version |
| --- | --- |
| cmake | 3.31.6-2 |
| ninja-build | 1.12.1-1 |
| gcc / g++ | 4:14.2.0-1 |
| libc6-dev | 2.41-12+deb13u4 |
| libmbedtls-dev | 3.6.6-0.1~deb13u1 |
| libsystemd-dev | 257.13-1~deb13u1 |
| libprotobuf-dev | 3.21.12-11+deb13u1 |
| nodejs | 20.19.2+dfsg-1+deb13u2 |
| npm | 9.2.0~ds1-3 |
| python3 | 3.13.5-1 |
| python3-aiohttp | 3.11.16-1+deb13u1 |
| python3-cryptography | 43.0.0-3+deb13u1 |
| python3-yarl | 1.19.0-1 |
| iptables | 1.8.11-2 |
| ipset | 7.22-1+b1 |

SHA-256 of the verified InRelease files:

| Suite | SHA-256 |
| --- | --- |
| trixie | `0584fba32e13e0ab8285fb16c27adea1ec03a73669c18702821094fd6ca86675` |
| trixie-updates | `f1d107982ffcfaea5cdd32041de5733099fdb43a64d9cd7bb58ba5fbe48586ed` |
| trixie-security | `b95d8fa997936c5bafdfc1ebbece792e8c35f29ee09a6c40f34a74ce8e718cf7` |

These hashes are verification evidence, not a replacement for APT's signature
verification. Existing packages inside each base are fixed by its image digest;
new dependency choices and downloads are fixed by the snapshot. This does not
claim that the two bases have identical preinstalled packages or that compiler
outputs are byte-for-byte deterministic.

## Docker package-stage correction

The initial metadata/download checks were insufficient for the builder: the
full package-union download ran in the runtime base, while the builder check
stopped after metadata update. The actual Docker builder install then failed
with exit 100 although the requested signed indices existed on disk.

The pinned builder contains `/etc/apt/apt.conf.d/80snapshot` setting
`APT::Snapshot "20260713T000000Z"`. Its built-in snapshot selection conflicted
with the new direct timestamped URIs during package lookup. A Docker diagnostic
reproduced the failure with the new package lists present and the old effective
`APT::Snapshot` value. The shared helper now sets `APT::Snapshot ""` so that
only the explicitly pinned source URIs determine package inputs. This does not
alter the snapshot timestamp, signature requirements or expiry policy.

After that single policy correction, actual Docker package stages copied from
`Dockerfile.sdk2026` both completed `apt-get update && apt-get install`:

- Builder: `local/sdk2026-apt-check:builder`, exit 0;
  [installation log](docker-builder-packages.log).
- Runtime: `local/sdk2026-apt-check:runtime`, exit 0;
  [installation log](docker-runtime-packages.log).

The retained [package-stage Dockerfile](Dockerfile.apt-packages-check) ends after
APT installation and excludes all application compilation.
[Failure diagnostics](docker-apt-diagnostic.log) and
[corrected lookup diagnostics](docker-apt-fixed.log) record the before/after
configuration and result. No signing checks were relaxed and no full host
application build was run during this correction.
