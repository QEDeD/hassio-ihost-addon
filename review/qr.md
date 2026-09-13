# Generate OTBR commissioning QR codes locally

Current head: `e34faa674de908f1e208eb71be2f129d7c48636d`. [Focused comparison](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/compare/5a8d7dec067f9196ada5879f31f71cbf6d595bff...QEDeD:e34faa674de908f1e208eb71be2f129d7c48636d). Product implementation remains f721b35; later commits update terminology and exercise the hostile-input browser case through the real UI click.

The OTBR web UI's Join form lets the border router itself join an existing
Thread network using a user-entered PSKd. Its Get Connect QR Code action
combines that PSKd with the local radio's EUI-64 and builds an external HTTP
QR-image request to api.qrserver.com. This is not the printed Matter setup QR
used to commission accessories such as ALPSTUGA. This change generates the image in the browser
with a bundled, exact-version QR encoder, preserving the existing commissioning
payload without sending it to a third-party image service.

The SDK patch uses the existing npm/CMake asset pipeline, retains the encoder's
MIT license, and binds the image through a fixed Angular template. Missing or
failing encoding shows the existing generic alert with no external fallback.
Debian, SDK and unrelated frontend dependency versions are unchanged.

Validation at f721b35:
https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34712451150

- Patch applies to SDK da661283f301b53eec04d1016009e60bc7e34a1f.
- Actual frontend CMake build/install and controller regression tests pass.
- Chrome screenshot pixels independently decoded by jsQR match the exact payload
  for 6- and 32-character PSKds, including leading-zero/mixed-case EUI, at 1000
  and 360 pixel viewport widths.
- Reopening changes the image; hostile text remains data; missing/throwing encoder
  paths show the generic alert. No synthetic credential is logged.
- Seven QR attempts produced zero external browser request attempts.

The viewport checks exercise the QR dialog; they do not redesign the existing
fixed-width join form. This individual frontend fixture does not establish production deployment or a physical commissioner scan.

Combined-image validation is recorded in the [integration evidence](../INTEGRATION.md). The unchanged 0.2.3-ordered image passed the physical NAT64 UDP enabled/disabled comparison and the final 21-sample, 629-second health observation; it remains running with NAT64 off. The earlier light dropout also occurred on baseline. Three earlier group-command BUSY failures still lack a controlled comparison or explicit acceptance disposition. ARM build/linkage/native-web checks passed at integration 11bef36 in [CI34749205311](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34749205311); this is not physical ARM radio acceptance. Combined-image evidence must not be presented as CI executed at this individual contribution head.

Status: committed and pushed to codex/local-commissioning-qr-20260912 on contrib;
not submitted as an upstream PR. An earlier combined trial reverted to baseline for comparison. The later approved trial leaves the unchanged candidate running with NAT64 off. The QR flow itself was tested with synthetic credentials in isolated browser tests.

Commissioning semantics verified against the pinned SDK source:
- `frontend/join.dialog.html` takes `thread.pskd` from the Join form.
- `frontend/res/js/app.js` combines that value with `get_qrcode`'s EUI-64.
- `wpan_service.cpp`, `HandleGetQRCodeRequest`, reads the local interface's
  `eui64`; `HandleJoinNetworkRequest` runs `joiner start` with the supplied PSKd.
- The QR contains neither the Thread network key nor a Matter setup passcode.

Source: https://github.com/SiliconLabs/simplicity_sdk/blob/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/src/web/web-service/wpan_service.cpp

Follow-up review: this clarification changes the issue description, not the
payload-preserving fix. The historical successful CI tests f721b35ba1f0abd1684377f666e6003301570c62; the current review head is identified above. No additional production test or
credential rotation is justified by this source inspection alone. Upstream
submission remains subject to operator review and approval.

This change is independent of firewall/readiness/NAT64. Preserve both QR and DNS patch-installation steps when resolving the shared Dockerfile during merge.

The earlier integrated artifact passed two local browser runs with the corrected test at e34faa6. Ordered candidate 0.2.3-ordered (source aca557b) separately passed four viewport/payload combinations, two encoder failures, hostile input rendered as data and zero external requests. Product code was unchanged by the test correction.
