> Current contribution framing and permissions: [RECONCILIATION.md](RECONCILIATION.md).
> Any older publication authorization below is historical; the active task is local-only.

> Historical baseline record: this document describes the original six contributions.
> The current local branch adds un-deployed follow-ups; see [FOLLOWUP.md](FOLLOWUP.md).
> Original production acceptance does not apply automatically to the modified image.

# Upstream contribution review package

[Open the six current submission drafts and review index](review/README.md).
These supersede the standalone draft files previously kept outside this branch.

## Outcome and current gate

Six separate contributions and the combined candidate are prepared. The approved
physical NAT64 UDP test passed on the unchanged 0.2.3-ordered candidate, including
a reverse exchange and same-candidate disabled comparison. The candidate remains
running with NAT64 off; Zigbee and Thread/Matter operation passed the final
21-sample, 629-second observation and closing checks.

Isolated AMD64 checks and separately scoped ARM build/runtime checks passed as
detailed below. The approved lighting replay did not reproduce the earlier BUSY
failure; independent review found no demonstrated candidate regression and
retained the historical symptom as unresolved general Zigbee reliability work.
The six contribution heads and final evidence have been reconciled. The package
is ready for operator review and approval of upstream submission, with the
explicit limitations and contribution order below. This is not a release or a
claim that every historical device issue is fixed.

No upstream PR has been submitted, released or merged. Git pushes and test-image
publication to the approved QEDeD destinations are authorized through September
27, 2026. Further production changes remain subject to their applicable authority.
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
was used. The initial baseline direct state read succeeded. All 16 samples over 15 minutes retained the initial 109 unavailable entities; the affected light stayed available and Matter CO2 report age remained below 24 seconds. The last unsolicited light report was near the end of the window. A final GET was accepted, but no newer response was captured: final active-read verification is inconclusive. No BUSY appeared in the captured baseline log, but equivalent group-command traffic was not established. A subsequent baseline log captured two failed pings and the same light going offline at 13:51:47 CEST. Core then confirmed the same four-entity availability loss (113 unavailable total), with all apps started and continuing Matter reports. The earlier healthy interval does not establish sustained recovery. This shared symptom does not demonstrate a candidate-specific regression, although differing rates or causes remain possible. That earlier comparison ended on baseline; the later approved NAT64 trial described below leaves the candidate running with NAT64 off. Group-command evidence remains unresolved.
Raw logs, backups and identifying device details are retained privately outside
Git/CI under `/tmp/otbr-ordered-trial-20260913`.

## Acceptance disposition and review

The agreed bounded AMD64 production trial, controlled restart, physical NAT64
UDP comparison, and approved lighting replay are complete. The light dropout
occurred on both images. The separate BUSY finding was not reproduced; its
reviewed disposition is recorded below. Neither establishes a candidate-specific
regression, nor proves identical failure rates or causes across images.

Independent source, integration-boundary, shutdown-order and final evidence
reviews have no unresolved material contribution finding. The initial baseline
final-read claim was corrected after timestamp review; that read remains
inconclusive and is not counted as successful evidence. Current contribution
heads match the tested source through ancestry or explicitly checked file
comparisons, not invented exact-head CI claims.

Physical ARM radio behavior, host-reboot ordering, TCP/DNS64/general Internet
NAT64 behavior and universal downgrade safety are not established. Firewall
ownership retains the documented single-OTBR assumption. Preserve current
network data for recovery, including Zigbee2MQTT's external database directory.
SDK/CPC/firmware upgrades, TREL and unrelated radio-hang investigation remain
outside this bundle. The remaining gate is operator review and approval before
upstream submission; no upstream comment, PR, release or merge has been made.

## Group-send evidence limit

