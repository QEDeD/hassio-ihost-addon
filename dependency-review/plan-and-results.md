# Trixie dependency review: plan and evidence

## Outcome and scope

Decide which dependency changes affect the iHost Multiprotocol add-on, identify
necessary compatibility work and worthwhile improvements, and establish the
remaining tests before recommending deployment/upstream acceptance. Keep CPC
v4.6.1 and SDK v2024.12.1-0 fixed to isolate the Debian/HA-base upgrade.
No production deployment, radio firmware change, upstream PR submission or SDK
upgrade is part of this review.

## Execution plan

1. **Account for the inputs.** Reuse the exact released/built image inventories;
   separate Debian packages, HA base additions, fixed bundled source and mutable
   downloads. Success: every package change has a disposition and build-only
   inputs absent from the final package list are also considered.
2. **Review actual overlap.** Read primary migration/release guidance across the
   intervening versions; map changed APIs, defaults, ABI and security behavior to
   actual source, compiler settings, linked libraries and service commands.
   Success: actionable findings name a consumer and evidence; irrelevant changes
   do not generate compatibility patches or a catalogue of speculative work.
3. **Test remaining high-value uncertainty.** Reuse the complete AMD64 build and
   run existing Python/firewall/s6/readiness regressions on the actual Trixie
   image. Add only focused probes for masked Python query failures, routing-table
   names and socat address-family behavior. Use disposable GitHub-hosted runners,
   inert endpoints and isolated network namespaces. Success: exact assertions
   pass or a failure is attributed to the product, fixture or environment.
4. **Integrate and decide.** Review specialist findings and fixture changes,
   preserve evidence with immutable input/run references, and distinguish
   compatibility requirements from separately valuable fixes. Success: concise
   recommendation and explicit remaining acceptance gates, without pretending
   a changelog review proves every runtime path.

The image digest, SDK/CPC revision and SLC bytes are pinned; APT repositories
and npm registry resolution are not a hermetic snapshot. Exact observed package
versions are evidence of each run, not a guarantee that future builds select
identical packages. Registry/source-lock fixes remain separate proposals.

No need to rebuild under every intermediate GCC/Python release: source migration
notes provide the compatibility filter, while the old deployed baseline and exact
target are the useful endpoints. A failed behavior comparison warrants a narrower
investigation. No benchmark project without an observed performance concern.

## Coverage

[package-coverage.csv](package-coverage.csv) accounts for all 283 literal package
names in the union of the old/new final image inventories: 161 changed, 63 added,
59 removed. ABI/package renames can represent one dependency in two rows.
The group assignment is a review index, not a claim that every base or transitive
package was independently tested or proved unused. For 117 base/transitive rows,
no direct changed application interface was identified; validate them through
actual consumers unless a release issue or test failure identifies a direct need.

Build-only GCC/G++, CMake, Make/Ninja, Java/SLC, Boost and npm, and non-dpkg s6,
Bashio and bundled libraries are covered in the accompanying reports. Package
candidate versions in the older comparison are not substituted for measured
installed versions.

- [Compiler, CMake and Python](compiler-python.md)
- [Runtime, init and networking](runtime.md)
- [Web, native web libraries and acquisition](web-build.md)
- [Initial measured inventory and source map](baseline.md)

## Additional cross-cutting assessment

OpenSSL 1.1.1 to 3.5 introduces provider/legacy-algorithm and API changes. None of
the five application linkage outputs established a direct OpenSSL dependency;
this upgrade must not be described as upgrading Thread's bundled mbedTLS. OpenSSL
and other crypto libraries can still be used by Debian tools, Python extensions,
HTTPS downloads and diagnostic paths. Do not enable the legacy provider or weaken
certificate/security settings without an actual required failing operation.
The successful build exercises acquisition, but it does not validate every TLS
endpoint; mDNS bootstrap explicitly disables certificate verification, so that
particular download is not evidence of verified TLS.
Primary reference: https://docs.openssl.org/3.0/man7/migration_guide/ .

Debian release issues also cover whole-machine upgrades and kernel changes.
This is a rebuilt container sharing its host kernel, so host bootloader/kernel
migration procedures are not applicable. ARM32 time ABI and CPU architecture
requirements still apply to native userspace and remain explicit gates.
Primary reference: https://www.debian.org/releases/trixie/release-notes/issues.en.html .

## Decisions from the review

