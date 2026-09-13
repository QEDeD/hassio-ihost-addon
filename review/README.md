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

## Remaining decision and acceptance work

The physical NAT64 UDP trial passed. Three earlier group OFF commands returned
BUSY during an eight-second sequence of Hue remote presses. The recorded HA
automation targets that Zigbee group alongside four individual lights. This
identifies a reproducible workload, not the cause or candidate specificity. The operator also recalls similar missed first presses for approximately two to four weeks before the candidate; that is symptom history, not proof of the same BUSY error. The recorded failures occur after the remote event reached HA.

Recommendation: perform a bounded comparison of that existing remote/automation
workload on candidate and baseline before claiming full production acceptance.
It would affect the living-room lights and require another expressly approved
image switch. No such comparison or additional device command is authorized by
this review document. Alternatively, the operator may choose upstream code
review with the finding explicitly unresolved; that is not full production
acceptance and does not silently complete the existing goal.

For Trixie, first offer PR79 the credited Release/mbedTLS corrections and exact
validation evidence. Use the prepared successor branch only if that reduces
maintainer work. External comments, PR creation, release and merging require the
operator's approval; none have been sent by preparing this package.
