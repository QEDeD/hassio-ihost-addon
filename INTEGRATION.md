# Upstream contribution review package

## Outcome and current gate

Prepare separate upstream contributions and one combined candidate, preserving
reliable Zigbee and Thread/Matter operation. The corrected AMD64 candidate passed isolated acceptance; production acceptance remains pending.
Production acceptance is pending; neither deployment nor upstream submission is
authorized by this document. Corrected AArch64 and ARMv7 build/runtime checks passed; see acceptance update below.

## Source and proposed merge order

Reviewed upstream master: `5a8d7dec067f9196ada5879f31f71cbf6d595bff` (2026-09-13).
The branch review found master only. Relevant open proposals were PR78 at
`03598f9b9c739d0293fa434f6899c1fa1efe5f7d` and PR79 at
`4c7d63cf10ed0cf70f31c64257663c3bdd8b5983`. Preserve Arno500 attribution.

| Contribution | Current contribution head | Purpose and relationship |
| --- | --- | --- |
| Firewall lifecycle | 60d3334 | Scoped setup/cleanup; prerequisite for NAT64 |
| Passive Zigbee readiness | 9536ef0 | Require the owned listener without consuming TCP connections; independent |
| Local QR generation | e34faa6 | Keep commissioning PSKd/EUI payload in the browser; independent |
| Debian Trixie | 7c3e607 | Update distribution inputs and explicitly select Release; SDK/CPC fixed |
| NAT64/upstream DNS | 4ff1642 | Opt-in translation and DNS; stacked on firewall, disabled in baseline |
| HA app terminology | 84fab10 | User-facing wording; preserve technical identifiers; merge last |

PR78's firewall/NAT64/DNS ideas are represented with attribution and additional
validation. TREL remains outside this package. Coordinate the Release correction
and evidence with existing PR79 first; use a credited successor only if it clearly
improves maintainer review. Do not submit the complete Trixie investigation history
as a competing PR by default. Its audit workflow is external evidence, not yet a
permanent upstream CI proposal. Integration-only packaging/recovery tooling does
not belong in the individual product PRs.

The assembled product source first passed at `0999946`. Integration `11bef36` now adds the verified mbedTLS backport, retaining the QR and DNS patches. New AMD64 isolated acceptance passed for that changed product source; full ARM verification passed in run 34749205311. The QR head adds the UI-event test correction to earlier product head
`4969de6`. Merge resolutions retained both QR/DNS Dockerfile patch installation
steps and the full NAT64 documentation. SDK/CPC/firmware upgrades, TREL and unrelated
radio-hang work remain deferred unless trial evidence makes them necessary.

## Verified evidence

[Combined AMD64 CI34747387036](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34747387036)
passed at `0999946ab0c826b59ee599194f6dff49269b7b38`. Its image was ephemeral;
do not confuse that pass with an untested replacement artifact.

A clean Linux checkout of `11bef3674d0b35e6db87ecf27e2834d894df9d01` subsequently
built the retained local AMD64 image and passed immutable-image linkage inventory.
Build records capture source revision, dirty/untracked state, copied-context hashes
and Docker image identity. Helper `391bb7c56e01ef34ae5ae0b8cd259f31fdb7d6d0`
built the three retained wrappers:

| Image | Docker-reported ID / published wrapper OCI index digest |
| --- | --- |
| Combined base | sha256:8a6bf28c97231f7c596f84a8dd8c78a43ff697f6e74705455f5f86b3f8c1619a |
| Candidate | sha256:7a5746b91c872b4b8a9b5a9becd7697f1161e15dbe4d20d26190d9fc1b06a2c1 |
| Baseline | sha256:a54a37aee7b6fb2d219b5e346725ae6d2f4972d0d9c4e1ef0bf4c33c99a46d4b |
| Limited recovery | sha256:a4bc52f4e8dc826d5d38308b36cf1021ebcb55c05210944a00edeaba2f7d9686 |

The exact candidate passed:
- Complete installed s6 graph compilation for all three wrappers, without services.
- Candidate/baseline/candidate synthetic image switches preserving evolving files
  and full options; five stub starts. OTBR-off recovery passed; OTBR-on recovery
  was refused. No real radio initialization or counter compatibility was tested.
- Real-kernel firewall lifecycle and synthetic IPv4 forwarding, rejection and
  cleanup; s6 shutdown and NAT64 off/on/error/stall cases; passive Zigbee listener
  ownership; installed Bashio and native web failure handling.
- Browser checks against extracted assets: four viewport/payload combinations,
  two encoder failures, hostile input retained as data and zero external requests.
  The corrected image passed using test-only correction `e34faa6` and the real QR click; two prior-image runs also passed.
  The earlier harness timed out twice when calling Angular outside the UI event;
  product code and security assertions were unchanged.

Local current evidence: `/tmp/otbr-local-build.NDQvDP` (build record, package identities, runtime.log and browser.log). Earlier-image evidence remains at `/tmp/otbr-local-build.1KZZGI`; its image is tagged `local/otbr-trial-candidate:pre-mbedtls-backport`. Raw production logs/credentials are excluded.
The audit image contains one retained test-only mbedTLS config.py file.

