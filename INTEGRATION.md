# Upstream contribution review package

## Outcome and current gate

Prepare six focused contributions and one combined candidate that preserves
reliable Zigbee and Thread/Matter operation. Isolated AMD64 acceptance and ARM
build/runtime checks passed. Production acceptance remains unresolved.

Candidate `0.2.3-ordered` completed the approved 30-minute observation and one
controlled restart followed by 10 minutes. Fresh Zigbee reads and Matter reports
continued, and the restart shut down cleanly. One light became unavailable in
both candidate windows; three real Zigbee group commands also returned BUSY.
These observations do not establish candidate causality. The approved fallback
installed `0.2.1-baseline` into the same app with current evolved data and complete
options. Zigbee and Matter resumed. The baseline comparison completed: the light stayed available in all 16 samples over 15 minutes. Its final requested read has no captured response, so that check is inconclusive.
NAT64 remains disabled; a separate suitable Thread consumer is still needed.

No upstream PR has been submitted, released or merged. Git pushes and test-image
publication to the approved QEDeD destinations are authorized through September
27, 2026. This document does not itself authorize production changes.

## Contributions and merge order

Upstream master reviewed on 2026-09-13:
`5a8d7dec067f9196ada5879f31f71cbf6d595bff`; master was the only upstream branch.
Relevant proposals: PR78 `03598f9b9c739d0293fa434f6899c1fa1efe5f7d`,
PR79 `4c7d63cf10ed0cf70f31c64257663c3bdd8b5983`. Preserve Arno500 attribution.

| Contribution | Reviewed head | Relationship |
| --- | --- | --- |
| Firewall lifecycle and shutdown ordering | 60d3334 | Prerequisite for NAT64 |
| Passive Zigbee readiness | 9536ef0 | Independent |
| Local commissioning QR generation | e34faa6 | Independent |
| Debian Trixie and Release compilation | 7c3e607 | SDK/CPC fixed; attributed mbedTLS backport |
| Opt-in NAT64/upstream DNS | 4ff1642 | Stacked on firewall; default off |
| HA app terminology | 84fab10 | Merge last to reduce textual conflicts |

PR78's firewall/NAT64/DNS ideas are represented with attribution and additional
validation. Coordinate the Trixie correction and evidence with PR79 first; a
credited successor is appropriate only if it reduces maintainer work. The clean
Trixie branch contains three product files, byte-identical to the verified
investigation product files. Integration packaging, recovery scripts and audit
machinery are not proposed as product PR content. Preserve both QR and DNS patch
installation when resolving Dockerfile changes.

SDK/CPC/firmware upgrades, TREL and unrelated radio-hang investigation remain
outside the bundle. Trial failures affecting acceptance cannot be dismissed as
that parked issue without evidence.

## Exact integrated artifact

Product source: `aca557b6eb851af109a2708f55b5b2668314818f`.
Registry: `ghcr.io/qeded/otbr-integration-test-amd64`.

| Version | Published OCI index digest |
| --- | --- |
| 0.2.3-ordered | sha256:0224cb183592e0e83aac35ce9ed6f350654537b73b73c03b0ebb74a1f972b107 |
| 0.2.1-baseline | sha256:a54a37aee7b6fb2d219b5e346725ae6d2f4972d0d9c4e1ef0bf4c33c99a46d4b |
| 0.2.2-recovery | sha256:a4bc52f4e8dc826d5d38308b36cf1021ebcb55c05210944a00edeaba2f7d9686 |

Candidate AMD64 platform manifest:
`sha256:3214cb9e1e42f8da631134f4177779ea9acd366273c00c901affab65efb9a4df`.
Anonymous registry checks verified manifest/config hashes, architecture/version
labels and availability of all 41 distinct layers across this candidate and the
three previously published wrappers. Existing tags were not overwritten. Docker
reported these wrapper IDs as OCI indexes, not configuration blob digests.

## Isolated and architecture evidence

The exact ordered candidate passed a clean AMD64 image build, linkage for all
five application binaries, complete s6 graph compilation, synthetic evolving
state/options switches against the exact published fallback images, and runtime
checks covering firewall lifecycle, synthetic IPv4 packet forwarding/rejection,
readiness, NAT64 configuration failure/timeout and native web handling. Browser
checks passed four viewport/payload cases, two encoder failures and hostile-input
handling with zero external requests. Synthetic credentials only were used.
Current local evidence: `/tmp/otbr-local-build.XYn1ut`.

