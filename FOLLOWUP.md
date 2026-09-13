# Follow-up contribution preparation

## Goal and authority

Prepare the concrete build-input and network-response improvements left outside
the original six contributions. Local edits, commits and isolated validation are
authorized. GitHub pushes/comments/PRs, image publication and production changes
are not authorized. The original reviewed bundle at 1ab2356 remains unchanged.

## Local contributions

| Change | Local branch head | Base / intended relationship |
| --- | --- | --- |
| Verify supplied SLC archive and mDNS source acquisition | 836c2f9 | Trixie 7c3e607; separate build-input contribution |
| Lock validated frontend dependency selection | 12eb1fe | QR e34faa6; separate frontend-build contribution |
| Reject invalid Supervisor network responses | 7b9937f | Firewall 60d3334; narrow startup error-handling contribution |

Combined product source: 97277e9 on codex/otbr-followup-integration-20260913.
Shared Dockerfile merge preserves DNS, QR, mbedTLS, mDNS and frontend-lock patch
installation. None of these local heads has been pushed.

## Evidence and current gate

- Build-input fixture accepts the reviewed SLC archive and actual pinned mDNS
  HTTPS download. Wrong/missing archive, bad checksum, untrusted TLS certificate
  and HTTP failure are rejected. The Apple tag and pinned-commit archives have
  identical 855 source entries. Independent review found no material issue.
- Frontend lock preserves all ten installed npm asset bytes from the validated
  baseline. npm7/npm9 clean installs, lock-driven rebuild and invalid-lock tests
  passed. Existing QR browser cases passed with no external requests. Independent
  review found no material issue; this is not a full-image test.
- Network-response consumer tests reproduce the old malformed-response fallback.
  All 23 corrected cases pass with real old/Trixie Bashio, curl and jq, and the
  existing lifecycle fixture passes. The merged source passed both consumer and
  lifecycle checks. Independent review checked actual Supervisor schema/Bashio
  contracts and found no material issue. Consumer tests stop before full s6 startup.
- Full AMD64 image build is running from the unchanged product Dockerfile and
  verified retained SLC archive. Results: /tmp/otbr-followup-build-20260913.
  Do not transfer original production acceptance to this modified image.

Private/local supporting evidence: /tmp/otbr-build-inputs-20260913 and
C:/Users/Kristoffer/Git/otbr/frontend-inputs/output/frontend-inputs/evidence.md.
Keep synthetic tests distinct from actual production behavior.

## AngularJS disposition

The exact locked dependency tree has ten recorded Angular advisory entries,
reported through Angular and Material. Bounded source tracing found no demonstrated
applicable trigger in the reviewed app paths. This does not prove non-exploitability.
Locking dependencies and fixing QR generation do not remediate all framework
advisories. No additional narrow fix is currently justified by the evidence.
A maintained-distribution or framework migration requires separate scope and
operator decision; do not perform a blind major dependency update.

## Deferred work

SDK/CPC/firmware updates, possible ARMv7 2038 behavior, speculative package removal,
TREL, radio-hang investigation and local HA/network changes remain separate.
Preserve the original evidence-based follow-ups: vendor clarification for closed
ARMv7 time usage; prove unused packages before removal; require a concrete upgrade
benefit and radio compatibility plan; retain Zigbee reliability findings without
inventing retry/restart fixes. Local backup completeness and verified Traefik-to-HA
HTTPS remain deployment work, not these contributions.

## Completion requirements

Finish integrated image and affected runtime/browser verification, assess any
architecture-specific evidence that needs renewal, and record exact source/image
identity and limits. Prepare a bounded production-test proposal if needed, without
executing it. Final deliverable is locally reviewable contributions and an updated
review package; upstream publication and PR79 coordination still require approval.
