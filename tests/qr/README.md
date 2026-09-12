# Local commissioning QR regression checks

The app patch targets SiliconLabs/simplicity_sdk commit
`da661283f301b53eec04d1016009e60bc7e34a1f`, under
`util/third_party/ot-br-posix/src/web/web-service/frontend`.
It is applied in the existing SDK patch stage of the multiprotocol Dockerfile.

The change keeps `v=1&&eui=<original eui64>&&cc=<original PSKd>` unchanged,
including casing and leading zeros, and replaces the remote image URL with a
locally generated GIF data URL. The exact dependency is `qrcode-generator@2.0.4`
(verified with `npm view qrcode-generator version`). It has no dependencies.
The existing CMake npm asset list installs `dist/qrcode.js`; `index.html` loads
it before `app.js`. The encoder's notice remains in the unminified script and
its full MIT license is installed through `res/js/qrcode.LICENSE.txt`.
The license text comes from the encoder project's LICENSE and matches its MIT
package metadata. No package lock or unrelated dependency versions are changed.

Encoding uses automatic QR version selection, Byte mode, L error correction,
six pixels per module and a four-module white quiet zone. The dialog uses
natural raster dimensions, responsive max-width, and pixelated scaling. A
constant Angular template binds a per-dialog local image value. The existing
generic QR alert handles a missing or throwing encoder; no remote fallback or
credential logging remains in the QR controller.

## Local checks

Fetch the four modified frontend files (CMakeLists.txt, package.json,
index.html, res/js/app.js) from the pinned SDK to a scratch SDK-shaped tree,
then apply the patch with `patch -p1` at that tree's root. The patch also adds
the license file. Obtain the pinned encoder with `npm pack qrcode-generator@2.0.4`
and extract its tarball; no full SDK checkout is necessary for controller checks.

```
node tests/qr/check.cjs FRONTEND_DIR QRCODE_PACKAGE_DIR/dist/qrcode.js
```

The test executes the actual patched join dialog controller in a VM with API
and dialog stubs. It checks exact payloads with six- and 32-character valid
PSKds, zero/leading-zero and mixed-case EUIs, hostile input staying out of the
template, fixed local request paths, error handling, real encoder raster
output, and different subsequent credentials producing separate dialog locals.
It does not claim browser rendering, scanning, Angular safety, or Docker build
coverage by itself.

## Browser acceptance

Use the actual patched frontend with its npm-installed Angular dependencies,
and mock only the local get_qrcode response. Decode the rendered QR at its
actual displayed dimensions for six- and 32-character valid PSKds and a zero
EUI; compare the decoded text exactly. Repeat with different credentials and
check no stale QR remains. Record request attempts and reject any external QR
request, including blocked attempts. Exercise hostile strings containing HTML
and Angular expressions and verify they are never executed. Remove the encoder,
then replace it with a throwing encoder, and verify the generic visible alert
and absence of credential logging or remote fallback. Check narrow and desktop
viewports for clipping and a readable QR. Real hardware scanning and final
container integration require their own explicit evidence.

## Current local evidence

- Patch dry-run against the pinned original frontend: passed.
- Controller regression checks with qrcode-generator 2.0.4: passed.
- Actual CMake frontend build and install: passed locally with CMake 3.31.6.
- Chrome browser with CMake-installed assets: decoded screenshot pixels match
  the payload for 6/32-character PSKds at 1000/360-pixel viewports; repeat QR
  generation, missing/throwing encoder and hostile-text cases passed. Seven
  synthetic QR attempts produced zero external request attempts.
- QR opening animations are completed for screenshot decoding. Viewport tests
  open the unchanged fixed-width join form at desktop size, then resize the QR
  dialog; this does not claim a mobile join-form redesign or physical scan.
- Full native-container and real commissioner-device scanning are not claimed.

Scratch downloads and patched source belong under `output/` and must not be
staged. The delivery consists of the Dockerfile, the SDK patch, and these tests.

## Reproducible isolated browser harness

On Linux/WSL with Python 3, patch, CMake, Ninja or Make, and Node/npm on PATH:

```sh
python3 tests/qr/prepare.py /tmp/qr-frontend-check
npm --prefix /tmp/qr-test-tools install --ignore-scripts --no-audit --no-fund @playwright/cli@0.1.19 jsqr@1.4.0
node tests/qr/serve.cjs /tmp/qr-frontend-check/install/share/otbr-web/frontend /tmp/qr-test-tools/node_modules/jsqr/dist/jsQR.js
```

The preparation directory must be new or empty. The script downloads only five
pinned SDK files, dry-runs and applies the patch, builds and installs through the
actual frontend CMake target, and runs the controller checks on installed assets.
The server listens only on `127.0.0.1:18764`. Its fixture uses the actual installed
Angular/app/QR assets and join dialog, plus a test-only jsQR decoder. The backend
response is synthetic; it never contacts a Home Assistant or OTBR instance.

With Chrome already installed, use another terminal:

```sh
/tmp/qr-test-tools/node_modules/.bin/playwright-cli -s=qr-check open http://127.0.0.1:18764 --browser chrome
/tmp/qr-test-tools/node_modules/.bin/playwright-cli -s=qr-check run-code --filename tests/qr/browser-check.js
/tmp/qr-test-tools/node_modules/.bin/playwright-cli -s=qr-check close
```

Stop the loopback server when finished. The workflow `local-commissioning-qr.yml`
runs these checks with a 15-minute limit and automatic server/browser cleanup.
It does not build the native app, deploy it, or upload screenshots/artifacts.
