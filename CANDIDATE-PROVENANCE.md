# Candidate provenance and publication record

This record belongs only to the fork branch
`codex/otbr-candidate-feed`. Phase 1 is local-only. No branch, image, package,
visibility, pull request, upstream comment, or Home Assistant state is changed
until the separately listed external writes are explicitly approved.

## Source identity

| Item | Recorded value |
| --- | --- |
| Canonical source commit | `186eac8354fdcab9c224ec840989da1fd86af882` |
| Canonical root tree | `6742dfa230fc4724897c6196643da5261a919391` |
| Canonical Silicon subtree | `ab9d32ddf7d7cdeda9ba97cd7ae4be2dbbeb8b8e` |
| Candidate content commit | `e86f3b32105a0f7eaf669672d0938ed8e9fb4b16` |
| Candidate content tree | `0d377877ff329db1a4788aacc40c636116d694ba` |
| Candidate branch | `codex/otbr-candidate-feed` |
| Candidate version/tag | `1.0.2` |
| Candidate architecture | `amd64` only |
| Fork | `QEDeD/hassio-ihost-addon` |
| Upstream source | `iHost-Open-Source-Project/hassio-ihost-addon` |

The candidate content commit is recorded by a second local commit because a
Git commit cannot contain its own object ID. The eventual published branch SHA
is verified separately after both local commits are pushed.

## Validated local image

The image below was built and validated before this delivery branch was
created. Phase 2 must retag this exact cached image and must not rebuild it
merely to change its registry name.

| Item | Recorded value |
| --- | --- |
| Local reference | `local/silabs-otbr:186eac8354fdcab9c224ec840989da1fd86af882-amd64` |
| Local Docker image ID / OCI descriptor digest | `sha256:5a10cd6e03a4f398722b111278a6a24faa9af2261a1759b43c7784a7a31ee55a` |
| Image configuration digest | `sha256:ee8a97319ca2616afc84a28dd30d5d984308fb3d0961027930586ec69ad559d3` |
| Platform | `linux/amd64` |
| Image size | `198645943` bytes |
| Local image creation time | `2026-07-26T13:41:35.743365719Z` |

Verified labels:

```text
io.hass.arch=amd64
io.hass.base.arch=amd64
io.hass.base.image=debian:bullseye-slim
io.hass.base.name=debian
io.hass.base.version=2025.06.1
io.hass.type=app
io.hass.version=1.0.2
org.opencontainers.image.created=2025-06-12 13:13:45+00:00
org.opencontainers.image.revision=186eac8354fdcab9c224ec840989da1fd86af882
org.opencontainers.image.source=https://github.com/iHost-Open-Source-Project/hassio-ihost-addon
org.opencontainers.image.version=1.0.2
```

## Candidate registry record

| Item | Recorded value |
| --- | --- |
| Exact package/tag | `ghcr.io/qeded/ihost-silabs-otbr-candidate-186eac8354fdcab9c224ec840989da1fd86af882-amd64:1.0.2` |
| Target package URL | `https://github.com/users/QEDeD/packages/container/package/ihost-silabs-otbr-candidate-186eac8354fdcab9c224ec840989da1fd86af882-amd64` |
| Publication | `PENDING EXPLICIT APPROVAL` |
| Package visibility | `PENDING EXPLICIT APPROVAL` |
| Registry manifest/platform digest | `PENDING PUBLICATION` |
| Registry image configuration digest | `PENDING REMOTE VERIFICATION` |
| Anonymous pull verification | `PENDING PUBLICATION` |
| Published branch SHA | `PENDING BRANCH PUSH` |

The SHA-bearing tag is procedurally immutable, not cryptographically pinned by
the add-on metadata. Supervisor derives the tag from `version: 1.0.2`.
Publication therefore occurs exactly once: never overwrite or reuse the
package/tag, and record the resulting remote manifest digest.

## Delivery-only differences

