# Isolated PR79 Trixie audit

This worktree is current upstream master 5a8d7dec plus the unchanged two-file
PR79 patch from 4c7d63cf. The audit is investigatory, not a deployment. Push to
its named investigation branch or dispatch trixie-dependency-audit.yml only after
review. Nothing is published or uploaded; evidence is printed to CI logs.

The single GitHub-hosted AMD64 job first inventories the pinned released image,
resolved HA Trixie base and resolved vanilla Debian builder. Full dpkg versions,
s6/Bashio identifiers, tool versions, executable hashes and available ELF/loader
information are read without starting /init or application services. These are
actual installed image contents, not candidate package-index versions.

It then attempts the entire PR79 AMD64 Dockerfile, including CPC, SLC-generated
Zigbee, the vendor OTBR build, WEB/npm and final package cleanup. It stops at the
first build failure and prints the BuildKit stage/command and nonzero status;
there is no automatic dependency repair or skipped web build. If successful,
it inventories the resulting image and rejects missing linked libraries.

Audit-only acquisition adaptations in the temporary build context:

- Pin debian:trixie and the HA AMD64 Trixie base to the reviewed architecture
  digests in inputs.sh. Their tag/index provenance is recorded there.
- Download the official SLC ZIP once over verified HTTPS and require the reviewed
  SHA256/size. Populate the Dockerfile's already-required COPY input, replacing
  its redundant unchecked curl download with a checksum check of identical bytes.
- Preserve CPC v4.6.1 and SDK v2024.12.1-0, asserting their inspected commit IDs
  after cloning. No source, compiler, feature, patch or SDK-version repairs.

SLC acquisition review, 2026-09-12: the official login-path URL returned a public
ZIP without credentials or a click-through. The inspected archive is 215063443
bytes with SHA256 5fc88e5f7e3a782a9181716bf173285d4794ea6d2282dde0c992179e3ab955f8.
Its top changelog says 5.11.0.0 / Java 21, while its readme still says Java 17+.
The reviewed hash is drift protection, not a vendor signature. A changed archive
fails the gate rather than being executed automatically.

The archive has third-party notices and Eclipse licensing, but no top-level SLC
license that establishes terms for every bundled component. The exact SDK's
License.txt defaults to Silicon Labs' MSLA with file-specific exceptions. The
original build's slc signature trust and /accept_silabs_msla marker are retained,
not newly bypassed; this audit does not make a licensing conclusion or perform
an external agreement acceptance. No package/binary redistribution is proposed.

Sources: https://docs.silabs.com/simplicity-studio-5-users-guide/5.10.0/ss-5-users-guide-tools-slc-cli/02-installation
https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/License.txt
https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/pull/79

All execution is on a disposable GitHub-hosted runner. Read-only inspection
containers use no network, capabilities, devices or host mounts. The build has
public network access for unchanged package/source acquisition, and a 90-minute
bound. No credentials, production data, image publishing or artifact uploads
are used. Current APT/npm inputs remain upstream behavior, so image pinning alone
does not freeze every package; exact installed versions/build output are evidence.
A successful build would not prove ARM or physical shared-radio compatibility.