Corrected [ARM run 34749205311](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34749205311)
passed full AArch64 and ARMv7 image builds, five-binary linkage and native web
checks under emulation at `11bef3674d0b35e6db87ecf27e2834d894df9d01`.
The later mDNS dependency changes the service graph, not compiled software; that
change was tested on AMD64. This is not physical ARM radio acceptance.

The preceding AArch64 build failed on bundled mbedTLS with GCC14 and strict
array-bounds warnings. Keith Packard's attributed upstream correction
`292b96c0a69016a6d99ce324837a9e96d59e21f6` fixed the focused reproduction and full
build while retaining optimization and strict warnings. SDK/CPC versions stayed
fixed. Earlier AMD64 CI34747387036 and local evidence under
`/tmp/otbr-local-build.NDQvDP` cover earlier source; they are not relabeled as
exact-current-source tests.

## Shutdown finding and production evidence

The first approved preflight stopped the previous 0.1.4-local app and observed
OTBR SIGPIPE, propagated as container exit 141. Services were restored before
candidate installation. OTBR used external mDNSResponder but lacked an s6 mDNS
dependency, permitting concurrent shutdown. Adding that dependency ensures OTBR
finishes first. A synthetic real-s6 lifetime test exits 0 with the edge and 42
without it; existing abnormal-exit and timeout assertions remain intact.
Direct libdns_sd failure probes did not reproduce SIGPIPE. The dependency fixes
justified ordering; it is not a proven explanation of the original SIGPIPE.

The ordered candidate was subsequently installed in place after a fresh,
verified stopped-state backup. Complete options were preserved and NAT64 stayed
off. Thread attached and fresh Zigbee/Matter reports resumed. All three relevant
apps remained started in 31 samples over 1803 seconds and 11 samples over 602
seconds after the controlled restart. Matter CO2 report age stayed below 47
seconds. A representative non-actuating Zigbee read succeeded in both windows.
The controlled restart recorded OTBR exit 0, firewall cleanup, then mDNS stop and
CPC exit 0. This verifies that observed restart, not all possible shutdowns.

One previously available light recovered after each start, then became
unavailable around minute 15 and minute 7 respectively. Three group commands in
the final window failed with BUSY. Power/mesh conditions and candidate causality
remain unresolved. A fresh backup preserved evolved state before switching to
the published baseline; no previous volume, snapshot, reset or firmware change
was used. The initial baseline direct state read succeeded. All 16 samples over 15 minutes retained the initial 109 unavailable entities; the affected light stayed available and Matter CO2 report age remained below 24 seconds. The last unsolicited light report was near the end of the window. A final GET was accepted, but no newer response was captured: final active-read verification is inconclusive. No BUSY appeared in the captured baseline log, but equivalent group-command traffic was not established. Keep the baseline running; the sequential comparison is evidence of a possible regression, not proof of candidate causality.
Raw logs, backups and identifying device details are retained privately outside
Git/CI under `/tmp/otbr-ordered-trial-20260913`.

## Remaining acceptance and review

1. Confirm physical power for the affected light and diagnose the unresolved
   candidate dropout using preserved evidence. Keep the baseline running;
   another cutover needs a deliberate test window and confirmed response capture.
2. Test NAT64 separately with a Thread endpoint that initiates traffic to a
   controlled IPv4 service, including an enabled/disabled comparison. ALPSTUGA
   reports, local OTBR-originated packets and synthetic IPv4 firewall tests do
   not establish this end-to-end behavior. Consumer availability is unresolved.
3. Reconcile final PR evidence with the resulting tested source and obtain user
   approval before upstream submission.

Independent review of final contribution source, integration boundaries and
shutdown-order changes found no material product findings. It was source review,
not an independent rerun of tests. Independent production-evidence review agreed that acceptance remains unresolved;
its initial final-read claim was corrected after timestamp verification. Host-reboot ordering and physical ARM radio behavior remain
unverified; no claim of universal radio reliability or guaranteed downgrade is
made. Firewall ownership retains the documented single-OTBR assumption.
