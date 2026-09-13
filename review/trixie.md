# Offer Release and mbedTLS corrections for PR79

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/trixie-ready-20260913`.
Exact head: `7c3e6076e5f84995ac8b881aea4b4f12855a1e10`. Review base: `5a8d7dec067f9196ada5879f31f71cbf6d595bff`.
[Exact local diff](diffs/trixie.patch). Offer corrections to PR79; no competing PR by default.

## Final submission text

Two separately reviewable corrections are available for this Trixie upgrade:

- Select `CMAKE_BUILD_TYPE=Release` on the OTBR CMake invocation. The earlier `RELEASE=1` environment on bootstrap did not select that later build type. An isolated ARM compiler probe reproduced an unoptimized inline-assembly constraint failure in the pinned mbedTLS; optimized compilation passed. Release intentionally changes optimization/assertion settings, not just package versions.
- Backport [Keith Packard's mbedTLS correction 292b96c](https://github.com/Mbed-TLS/mbedtls/commit/292b96c0a69016a6d99ce324837a9e96d59e21f6) for the GCC XOR array-bounds diagnostic, retaining attribution and adapting SDK paths/context.

The [two-correction diff](https://github.com/QEDeD/hassio-ihost-addon/compare/4e3570772c377d8c8104ea73bd272f1a431ec807...7c3e6076e5f84995ac8b881aea4b4f12855a1e10) follows an unchanged application of this PR's two-file patch. The commits are 494becb and 7c3e607; CPC, SDK and radio firmware remain fixed. This is offered for incorporation into PR79, rather than as a competing upgrade proposal.

[AMD64 investigation CI](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34719118756) passed a complete build and runtime/native-web comparison at db4aef1. [Separately corrected ARM build/linkage/native-web evidence](https://github.com/QEDeD/hassio-ihost-addon/blob/c46ddf9ab9627b43feafaf349c33619ada1c71c2/dependency-review/arm-acceptance.md) and the [combined production record](https://github.com/QEDeD/hassio-ihost-addon/blob/1ab23561d56a711a1293af45c564d045c4941e02/INTEGRATION.md) provide additional qualified evidence. The extracted three product files match the investigated source; these are historical-source results, not exact-head CI on the extracted branch or physical ARM radio acceptance.

Would incorporating these corrections and linking that evidence here be useful?

## Operator notes - do not paste

This final text is a proposed comment on PR79, not a new PR body. Send only after operator approval. [Exact correction-only diff](diffs/trixie-corrections.patch); the full Trixie diff preserves explicit credit to Arno500. Build-input verification remains a separate follow-up. No promise of ongoing maintenance is made.
