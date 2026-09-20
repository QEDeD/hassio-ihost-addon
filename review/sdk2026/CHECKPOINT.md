# Accepted SDK2026 checkpoint — 20 September 2026

Start at [EXECUTION.md](EXECUTION.md) for the accepted trial and recovery limits.
The HomeAssistant repository owns maintained installation state and future project
navigation: `/home/wsluser/src/HomeAssistant/README.md`, then
`docs/projects/sdk2026-upgrade/README.md`. Its remote is
`https://git.thewrt.com/kristoffer/HomeAssistant.git`.
This repository owns implementation, build recipes and dated qualification evidence.

## Source and exact outputs

Acceptance/source record commit: `4554a605397b38e056b63c711823623ec1d237c7` on
`codex/sdk2026-integration`, origin `https://github.com/QEDeD/hassio-ihost-addon.git`.
This checkpoint adds retained output copies and navigation; it does not rebuild or
modify deployed source. [Accepted result](FULL-FUNCTIONAL-RESULT-20260920.md) and
[structured result](evidence/full-functional-result-20260920.json) identify the exact
GBL and app image. [Retained artifacts](retained-artifacts/README.md) preserve the
GBL, compressed ELF/map and independent package-validation result in Git.

Host recipe: `hassio-ihost-silabs-multiprotocol/Dockerfile.sdk2026`,
[build wrapper](build-host-sdk2026.sh), [vendor build](recipe/build-in-container.sh),
[package pins](recipe/PACKAGE-INPUTS.md) and [runtime adaptations](runtime/install.sh).
The accepted image adds the [trial wrapper](trial/README.md); its
[manifest](trial/build-manifest.json) pins base image and helper input hashes.
The manifest's offline-preparation status is historical. Final publication is in
[published-images](evidence/published-images-20260919.json); deployment is established
by the later accepted result. Image labels inherited from the HA base do not identify
our application source commit.

Firmware recipe: [receive-fix Dockerfile](firmware/receive-fix/Dockerfile.offline),
[preparation and source guards](firmware/receive-fix/README.md),
[packaging wrapper](firmware/receive-fix/build-package.sh),
[review](RECEIVE-FIX-REVIEW-20260920.md), and
[preparation hashes](evidence/receive-fix-preparation-20260920.json).
The pinned builder carries SDK/toolchain inputs. Debian package snapshot and source
epoch are pinned. Do not substitute the uncorrected original firmware recipe or
confuse diagnostic artifacts with the normal retained GBL. The wrapper also reuses helper source commit
`391bb7c56e01ef34ae5ae0b8cd259f31fdb7d6d0`, locally in the sibling
`haos18-focused` worktree; see `trial/helper-provenance.json`. Keep that source
revision available when reconstructing the wrapper. This checkpoint verifies
recorded inputs/outputs; it does not claim a fresh byte-identical rebuild of the host.

## Retention and operation

Final image registry digest was rechecked during checkpoint preparation. Non-secret
firmware artifacts are retained here; protected backup/key/log material stays under
`/home/wsluser/.local/share/ha-recovery/`, indexed by the HA project checkpoint.
The existing recovery store is not automatically covered by the HA VM's backups.
No recovery script is authorized to run because it appears in this tree. Historical
trial instructions, provisional labels and old recovery-only variants are evidence,
not current deployment procedures. Use the current execution record and a new concrete
applicable scope before disruptive work.

[Nine contribution reassessment](recovery/UPSTREAM-REASSESSMENT-20260920.md) remains
the starting point for upstream work; public posting needs separate authority.
