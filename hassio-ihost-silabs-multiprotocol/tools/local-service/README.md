# Persistent local OTBR preparation

**Preparation artifact, not an approved deployment.** This directory preserves the
activation/recovery proposal and its small local package builder. It does not
change the released add-on or automatically create a local store entry. Generated
contexts belong outside this repository. No credentials, datasets, native backup
archives, deployment manifests, addresses or live observations belong in Git.

See [activation and recovery](ACTIVATION.md) for the maintained proposal, exact
Supervisor contracts and remaining gates. Runtime fix remains the five files
from `9de61ea035588e65de3aca803ba1e060284672fa`; historical results remain in
[VALIDATION.md](../../tests/VALIDATION.md).

## Local use

Run under Linux/WSL; Python standard library only:

```sh
python3 -m unittest discover -s hassio-ihost-silabs-multiprotocol/tools/local-service -v
python3 hassio-ihost-silabs-multiprotocol/tools/local-service/make_context.py /tmp/otbr-fixed-new
python3 hassio-ihost-silabs-multiprotocol/tools/local-service/make_context.py /tmp/otbr-recovery-new --recovery
```

The generator refuses an existing destination or changed runtime source hashes.
It creates manifests and Dockerfiles, not an installation. The fixed context
uses a digest-pinned released image plus the five unchanged runtime files. The
recovery context uses the same released binaries without that overlay, a distinct
package version and an enforced OTBR-off gate. Both retain the same proposed
local app slug. Private deployment options must be supplied separately. No normal
entrypoint runs during generation or unit tests.

The app defaults to `local_service_mode: prepare`, OTBR off, manual boot,
observations off and no configured radio. Its entrypoint performs an import only
when supplied a valid private manifest; it never falls through into radio startup.
Changing to `run` requires explicit operator action after import validation.
First run requires exact boolean `otbr_enable: false`. The recovery variant
requires that value on every invocation. A marker is durably written before
`/init` is called: attempted handoff makes the current volume authoritative,
including if initialization later fails. Subsequent starts never re-import.

## Private import manifest

The deployment operator supplies `/share/otbr-local-seed.json` through the
read-only share mount. It is not a user-editable radio dataset. Shape:

```json
{
  "version": 1,
  "expires_at": 0,
  "sources": {
    "thread": {
      "backup_slug": "11111111",
      "app_slug": "local_codex_otbr_radio_trial_9de61ea",
      "size": 1,
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    },
    "zigbee": {
      "backup_slug": "22222222",
      "app_slug": "81bc2df9_hassio_ihost_silabs_multiprotocol",
      "size": 1,
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  }
}
```

These dummy values deliberately cannot authorize an import. Real fingerprints
must be obtained privately from the exact selected members, and expiry must be
within the next fifteen minutes. Stopped-state capture and absence of subsequent
radio use are operator preconditions, not something an archive hash proves.

The importer selects newer retained Thread state and fresh stopped-original
Zigbee state independently. It never imports another app's options or image. It
reads through the complete archives, including members after the desired files,
to reject late duplicates and invalid gzip/tar endings. Image bytes are streamed
and discarded, not extracted or buffered in memory. It refuses links, sparse or
extension headers, unsafe paths, unexpected destination state, and selected-file
fingerprint mismatches. Maximum outer/decompressed archive work is 512 MiB per
source, fewer than 256 headers, selected files at most 1 MiB. Unsupported future
backup formats fail closed; these bounds are not promises of general backup
format support.

A durable pending marker precedes all state writes. Interrupted imports refuse
both another import and radio startup. Do not repair that marker automatically:
recover the unstarted installation deliberately. Files/directories use0600/0700.
After first handoff, guards check presence, safe file type and bounded size, not
semantic integrity or freshness of evolving radio state. Preserve current-state
backups and verify actual devices.

## Observation

`local_observe: true` enables a finite s6 sidecar inside the same app. Set
`local_backbone` to the verified host Ethernet interface. After a20-second delay,
it records20 samples with30-second gaps; bounded command runtimes add to duration.
Commands are fixed, shell-free and output-limited. The process reads Thread role,
OMR/network data, host IPv6 addresses/routes/rules and RA/RIO/forwarding sysctls.
Only prefix/route sections of network data are logged; no dataset/key command is
present. On the first/last samples it tries bounded active Avahi DNS-SD queries,
retaining only interface, service, target, address and port, not TXT/instance data.
Logs remain private. A command failure, timeout, OpenThread Error response or
missing binary is explicit rather than interpreted as an empty topology.

Readiness limit: Avahi client/daemon availability in the released image is NOT
established (upstream uses mDNSResponder). The observation code reports missing
Avahi but does not solve that dependency. Select an existing compatible discovery
client or approved observation point after image inspection; do not install an
Avahi daemon or reflector into the radio app simply to satisfy this script.
Actual OT CLI commands/socket, s6 graph, AppArmor and host namespace observations
also require released-image validation before live use.

## Evidence, 2026-09-11

- 19 local WSL Python tests passed: two-source selection, unchanged options,
  interrupted-import refusal, restart continuity, unsafe archives, gzip integrity,
  first-run/recovery OTBR-off enforcement, command time/output limits, DNS-SD
  output filtering and reproducible package manifests.
- A32MiB image-before-state fixture used less than4MiB peak traced Python memory
  during extraction. This is a bounded-memory check, not a production backup test.
- An independent read-only review challenged importer safety. Its two required
  startup-option gates were added and tested. It found no additional must-fix
  archive/state-lifecycle issues; it did not independently execute tests.
- Upstream still lists1.0.2; latest add-on-path changes found were the May6 README
  and1.0.2 update. No released artifact containing this exact fix was established.
- Docker engine was unavailable. An ordinary Desktop startup did not make it
  available during this preparation; no repair was attempted. Therefore NO new
  image build, complete s6 graph compile, released-Python tests, image-switch
  sentinel test or Supervisor persistence/failure rehearsal has passed.

Stop here until the image-validation blocker is resolved. This source-level
increment is useful but does not make activation execution-ready. No production
installation, restart, radio test or networking modification was performed.
