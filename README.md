# TEST ONLY — Silicon Labs OTBR candidate 186eac8

> [!CAUTION]
> This is an experimental, fork-only hardware-test feed. It is not an
> upstream release, it supports only `amd64`, and it must not be started
> without a current backup and a recorded rollback path.

This branch exposes exactly one Home Assistant add-on:
**TEST/EXPERIMENTAL — Silicon Labs Multiprotocol (186eac8)**. Its runtime and
build inputs come from broad canonical Silicon Labs head
`186eac8354fdcab9c224ec840989da1fd86af882`. The delivery metadata selects the
already validated AMD64 image under a unique candidate-only GHCR name.

Successful hardware results validate that exact broad canonical head. They do
not validate a later, scope-specific, rebased, or otherwise changed upstream
head.

## Installation

Do not add this repository until the provenance record shows that the image was
published, made public with explicit approval, and anonymously pull-verified.

1. Create and verify a current Home Assistant backup.
2. Record the original add-on options, radio connection, consumers, and
   rollback target.
3. In Home Assistant, open the add-on store repository dialog.
4. Add this exact branch URL:

   ```text
   https://github.com/QEDeD/hassio-ihost-addon#codex/otbr-candidate-feed
   ```

5. Refresh the store and verify that this repository exposes only the
   conspicuously named TEST/EXPERIMENTAL AMD64 candidate.
6. Install it, but do not start it until the preflight section of the
   [hardware-test and rollback runbook](./HARDWARE-TEST-RUNBOOK.md) is
   complete.

The resolved image reference must be:

```text
ghcr.io/qeded/ihost-silabs-otbr-candidate-186eac8354fdcab9c224ec840989da1fd86af882-amd64:1.0.2
```

## Records

- [Candidate provenance and publication record](./CANDIDATE-PROVENANCE.md)
- [Hardware-test and rollback runbook](./HARDWARE-TEST-RUNBOOK.md)
- [Canonical implementation release gates](./hassio-ihost-silabs-multiprotocol/RELEASE.md)

No pull request or upstream contact is part of this candidate feed.

## License and attribution

The retained implementation and documentation remain subject to the
repository's [MIT license](./LICENSE), notices, and component-specific license
files. The implementation originates from the
[iHost Open Source Project](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon);
this experimental delivery branch is maintained only in the `QEDeD` fork.