- Continue directly with Trixie and unchanged SDK/CPC. No demonstrated compiler
  or Python incompatibility currently warrants a source upgrade, language-standard
  migration, blanket warning suppression or added Python package.
- Preserve actual frontend dependency selection in a reviewed lock as a separate
  reproducibility change. Restoring the old lock unchanged downgrades assets.
- Evaluate exact frontend advisories against browser inputs. The historical npm
  summary does not identify two CVEs or establish exploitability.
- Keep the existing external HTTP QR-service credential flow as a separate
  actionable finding; it is not caused or fixed by Debian. Source is evidence
  of the constructed request, not proof that any user executed it.
- Preserve attribution to PR79 rather than producing an unnecessary competing
  OS-upgrade patch. Carry evidence into whichever contribution is easiest to merge.

## Results and remaining gates

Initial full AMD64 build/linkage passed at 77287ce:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34707535921 .
Deeper isolated runtime audit at 6a9ee8b:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34709637929 .
The fresh build and existing Python/firewall/s6/readiness regressions passed,
independently checked against the complete CI log:

- Five Python NAT64 pool-helper unit tests under system Python 3.13.
- Mocked firewall and optional NAT64 reservation/lifecycle regressions.
- Real-kernel IPv6 firewall lifecycle, including scoped cleanup/foreign-state tests.
- Actual upgraded s6 shutdown: failure, bounded stall and finish timeout.
- Actual upgraded s6 with synthetic NAT64 daemon/control responses: off, on,
  configuration error and uncooperative-daemon shutdown.
- Actual Zigbee readiness fixture: missing listener, valid configured listener,
  foreign listener, changed port, lost daemon and failed supervisor query.
- Exact bundled mbedTLS config.py: enabled/disabled query statuses under Python 3.13.

Inherited test output says "released s6" but these disposable fixture images use
Trixie's s6-overlay 3.2.3.0. Synthetic NAT64 cases do not exercise the translator;
the real-kernel fixture here covers IPv6 firewall rules, not NAT64 traffic.
The final utility probe stopped with exit 2 querying an empty IPv6 table. This
was a fixture error, not evidence of failure to recognize the table name.
Corrective fixture commit 18ad9a2 populates an isolated table and compares socket
behavior on both the released and Trixie images. Follow-up run:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34709969928 .
**Final outcome: PASS in 5m20s at 18ad9a2.** The full build and all regression
steps passed again. Named table 88 resolved against an actual isolated IPv6
blackhole route in both images. Both generic socat listeners accepted IPv4 and
not IPv6; both generic clients accepted an IPv6 literal with an explicit TCP6
server as the positive control. No old/new difference was observed in those
forms. AAAA-only names, dual-stack name selection, radio transport and live
network behavior were not exercised.

The first run's empty-table fixture failure is retained as evidence rather than
relabelled a product defect. No application source compatibility patch was made.
Tests and review are committed on the user-owned contribution audit branch;
no upstream PR was submitted and production remains unchanged.

Still separate from the dependency review: real Bashio API error-path behavior,
web/browser and serialization acceptance, complete old/new generated-feature
comparison, enabled NAT64/DNS binary tests on Trixie, ARM builds/time ABI and
physical Thread/Zigbee coexistence. These gates are neither silently waived nor
proved by AMD64 compilation or synthetic daemon fixtures.

Operator effort for this isolated review: none required. Agent effort is the
source/evidence review and test integration; tool runtime is the CI build/test
run. Production cutover and consequential radio-state changes retain their
separate authorization boundary.

## Review closeout

The three specialist source reviews were integrated by the parent. A separate
read checked package counts, scope and evidence qualifications; the runtime log
was independently checked against the asserted coverage. The kernel shim path
and bounded utility execution were corrected before first CI. Subsequent CI
identified the empty-table fixture assumption, which was fixed and reverified.

Next smallest useful implementation acceptance step: exercise actual Bashio API
error paths and isolated web requests on Trixie, while preserving generated build
settings and frontend dependency selections. Then validate ARM and the enabled
NAT64/DNS build before preparing an approved physical coexistence trial. These
are targeted acceptance tasks identified by the completed review, not a reason
to keep rereading every dependency changelog.

## Follow-up acceptance plan: actual application interfaces

Reuse the successful lifecycle/firewall/readiness evidence above. Add two bounded
probes to the existing disposable CI runtime job, comparing the pinned released
image with the freshly built AMD64 Trixie image:

1. Installed Bashio with a loopback synthetic Supervisor: primary/missing primary,
   malformed JSON, HTTP failure, connection refusal, false/zero/missing options.
   Record actual return status and captured output in the production assignment
   context; do not classify inherited behavior as a Trixie regression.
2. Installed native otbr-web with no OT control socket or radio: exact static
   asset bytes, missing/traversal path rejection, absent-agent JSON serialization,
   malformed commission JSON, and responsiveness after errors.

Plan review: both probes use network-none read-only containers, dropped
capabilities, bounded runtime and writable temporary storage only. They exercise
actual installed consumers rather than replacing Bashio/native code with mocks.
The comparison is against endpoint versions, not every intermediate release.
Malformed commission requests cannot reach a real agent. No QR generation,
external request, credential, production mutation or service cutover is involved.

Passing results close these narrow application acceptance gaps, not full browser
interaction, successful radio-backed API calls, ARM/time ABI, enabled NAT64/DNS
traffic or physical coexistence. Only a demonstrated failure warrants another
implementation cycle. SDK/CPC stay fixed. Results will be recorded after CI.

First follow-up run at 4a422e6:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34718749383 .
The full AMD64 build, existing lifecycle/firewall/readiness regressions and utility
comparison passed. New Bashio primary/missing-primary/malformed-JSON probes ran.
The HTTP 503 assertion failed because it incorrectly required empty stdout on a
failed call; actual Bashio returned status 1 with its diagnostic on stdout.
Official Bashio v0.17.0 logs to stderr; v0.17.5 preserves original stdout in a
logging descriptor. This is an intentional logging-channel change, not evidence
that the failed call supplied a usable interface. Source references:
https://github.com/hassio-addons/bashio/blob/v0.17.0/lib/log.sh and
https://github.com/hassio-addons/bashio/blob/v0.17.5/lib/log.sh .

Correction db4aef1 requires status 1 plus the expected diagnostic on either
stream, retaining strict successful-value assertions. Independent application
probes now finish before reporting aggregate failure. The first run did not
reach native web or released-image application checks; no pass is claimed for
those cases from that run. The existing run script falls back to eth0 when
backbone_if is empty. The old/new comparison must establish whether malformed
JSON behavior is inherited before treating it as an upgrade regression.

### Follow-up outcome

PASS at db4aef1c97e284e4488588eed13fe22f123fe82e:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34719118756 .
Job runtime was 5m37s, including the fresh full AMD64 build and existing runtime
regressions. Both the pinned release and candidate passed the new probes:

- Bashio selected the first primary interface, preserved false/zero values and
  distinguished missing options. HTTP 503 and connection refusal returned status 1
  with diagnostics. The newer Bashio diagnostic uses stdout; on refusal curl also
  writes stderr. Successful interface output remained clean.
- Missing primary and malformed network JSON both returned status 0 with empty
  output in both images. The malformed case emitted a parsing diagnostic. Source
  inspection confirms an empty value would select eth0 if execution reaches the
  existing fallback; full startup was not exercised. This is inherited behavior,
  not a demonstrated Trixie regression. A separate narrow
  improvement could distinguish invalid API data from a valid no-primary result.
  No error-handling application change was added to this upgrade audit.
- Five native static-asset requests covered four distinct files and matched each
  image's own installed bytes, including the large
  Angular asset. Missing and traversal paths returned 400 without exposing passwd.
  Absent-agent QR metadata returned failed JSON; this endpoint generated no QR and
  contacted no external service. Empty/malformed commission JSON returned error 11.
  The native server remained responsive after errors in both images.

The application probes used no radio, OT control socket, Supervisor, real token,
external connectivity or writable root filesystem. Docker containers were removed
at exit. Production and upstream repositories remain unchanged.

Decision: continue with Trixie, keeping SDK/CPC fixed. No compatibility patch is
justified by these results. These tests close the narrow Bashio and native web
error-path gaps called out above; they do not close complete browser interaction,
successful radio-backed serialization, ARM/time ABI, enabled NAT64/DNS traffic,
generated-feature comparison or physical coexistence. Those are still explicit
acceptance gates, not implied by a green AMD64 run. The next useful base-upgrade
check is ARM build/ABI acceptance; optional feature acceptance remains separate.

An independent evidence review checked the final application log and production
fallback source; the report retains its distinctions between isolated execution,
source-based inference and untested live behavior.