Zigbee2MQTT 2.14.1 declares zigbee-herdsman 10.9.2. In the matching
[Ember adapter source](https://github.com/Koenkk/zigbee-herdsman/blob/v10.9.2/src/adapter/ember/adapter/emberAdapter.ts),
`sendZclFrameToGroup` throws on non-OK status immediately, whereas unicast sends
have bounded BUSY retry handling. This identifies the reporting path, not the
cause of radio BUSY. No change to this separate dependency is proposed. The
retained pre-candidate and baseline Zigbee log captures did not contain BUSY;
unequal traffic and rolling capture prevent treating absence as a controlled
comparison. HTTP acceptance of an MQTT publish is not proof of a Zigbee response.

## Additional physical Thread control â€” 2026-09-13

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


## NAT64 approval package â€” 2026-09-13

The ordinary IPv6 control received both a correlated Matter acknowledgement and
NoSharedTrustRoots from the authorized plug. Its rejection was acknowledged on
the same UDP socket. The Python IPv4 collector subsequently exchanged an exact
UDP nonce with HA. Existing Windows rules had changed to Allow; this task did
not modify them. Collector and control implementations are integration tooling,
not changes to the published candidate or the six product contribution heads.

The following trial procedure was subsequently explicitly approved and executed:

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

Allow roughly 30â€“45 minutes of agent/tool runtime, including the final observation
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
That review preceded the explicitly approved deployment and results below.

## Completed NAT64 trial â€” 2026-09-13

The published 0.2.3-ordered image was installed in the same app, retaining current
radio data and complete options. Both candidate and fallback registry digests
were rechecked before installation. Only otbr_nat64 was enabled for the test.
The existing physical GRILLPLATS plug returned its correlated CASE rejection to
the IPv4 collector; a fresh Sigma1 sent through that collector's same socket
obtained another correlated rejection. Independent byte-level review confirmed
both exchanges, request counters, destination identities and exact status bodies.
Six enabled network-data observations advertised the NAT64 /96 route.

The same candidate then restarted with otbr_nat64=false. An ordinary IPv6 probe
still obtained the expected rejection. A fresh translated-source probe produced
no IPv4 response within the collector's 30-second limit; seven network-data
observations showed no advertised NAT64 route. This is the limited UDP behavioral
comparison described above, not TCP, DNS64, per-rule coverage or general Internet
acceptance. No device load switch, commissioning or firmware change was performed.

After disablement, all three apps stayed started across 21 samples over 629
seconds. The Zigbee bridge remained connected, and CO2 readings included 14
distinct values. A closing Zigbee GET received a new device state publication;
all four Matter nodes remained available and the tested plug remained off.
The candidate's controlled shutdown recorded OTBR exit 0 and CPC exit 0.
The candidate remains running with NAT64 off. Temporary probe executables and
collector sockets were removed/closed.

The baseline stop again exhibited the already-recorded OTBR exit 141 followed by
complete s6 shutdown. An initial strict stop assertion restored the baseline;
Zigbee2MQTT required starting after radio readiness. Subsequent Supervisor update
and start responses were ambiguous despite eventual successful state readback.
These management-harness observations are not evidence of a new candidate radio
regression, nor justification to accept unknown shutdown failures.

Recovery record correction: fresh stopped partial backup 524be610 verified both
nonempty authoritative radio state files. Zigbee2MQTT stores its database under
/config/zigbee2mqtt, outside its partial app archive. That external data remained
in place throughout. A supplemental live file copy of its database, coordinator
backup and configuration was retained only on HA under
/backup/codex-zigbee-live-copy-20260913-nat64.tar. It is not a stopped-state snapshot.
Future stopped-state backup procedures must include this external directory.
Fallback must continue using evolved data; neither archive authorizes restoring
obsolete network state. No secrets or raw private packet/log evidence enter Git.

Private evidence is retained under /tmp/otbr-nat64-approved-20260913 and the local
nat64-live-enabled-traxbxt8 / nat64-live-disabled-yvd3is2c evidence directories.
Only integration documentation and test tooling changed after product commit
aca557b6eb851af109a2708f55b5b2668314818f; the six contribution heads are unchanged.
Independent closing-evidence review verified all 21 health samples, the final
Zigbee request/response timestamps and availability of all four Matter nodes.
It supports this trial closeout, not resolution of the earlier group BUSY issue.


## Group-command comparison plan (subsequently executed below)

Focused review of the retained failure log ties all three BUSY responses to
group 1 OFF commands at 13:21:05, 13:21:07 and 13:21:13 during Hue remote presses.
The recorded automation targets that group alongside four individual lights.
This identifies the workload; it does not prove overload, duplicate commands,
a candidate regression or physical recovery from optimistic state publications.
The next proposed check is one replay on the current candidate, with NAT64 off:
OFF, OFF, OFF, ON, OFF, OFF, ON at offsets 0, 2, 4, 6, 8, 13 and 15 seconds.
It requires explicit approval to actuate the affected living-room lights.
Immediately before execution, capture the physical lights' current settings
using HA's temporary scene capability; restore those settings afterward and
verify readback. Abort if target availability or configuration differs materially,
radio health degrades, or restoration fails. Capture trigger timestamps, command
errors and fresh physical-device responses; do not infer success from optimistic
state alone. Do not automatically repeat the sequence or switch images.

A single clean replay does not rule out an intermittent regression. Its evidence
will determine whether further observation or a separately approved baseline
comparison is worthwhile. No replay or additional image switch is authorized
by this record. Preparing an upstream review with the finding unresolved is an
operator option, not an implicit waiver of full production acceptance.

Operator history: the operator recalls intermittent first-press failures over
the preceding roughly two to four weeks, before this candidate deployment.
This is reported symptom history, not archived proof of the same BUSY status.
For the three retained failures, the remote action reached HA before the group
command returned BUSY. A missing remote event therefore does not explain those
three cases. Treat a pre-existing control problem as plausible; do not label it
a demonstrated candidate regression or assume the earlier symptom has one cause.
The unresolved question for bundle acceptance is candidate-specific worsening,
not whether this contribution must cure every historical remote-control failure.


## Approved single lighting replay — 2026-09-13

On unchanged candidate 0.2.3-ordered with NAT64 off, seven MQTT action messages
replayed the recorded automation workload once at 17:18:26–17:18:41 CEST.
The OFF/OFF/OFF/ON/OFF/OFF/ON offsets were 0, 2, 4, 6, 8, 13 and 15 seconds.
The live automation matched the saved configuration before execution. This
injected events at MQTT; it did not exercise the handheld remote's radio link.

The captured window contained 78 new Zigbee2MQTT log lines and no error,
warning or BUSY match. Intermediate HA snapshots were sometimes mixed while
commands propagated; optimistic publications do not prove every physical
transition. All nine physical-light entities matched their saved on/off,
brightness, active color mode and color values after temporary-scene restoration.
The temporary scene was deleted. Fresh GETs to a group member and a separate
bulb were followed by publications at 17:18:56 and 17:18:59 confirming their
restored ON states and brightness values 1 and 76 respectively. These are
representative readbacks, not independent observation of all nine light outputs.

All three apps remained started afterward; the candidate version was unchanged
and otbr_nat64 remained false. Private evidence is retained under
/tmp/otbr-group-replay-20260913. No image switch or repeated replay was performed.
The previous BUSY error was not reproduced. A single clean run does not exclude
intermittent failure or establish candidate/baseline equivalence. The historical
finding remains unresolved; this result provides no new demonstrated regression.


Independent read-only review verified the seven recorded injection offsets,
seven corresponding group publications, nine matching restored HA light states
and the two representative request/publication pairs. Scheduling drift was under
0.5 ms at the pre-API timestamps; those are not radio-transmission timestamps.
The reviewer found no new demonstrated material candidate regression.

Disposition: retain the earlier BUSY finding as unresolved general Zigbee
reliability work. The reported pre-candidate symptom history and this bounded
non-reproduction do not justify making another disruptive image comparison
mandatory by themselves. Reopen comparison if concrete evidence implicates the
contributions. This does not establish candidate/baseline equivalence, cure the
historical problem, or replace the remaining bundle-wide completion audit.


## Final bundle audit — 2026-09-13

- All six published heads match the review index. Independent provenance review
  checked ancestry or exact product-file transfer into aca557b, including shared
  Dockerfile resolutions. Subsequent commits change evidence/drafts/probe tools
  only; the tested product source is unchanged.
- Retained build success/source records identify aca557b and its clean source
  hashes. Build, linkage, runtime and packaged s6 records support the isolated
  results. Existing synthetic browser and independent source reviews remain
  applicable; no product change invalidated them.
- Production records retain 31 initial samples and 11 post-restart samples with
  changing Matter readings, followed by the independently reviewed NAT64 trial
  and 21-sample/629-second disabled health window. The additional approved
  lighting replay and restoration were independently reviewed separately.
- GitHub confirms the successful AArch64/ARMv7 run at 11bef36. The later mDNS
  graph edge has separate AMD64 evidence; this is not physical ARM acceptance.
- Backup/data-continuity limitations, initial baseline findings, feature coverage,
  upstream overlap/attribution and merge dependencies remain explicit. Six draft
  PR descriptions now agree with the resulting evidence and finding disposition.

The preparation and bounded validation objective is complete. The operator's
next decision is approval of the proposed submissions and the PR79 coordination
route, not authorization for an automatic release or further production testing.