## ARM verification

[ARM run34747479789](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34747479789)
at `e28c7aa` completed with an AArch64 failure; ARMv7 passed its complete image build, installed linkage and isolated native web checks. AArch64 failed compiling bundled mbedTLS
ctr_drbg.c with GCC14.2, -O2 and -Werror=array-bounds. It was not a timeout;
final-image runtime checks were not reached. Upstream mbedTLS commit
`292b96c0a69016a6d99ce324837a9e96d59e21f6` addresses this diagnostic. A focused ARM64 cross-compile reproduced the original failure and passed with this upstream backport, retaining -O2 and strict warnings. Integration completed at `11bef3674d0b35e6db87ecf27e2834d894df9d01`; full-image verification passed in ARM run34749205311 and the local AMD64 rebuild. No ARM acceptance is inferred from AMD64 evidence.
The previously inspected armv7 vendor archive imports legacy `time`; this identifies
a possible 2038 limitation, not a demonstrated ABI mismatch.

## Delivery and recovery gate

Installed identifier `local_codex_ihost_otbr_focused` correctly corresponds to
config slug `codex_ihost_otbr_focused` staged at `/addons/codex_ihost_otbr_focused`.
Use the established store reload and distinct-version stopped-app update, retaining
the same authoritative data volume and complete options. No uninstall or seed import.

Verified preferred delivery: publish the exact tested wrappers to
`ghcr.io/qeded/otbr-integration-test-amd64`, then add only that repository's `image`
field to existing local app metadata. Supervisor 2026.09.0 selects a registry pull
from store metadata containing `image`, preserving the local app identifier/data.
Tags match versions: `0.2.0-integrated`, `0.2.1-baseline`, `0.2.2-recovery`.
Prepared local metadata is under `/tmp/otbr-local-build.NDQvDP/delivery-configs`.
All three differ only by `image`; independently checked. Actual wrapper labels
match their versions, type=app and arch=amd64. Publication was approved and all three wrapper tags were uploaded; GitHub now reports public visibility. Anonymous registry access verified all three index/platform/config manifests, matching labels and all 35 distinct required layers.
Registry inspection verified each published OCI index digest equals the corresponding tested local image ID and contains exactly one Linux AMD64 platform manifest. These Docker IDs represent OCI indexes in this store, not image-configuration blobs. Do not retag. Supervisor's config uses version
tags rather than accepting a digest in the image field. No build on HA is needed.
Prove the actual candidate and recovery images are available before cutover.

Take a fresh stopped-state backup before update and retain state evolved during
the trial. Candidate/baseline wrappers preserve Thread-enabled options; the limited
recovery wrapper enforces Thread off and is only a Zigbee fallback. Same SDK/CPC
versions and synthetic continuity reduce uncertainty but do not prove real-radio
downgrade safety. Explain that residual risk in the particular cutover approval;
do not claim guaranteed recovery or restore an obsolete volume/VM snapshot.

## Approved production acceptance — paused after stop error

Capture representative fresh Zigbee and ALPSTUGA Matter reports before the change.
With NAT64 disabled, stop the dependent Zigbee client and app, update, restart in
the established order, and confirm image/version, readiness, OTBR attachment and
fresh end-to-end reports. Exercise a safe representative read/control where suitable.

Observe at least 30 minutes, extending if selected devices have not reported. If
included in approval, perform one controlled app/client restart and observe fresh
reports for another 10 minutes. These windows test ordinary operation, not absence
of the parked intermittent radio hang. Specify interruption/recovery actions and
whether a passing candidate remains running before requesting approval.

NAT64 needs a separate enabled/disabled comparison with a Thread consumer that
actually initiates traffic to a controlled IPv4 endpoint. ALPSTUGA sensor reports
alone cannot prove translation. Consumer availability and permitted traffic remain
unresolved; synthetic packet tests do not replace this production requirement.

After trial findings are resolved, ensure individual branches match the tested
product changes, complete independent final review, and present the PR bundle for
approval. No upstream submission, upstream release or merge has occurred. The explicitly approved test images have been published to GHCR; production is unchanged.

