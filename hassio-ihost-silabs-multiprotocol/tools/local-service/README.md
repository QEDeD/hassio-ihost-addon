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
and discarded, not extracted or buffered in memory. It accepts bounded per-file PAX metadata only when it contains a single timestamp.
It refuses links, sparse or other extension headers, unsafe paths, unexpected destination state, and selected-file
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
present. On the first/last samples it uses the installed dns-sd client and the
existing mDNSResponder daemon on the verified backbone interface. Each browse
and IPv6 address query has a two-second window and a four-second external bound;
at most four SRV targets per service are resolved. It retains service, target,
port, IPv6 address and interface index, not TXT/instance data. Results are bounded
observations, not an exhaustive inventory; an empty result does not establish
absence of devices. Only valid .local targets are resolved. Truncation and query
failure are explicit. Logs remain private.

A local-only synthetic service with a spaced instance name, private TXT, SRV and
AAAA was registered and resolved through the installed helper in both images.
No network or radio was accessible, and normal /init did not run. This establishes
the daemon/client/parser combination, not multicast delivery on the actual LAN,
AppArmor acceptance or discovery of real accessories. No Avahi daemon is needed.
The full fixed and recovery s6 graphs now compile. Actual OT CLI commands/socket,
AppArmor and host namespace observations still need runtime verification.

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
- Docker initially blocked image validation. Reusing the prior successful runtime-
  directory quarantine restored the engine; its settings were unchanged and all
  five retained OTBR images were present. An isolated hello-world test passed.
- Both generated images built from the pinned base. Their full s6 graphs compile,
  installed preparation Python files match source, and all five fixed runtime
  files match the focused overlay. Recovery has the explicit OTBR-off environment.
- All19 tests also pass under the fixed image's Python3.9.2. Containers used no
  network, a read-only root, no capabilities, no-new-privileges and no radio or
  host mounts. Normal /init and real radio services were never executed.
- Fixed local image manifest-list digest:
  `sha256:1ddfa4bcc9e4f89d06ec01ac74d6076bab42544749694d8ef236675a87fa2370`.
  Recovery local image manifest-list digest:
  `sha256:0bb322481674051d9171f5e07a3f74cf73fa9899c75f44523865f149a90212c0`.
  Neither image is published or installed in HA.

## Completed isolated checks and remaining gates

- All 21 preparation tests pass in WSL and the released Python 3.9.2 runtime.
- Both updated images build; installed Python source hashes match, the five
  focused runtime files are unchanged, and complete s6 graphs compile.
- `check_dns_sd.py` passes against the installed helper in each image. Run it
  only in an isolated Docker container with networking disabled, capabilities
  dropped, read-only root/source, writable /run and /tmp tmpfs, and Python as
  the entrypoint. It starts only mDNSResponder plus a local-only registration;
  it never starts normal init, creates a Thread network or accesses a radio.
- `check_image_switch.py` runs under Linux/WSL with Docker: fixed -> fixed ->
  recovery -> fixed preserves two evolving synthetic state files and nondefault
  options on one /data bind mount. OTBR-enabled recovery is refused before stub
  init. This proves container continuity, not radio counter safety or Supervisor
  update/backup behavior.
- An isolated Supervisor 2026.09.0 rehearsal at commit
  75e47083b96c97c46d411ea0292e5b699a7850c2 passed 15 tests: upstream running/stopped
  update/rebuild and options cases, plus four synthetic continuity cases. Docker
  and AppsData.save_data were mocked. This establishes Python lifecycle and
  in-memory options behavior, not durable Supervisor persistence or native
  backup/restore integration.

Updated local images (neither published nor installed in HA):

- `local/otbr-persistent-prep:0.1.0-dnssd`, manifest-list digest
  `sha256:b02a49e02a52c1efaaf8ae759536d59594484620490193ac8dd79d8dab35656f`.
- `local/otbr-persistent-prep:0.1.1-recovery-dnssd`, manifest-list digest
  `sha256:074fc973bf2b84c2b1f327daec80a1b8a8af4f5bf4fdb73682c52b8642ae5bcd`.

Both current images suppress automatic OTBR REST discovery in the compiled s6
user bundle. Core's discovery flow can create a missing active dataset without
confirmation. Integration setup is manual and gated on private active-dataset
verification; see ACTIVATION.md for the supported remove-old/add-new transition.