The branch:

- exposes only `hassio-ihost-silabs-multiprotocol`;
- marks the entry TEST/EXPERIMENTAL and AMD64-only;
- selects the unique candidate image name while retaining version `1.0.2`;
- changes repository/add-on presentation metadata and documentation; and
- removes unrelated add-on directories from the candidate feed.

Runtime and build inputs retained from the canonical source are byte-identical.
Reference Git object IDs:

| Canonical path | Git object ID |
| --- | --- |
| `Dockerfile` | `7f6724c99844de50d5e6cf7464ce7a6f992b6c4b` |
| `build.yaml` | `43ca9cdda279595f040f8a5f631c85c2af64e9cf` |
| `rootfs/` | `b4cac75fd31800771eedf2b56277f5d2d3516183` |
| `openthread-patches/` | `fef0e6952c625862ca04cd426d88e3fd4883cdb2` |
| `otbr-patches/` | `5574917f28b5add1c846f16ff22a1c1715a04726` |
| `zigbeed-patches/` | `db38535ac778052b60fd4f229500e0b103f1d3dd` |
| `tests/` | `6449a7d1175b2321684832e70070f929020c306e` |

## Intended Home Assistant environment

The local workspace establishes only the intended class
**Home Assistant OS 18 or newer, AMD64 host, representative EFR32MG21
Multi-PAN radio**. It does not contain the current device facts below, and this
candidate has not contacted the Home Assistant instance.

Record these privately before installation. Do not commit secrets or complete
option values that contain credentials.

| Required fact | Intended/recorded value |
| --- | --- |
| Home Assistant OS version | `REQUIRED — not recorded locally` |
| Supervisor version | `REQUIRED — not recorded locally` |
| Home Assistant Core version | `REQUIRED — not recorded locally` |
| Host/container architecture | `amd64 required; actual value REQUIRED` |
| Hardware/machine | `REQUIRED — not recorded locally` |
| MG21 model and firmware build | `REQUIRED — Multi-PAN expected` |
| MG21 connection | `REQUIRED — device path or network endpoint` |
| Baud rate and flow control | `REQUIRED — copy from original options` |
| Backbone/network interface | `REQUIRED — record explicit or Supervisor-selected interface` |
| Original add-on ID, version, repository, and boot setting | `REQUIRED` |
| Complete original add-on options | `REQUIRED — store privately` |
| Zigbee consumer and endpoint | `REQUIRED — ZHA/Zigbee2MQTT/other` |
| Thread/OTBR consumers and dataset status | `REQUIRED` |
| Other radio or OTBR owners | `REQUIRED` |
| Current backup ID/time and restore verification | `REQUIRED` |
| Maximum acceptable downtime | `REQUIRED` |
| Rollback trigger and recovery access | `REQUIRED` |

For comparison only, issue #83 reported HAOS `18.0`, Core `2026.6.4`,
Supervisor `2026.06.2`, Raspberry Pi 4/aarch64, and an MG24 USB radio with
Multi-PAN RCP firmware. This AMD64/MG21 candidate is a representative
cross-environment test of the same failing configuration path, not a
reproduction on the reporter's exact hardware.

## Rollback gate

Hardware testing is blocked until all of these are true:

- a current backup exists and its identifier/time are recorded;
- the original add-on remains installed with its data intact;
- its complete options and consumer endpoints are recorded privately;
- candidate and original add-on IDs/hostnames are distinguishable;
- all possible radio and OTBR owners are identified;
- a local console or other recovery path is available;
- the maximum acceptable downtime and rollback trigger are agreed; and
- the quick rollback section in `HARDWARE-TEST-RUNBOOK.md` has been reviewed.

## Validation scope

Results from this candidate validate broad canonical head
`186eac8354fdcab9c224ec840989da1fd86af882` and its recorded tree. They do not
validate any later, scope-specific, rebased, amended, or otherwise different
upstream head.
