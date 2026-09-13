# Generate commissioning QR codes locally in the pinned SDK

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/local-commissioning-qr-20260912`.
Exact head: `e34faa674de908f1e208eb71be2f129d7c48636d`. Review base: `5a8d7dec067f9196ada5879f31f71cbf6d595bff`.
[Exact local diff](diffs/qr.patch). Independent iHost PR; credits OpenThread PR3449.

## Final submission text

The bundled OTBR web UI sends the Join form's PSKd and the local radio's EUI-64 to api.qrserver.com over HTTP when generating a commissioning QR image. Generate that image locally using bundled qrcode-generator 2.0.4, preserving the payload and avoiding the external request.

This QR identifies the border router as a Thread joiner. It is not an accessory's printed Matter setup QR and does not contain the Thread network key or a Matter setup passcode.

[OpenThread PR3449 by LJspice](https://github.com/openthread/ot-br-posix/pull/3449) already added local generation upstream. This independently implemented equivalent targets the older Silicon Labs SDK actually built here; it is not a literal cherry-pick. Additional refinements include a four-module quiet zone, responsive intrinsic sizing, a fixed Angular template with dialog locals, removal of the response log and installation of the encoder's MIT license. Missing/failing encoding shows the generic alert without an external fallback.

[Historical CI at f721b35](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34712451150) verifies patch application to SDK da661283, the actual CMake frontend build/install, controller behavior and browser rendering. Independently decoded screenshot pixels match short/long PSKds at desktop/mobile widths; failures remain local and seven QR attempts make zero external requests. The final hostile-input test correction was rerun locally through the actual UI click and against the ordered combined image; product behavior did not change.

These tests use synthetic credentials and do not establish a physical commissioner scan. The existing fixed-width Join form and AngularJS advisories are outside this change. No SDK, radio-firmware or unrelated frontend dependency upgrade is included.

## Operator notes - do not paste

Ready for approval, independent of runtime fixes. The separate frontend-lock contribution depends on this patch. Preserve both QR and DNS patch installation when resolving shared Dockerfile changes. Historical deployment details remain in INTEGRATION.md; this draft makes no current-live-state claim.
