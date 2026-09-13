> Current disposition and authority: [reconciled package](../RECONCILIATION.md).
> The six drafts below are supplemented by three local follow-up drafts. Historical
> deployment observations below have not been repeated in this reconciliation.

# Contribution drafts for approval

These are proposed submissions, not published upstream PRs. The product branches
are published to the authorized contribution repository; integration wrappers and
probe tools are excluded from those branches. Use these six files as the current
drafts. Earlier standalone draft files outside this repository are superseded.

| Contribution | Draft | Exact head | Review relationship |
| --- | --- | --- | --- |
| Firewall lifecycle | [Draft](firewall.md) | `60d3334` | Before NAT64; new PR, not reopening #92 |
| Passive Zigbee readiness | [Draft](readiness.md) | `9536ef0` | Independent |
| Local commissioning QR | [Draft](qr.md) | `e34faa6` | Independent |
| Debian Trixie | [Draft](trixie.md) | `7c3e607` | Coordinate with PR79 first; credited successor is prepared as an option |
| NAT64/upstream DNS | [Draft](nat64.md) | `4ff1642` | Stacked on firewall `60d3334` |
| HA app terminology | [Draft](terminology.md) | `84fab10` | Last, to reduce textual conflicts |

Each draft includes its exact comparison or branch identity. The [integration
record](../INTEGRATION.md) records the assembled source, image digests, production
evidence and limitations. Historical CI is labeled with its tested source.

## Acceptance and remaining operator decision

The physical NAT64 UDP trial passed. Three earlier group OFF commands returned
BUSY during an eight-second sequence of Hue remote presses. The recorded HA
automation targets that Zigbee group alongside four individual lights. This
identifies a reproducible workload, not the cause or candidate specificity. The operator also recalls similar missed first presses for approximately two to four weeks before the candidate; that is symptom history, not proof of the same BUSY error. The recorded failures occur after the remote event reached HA.

The approved single candidate replay is now complete: the seven recorded actions
were injected at their original offsets, no new BUSY/error/warning appeared in
the captured window, saved settings were restored for all nine HA light entities,
and two representative fresh reads confirmed restored state and brightness.
All three apps remained started, and NAT64 remained disabled. See the integration
record for exact timing and evidence limitations.

This did not exercise the handheld remote's radio link or establish that every
physical transition succeeded. The earlier intermittent BUSY finding was not
reproduced and remains unresolved; candidate/baseline equivalence is not proven.
Independent evidence review found no new demonstrated candidate regression.
Recommendation: retain the historical finding as unresolved general Zigbee
reliability work; do not require another image switch solely for this finding.
Reopen candidate/baseline comparison if concrete evidence implicates these
contributions. This is a disposition of the finding, not proof of equivalence
or a claim that the historical issue is fixed. The final bundle audit is complete.

For Trixie, first offer PR79 the credited Release/mbedTLS corrections and exact
validation evidence. Use the prepared successor branch only if that reduces
maintainer work. External comments, PR creation, release and merging require the
operator's approval; none have been sent by preparing this package.


Ready for operator review: approve the proposed submissions, including offering
Trixie corrections/evidence to PR79 first. Approval of this package does not
implicitly authorize releases, merges or additional production changes.
