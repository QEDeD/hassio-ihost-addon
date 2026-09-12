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