Remaining gates: native Supervisor persistence/backup/failure integration,
authenticated control and endpoint reconfiguration, then approved verification
of real OT socket, host namespace, discovery and radio behavior. The documented
access prerequisite now passes and installed SSH manager role is verified.
The installed Bashio helper is unsuitable for credential-safe writes; existing
admin UI control is preferred. No integration or app-options write was tested. No production
installation, restart, radio test or network modification was performed.

## Integrated trial packaging (preparation only)

`make_trial_contexts.py` reuses the unchanged historical generator to produce
three contexts under a new absolute destination. It never invokes Docker,
installs an app, imports live state or starts radio services. The original
`make_context.py` interface and five-file source-hash safeguards are unchanged.

The caller first retains `docker image inspect local/otbr-integrated:ci-tag`
output from its already-built combined Linux AMD64 image. Supply that JSON array,
the same local tag and its independently recorded immutable image ID:

```sh
python3 tools/local-service/make_trial_contexts.py /tmp/otbr-trial-new \
  --combined-image local/otbr-integrated:ci-tag \
  --expected-image-id sha256:<64-lowercase-hex-digits> \
  --image-inspect /tmp/combined-image-inspect.json
```

The example runs from the add-on directory. Replace the ID placeholder; it is
not executable evidence. The helper checks the inspection's exact tag/ID and
Linux/AMD64 identity. It records that identity in the candidate manifest and
writes a tagged `FROM`, because a raw local image ID is not a portable BuildKit
base reference. Inspection JSON is caller-supplied evidence, not authenticated
by the helper. The caller must recheck the tag resolves to the expected ID
immediately before and after building, use the same Docker daemon/local image
store, prevent concurrent retagging and retain build provenance. If the builder
cannot resolve that local image, stop; do not silently substitute a registry
image. No combined-image availability or build is established by generation.

Generated contexts share slug `codex_ihost_otbr_focused`:

- `candidate` defaults to version `0.2.0-integrated`. Its base is the inspected
  combined image. Only local guard/observer scaffolding is copied; none of the
  five historical runtime files overlays the integrated runtime.
- `baseline` defaults to `0.2.1-baseline`, using the pinned released base and
  exact historical five-file focused overlay. OTBR can run against current state.
- `recovery` defaults to `0.2.2-recovery`, using the pinned release without that
  overlay and enforcing OTBR off on every guarded start.

Optional `--candidate-version`, `--baseline-version` and `--recovery-version`
flags select three distinct safe package versions. They must also differ from
the original local/recovery versions. Before any approved update, verify each
selected version differs from the actually installed version; the helper has no
live installation knowledge. All three retain the complete local configuration
and add `otbr_nat64: false` plus its boolean schema, allowing full options to
survive code switches. Defaults remain prepare/manual/OTBR off. Existing live
options must be retained explicitly at deployment; template defaults are not a
replacement for those options. All three retain the state guard, observer and
automatic discovery suppression. No firmware or import migration is introduced.

After building the three contexts in the caller's approved isolated environment,
run the existing fixture with their resulting local image IDs (not the combined
base ID):

```sh
python3 tools/local-service/check_image_switch.py \
  --candidate sha256:<candidate-image-id> \
  --baseline sha256:<baseline-image-id> \
  --recovery sha256:<recovery-image-id>
```

This exercises an initial guarded OTBR-off start, candidate/baseline/candidate
switches with OTBR enabled, and a separate OTBR-off recovery/refusal check. It
uses one evolving synthetic data volume, complete synthetic options including
NAT64 off and a sentinel, stub `/init`, no network and no capabilities. It never
validates radio counters, persisted radio format compatibility, physical devices
or real Thread/Matter recovery. Passing the fixture is required packaging evidence,
not production authority. Exact-image execution remains unverified until run.

The 29 local unit tests pass, including five trial-packaging tests for guarded
entrypoints, historical-overlay exclusion, full options/schema preservation,
manifest hashes, distinct versions, invalid inputs and unchanged source-hash
refusal. No Docker build or real image-switch run was performed for this helper.
Production trial and same-volume recovery still require the concrete approval
and verification described in ACTIVATION.md; never restore stale radio state.
