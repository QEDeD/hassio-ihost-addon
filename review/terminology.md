# Use Home Assistant app terminology in user-facing text

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/ha-app-terminology-20260912`.
Exact head: `84fab103614c2eef11a0dc877fb4a12c85df6221`. Review base: `5a8d7dec067f9196ada5879f31f71cbf6d595bff`.
[Exact local diff](diffs/terminology.patch). Independent iHost PR; merge after overlapping text changes.

## Final submission text

Update documentation, English descriptions, issue-form wording, displayed workflow labels and startup messages from add-on terminology to app terminology.

Preserve technical identifiers, API/function names, repository paths and configuration keys. Issue routing accepts both old and new form labels and sentinels so existing reports remain compatible. This is a 42-file wording change with a narrow parser-compatibility adjustment; runtime policy and configuration semantics are unchanged.

Validation is source-diff review of terminology and preserved technical identifiers. Physical radio tests do not validate this wording/parser change and are not claimed as its evidence. This contribution is independent; resolve overlapping documentation and messages without discarding feature-specific instructions.

## Operator notes - do not paste

Ready for approval. Merge after overlapping text changes where practical; this is conflict management, not a functional dependency.
