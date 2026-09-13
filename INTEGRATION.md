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
options. Zigbee and Matter resumed. The baseline retained light availability during the 15-minute comparison, then the same light failed two pings and went offline. Its final requested read had no captured response. The dropout therefore occurs on both images; candidate-specific causality is unproven.
NAT64 remains disabled. An existing authorized Thread plug now provides a verified UDP rejection response for the separately approved translation test.

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
was used. The initial baseline direct state read succeeded. All 16 samples over 15 minutes retained the initial 109 unavailable entities; the affected light stayed available and Matter CO2 report age remained below 24 seconds. The last unsolicited light report was near the end of the window. A final GET was accepted, but no newer response was captured: final active-read verification is inconclusive. No BUSY appeared in the captured baseline log, but equivalent group-command traffic was not established. A subsequent baseline log captured two failed pings and the same light going offline at 13:51:47 CEST. Core then confirmed the same four-entity availability loss (113 unavailable total), with all apps started and continuing Matter reports. The earlier healthy interval does not establish sustained recovery. This shared symptom does not demonstrate a candidate-specific regression, although differing rates or causes remain possible. Keep the baseline running with continuous mains power now confirmed and the remaining group-command evidence unresolved.
Raw logs, backups and identifying device details are retained privately outside
Git/CI under `/tmp/otbr-ordered-trial-20260913`.

## Remaining acceptance and review

1. Continuous physical power is confirmed for the light that fails on both images. Keep this
   shared device issue distinct from candidate acceptance; do not start a broad
   mesh investigation as an implicit prerequisite. Three candidate group-command
   BUSY failures remain unexplained by comparable baseline traffic. A further
   live comparison needs a deliberate window and confirmed response capture.
2. Test NAT64 separately using the existing authorized plug's verified CASE
   rejection response, including an enabled/disabled comparison on the same
   candidate. A reply can supply the outgoing Thread IPv6 packet; initiating
   an application conversation is not required. The ordinary IPv6 control and
   actual Windows Python collector path passed. Translation remains untested.
   See tools/nat64-reply-probe/README.md for the bounded procedure and evidence limits.
3. Reconcile final PR evidence with the resulting tested source and obtain user
   approval before upstream submission.

Independent review of final contribution source, integration boundaries and
shutdown-order changes found no material product findings. It was source review,
not an independent rerun of tests. Independent production-evidence review agreed that acceptance remains unresolved;
its initial final-read claim was corrected after timestamp verification. Host-reboot ordering and physical ARM radio behavior remain
unverified; no claim of universal radio reliability or guaranteed downgrade is
made. Firewall ownership retains the documented single-OTBR assumption.

## Group-send evidence limit

Zigbee2MQTT 2.14.1 declares zigbee-herdsman 10.9.2. In the matching
[Ember adapter source](https://github.com/Koenkk/zigbee-herdsman/blob/v10.9.2/src/adapter/ember/adapter/emberAdapter.ts),
`sendZclFrameToGroup` throws on non-OK status immediately, whereas unicast sends
have bounded BUSY retry handling. This identifies the reporting path, not the
cause of radio BUSY. No change to this separate dependency is proposed. The
retained pre-candidate and baseline Zigbee log captures did not contain BUSY;
unequal traffic and rolling capture prevent treating absence as a controlled
comparison. HTTP acceptance of an MQTT publish is not proof of a Zigbee response.

## Additional physical Thread control — 2026-09-13

A user-authorized IKEA GRILLPLATS 1.4.6 plug was identified from recent physical
button transitions and matched to its live entity/device/Matter endpoint.
Thread diagnostics confirmed transport. On baseline 0.2.1, fresh HA transitions
and server-backed Matter OnOff values confirmed on then off; the initial off
state was restored. Other plugs were unchanged and ALPSTUGA reports continued.
This establishes a usable ordinary Thread/Matter control target, not candidate
acceptance or NAT64. No supported command for initiating traffic to a selected
IPv4 service was established for this plug.

Two preliminary assertions against per-device diagnostic snapshots were invalid:
the installed Matter client retained stale raw node attributes while updating live
endpoint values. Server-backed diagnostics resolved the mismatch. These are test
method failures, not demonstrated plug failures. No new product patch is proposed
from this observation. The known Hue failure predates the candidate trial, as
confirmed by the separate incident investigation; powered recurrence on both
images does not prove intrinsic bulb fault or exclude all candidate effects.


## NAT64 approval package — 2026-09-13

The ordinary IPv6 control received both a correlated Matter acknowledgement and
NoSharedTrustRoots from the authorized plug. Its rejection was acknowledged on
the same UDP socket. The Python IPv4 collector subsequently exchanged an exact
UDP nonce with HA. Existing Windows rules had changed to Allow; this task did
not modify them. Collector and control implementations are integration tooling,
not changes to the published candidate or the six product contribution heads.

Proposed next trial, requiring explicit approval:

1. Verify current health, exact image digest and current authoritative data;
   take a fresh stopped-state backup and preserve complete options. Reuse the
   established in-place switch procedure and current-data fallback.
2. Install the existing 0.2.3-ordered candidate with otbr_nat64=true, preserving
   other options. Wait for Thread attachment and fresh Zigbee/Matter reports.
3. Confirm the advertised NAT64 prefix and collector path, then send one
   synthetic-source Sigma1 to the authorized plug. Save the IPv4 collector's
   correlated rejection and the response to its single reverse-path Sigma1.
4. Set otbr_nat64=false on the same candidate and restart the app. Confirm
   ordinary IPv6 control still works, then repeat the translated-source probe
   with fresh identifiers. Expect no correlated IPv4 response; verify the
   feature is disabled and no alternate translator is available before
   interpreting that absence. Never use silence alone as proof.
5. Observe fresh Zigbee and Matter traffic for ten minutes after disablement.
   If healthy, leave the tested candidate running with NAT64 off. On material
   regression, use the published baseline in the same app with evolved data;
   do not restore an obsolete volume or reset a network.

Allow roughly 30–45 minutes of agent/tool runtime, including the final observation
window, with brief Zigbee/Thread interruptions during app switches. No plug load
switching, device commissioning or firmware changes are included. A failed probe
is a diagnostic result, not permission to broaden traffic or bypass filtering.

Evidence-plan refinement: exact recorded UDP replies, unique exchange correlation,
the tested raw sender, and the same-candidate enabled/disabled comparison provide
an end-to-end behavioral test without installing privileged packet-capture tooling.
Internal translator mappings and per-rule counters are optional diagnostics if
needed to explain a failure, not prerequisites for that limited behavioral claim.
Do not claim individual rule coverage, DNS64, TCP or general Internet reachability
from this test. Existing isolated firewall evidence remains separately identified.


Pre-cutover refresh: upstream still exposes only master at 5a8d7dec; open PR78
and PR79 retain the heads recorded above. PR92 remains closed and unmerged.
All six contribution heads match their published remote branches. A focused
independent read-only review of the probe code and this approval procedure found
no material issues in correlation, bounded traffic, same-socket reverse delivery,
negative-control interpretation or current-data recovery. The reviewer did not
rerun tests; this is design/source review, not NAT64 production acceptance.
Cutover approval remains pending; no deployment followed this review.