Clean Trixie contribution `7c3e6076e5f84995ac8b881aea4b4f12855a1e10` contains only
Dockerfile, build.yaml and the attributed mbedTLS patch. Parent verified all three
files are byte-identical to investigation `c46ddf9`, which integration `11bef36`
merges. Audit history remains external evidence. The separate branch preserves
atomic PR79, Release and mbedTLS-backport changes and is pushed for review.
Independent source review of the six final contributions and integration found
no material product defects. It checked lifecycle/readiness, NAT64 error gating,
QR generation, Trixie patch boundaries and relevant test assertions. No additional
code change was requested. This was a read-only source review, not an independent
rerun of image tests. Corrected ARM checks have passed; production acceptance remains a gate;
firewall ownership assumes the documented single-OTBR deployment.
Publication evidence is retained in `publication-evidence-20260913.json` in the
local OTBR workspace. Candidate platform manifest:
`sha256:a49d54cf60650821fbb8e53abd311184b833c54bdee7ea27a51bdb1892225ace`;
baseline: `sha256:621c209d7226ed8f3b093b82a1440e63b9f241d384ba8710ec46b5c46d55a891`;
recovery: `sha256:a8d614a4260b0b9c660a0e91422ed8054f153db69f4c3251eef247c4b1985fd9`.
The version tags' OCI index digests are the wrapper identities in the table above.
The operator completed the visibility change. An anonymous registry-token request (no Docker/GitHub credentials) verified manifest hashes, version/type/architecture labels and HEAD access to all 35 distinct required layer blobs. This establishes registry availability; HA-side download/start is still pending.
The operator approved the described trial; it stopped at the shutdown preflight gate. No candidate has been installed.
## Acceptance update — 2026-09-13

Corrected ARM run [34749205311](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34749205311)
passed for both AArch64 and ARMv7 at source
`11bef3674d0b35e6db87ecf27e2834d894df9d01`. Both job logs confirm complete image
builds, installed linkage for all five binaries and isolated native web checks
under emulation. This closes the corrected ARM build/runtime gate, not physical
ARM radio acceptance.

The operator approved the concrete AMD64 trial. Preflight reached stopping the
existing 0.1.4-local app; Supervisor recorded exit 141. No candidate installation
or fresh backup occurred. Existing services were restarted and fresh Zigbee and
Matter reports verified. The shutdown log shows OTBR signal 13, propagated by
its finish script as container exit 141; firewall cleanup and CPC shutdown
completed. Candidate finish handling has the same behavior.

OTBR and mDNS stop concurrently because OTBR lacks an explicit dependency on
mDNS, although its build selects mDNSResponder. This is a justified ordering
concern, not yet a proven source of SIGPIPE. An isolated test using the candidate's
real libdns_sd (create connection, stop daemon, deallocate or register on the
existing connection, including removing a registered synthetic AAAA record) did not reproduce SIGPIPE. Do not blanket-ignore exit 141.
Production acceptance remains blocked pending targeted shutdown investigation;
NAT64 consumer/testing and final bundle acceptance remain outstanding.
## Ordered replacement candidate — local acceptance

Integration `aca557b6eb851af109a2708f55b5b2668314818f` and firewall contribution
`60d3334` add the mDNS dependency and shutdown-order regression. Independent
review found no material findings. Real s6 positive case exits 0 after client
cleanup; removing only the edge in the negative control gives exit 42. Existing
failure/cleanup timeout scenarios retain exit 23. This does not establish the
source of production SIGPIPE.

Local build `/tmp/otbr-local-build.XYn1ut` completed successfully. Candidate
version `0.2.3-ordered`, immutable local image identity
`sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107`,
passed installed linkage, full packaged s6 graph compilation, evolving synthetic
state/options preservation against the exact published baseline/recovery images,
and the complete isolated runtime suite including the new shutdown-order case.
Browser checks on extracted candidate assets passed four viewport/payload cases,
two encoder failures and hostile-input handling with zero external requests.
The original baseline/recovery images remain the intended fallback artifacts;
newly generated local fallback wrappers are not replacements for published tags.
This candidate is published and installed under the approved trial; acceptance is in progress. Production acceptance and
separate NAT64 consumer testing remain incomplete. The previous ARM acceptance
covers the same compiled software; the added graph edge is tested here on AMD64.
NAT64 head 4ff1642 incorporates firewall 60d3334. The documentation-only merge conflict retained NAT64 guidance; OTBR lifecycle files and s6 fixtures match integration aca557b. PR draft heads and ARM status are reconciled. The operator clarified that test-image publication is included in the two-week authorization through September 27, 2026.

Published 0.2.3-ordered with index digest sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107 and AMD64 manifest sha256:3214cb9e1e42f8da631134f4177779ea9acd366273c00c901affab65efb9a4df. Anonymous manifest/config hashes, HA labels and access to all 41 distinct layers across the new and three existing images verified. Existing published tags are unchanged. Production trial is now in progress; see current trial status below.

## Current production trial status

The existing app was updated in place from 0.1.4-local to 0.2.3-ordered on
2026-09-13, after a normal stop and a fresh stopped-state backup. The private
backup was copied locally, archive length validated and both nonempty radio
state files verified. Complete prior options were preserved; NAT64 remains off.
Supervisor logs confirmed successful image update despite an ambiguous API
response. No reset, firmware change or old-state restoration occurred.

Candidate startup attached Thread as a router; fresh ALPSTUGA measurements and
Zigbee responses were observed. A 30-minute read-only observation is running,
followed by the approved controlled restart and 10-minute observation if healthy.
Initial entity availability is identical to preflight. Reconnect warnings are
under assessment, not dismissed. This is deployment evidence, not completed
production acceptance. Private evidence remains outside public Git/CI.