# Accepted firmware artifacts

Retained on 20 September 2026 from the accepted normal build. These are offline
build outputs, not data read from the production radio. No keys, network stores or
private logs are included. Originals remain in the ignored build-output directories.

[manifest.json](manifest.json) records stored and uncompressed SHA256 values and
original paths. GBL is directly usable as an artifact; ELF and map use standard gzip.
Verify both stored and decompressed hashes before analysis. Retention does not
qualify flashing or rollback: read [EXECUTION.md](../EXECUTION.md) and the
[accepted result](../FULL-FUNCTIONAL-RESULT-20260920.md) first.

Source/recipe: [receive-fix](../firmware/receive-fix/README.md), including pinned
builder, source guards, packaging and independent validation. Preparation evidence
is historical; the accepted result supersedes its unflashed status. The parent
[checkpoint](../CHECKPOINT.md) explains reproduction and cross-repository ownership.
