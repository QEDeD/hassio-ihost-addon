# Frontend input locking — local evidence, 2026-09-13

## Decision and exact selection

Preserve the tested frontend selection, including the existing local QR patch,
and make CMake enforce its lock. SDK remains da661283f301b53eec04d1016009e60bc7e34a1f.
Angular/animate/aria/messages 1.8.3; Angular Material 1.2.5; D3 3.5.17;
Material Design Lite 1.3.0; qrcode-generator 2.0.4. All 10 installed npm JS/CSS
assets are byte-identical to retained combined-build frontend assets under
/tmp/otbr-local-build.XYn1ut/combined-frontend. No historic generated lock survived
in the inspected retained directories: generated candidate resolution was accepted
only after that asset comparison. This is asset equivalence, not independent
verification of the old npm metadata or a new full native/container build.

A proportionate current upstream check found OpenThread main still copies only
package.json and runs npm install. No suitable existing locking fix was found in
that checked file. https://raw.githubusercontent.com/openthread/ot-br-posix/main/src/web/web-service/frontend/CMakeLists.txt

The separate 0002 patch updates the pinned SDK's stale lock, copies both inputs,
uses npm ci --ignore-scripts, and depends on both source inputs. Version-2 lock
format supports npm7. Packages supply prebuilt assets; lifecycle scripts are
unneeded. This does not freeze OS packages, npm versions or registry availability.
The integrity fields protect downloaded package bytes; npm audit remains enabled.
https://docs.npmjs.com/cli/v9/commands/npm-ci/

## Local verification

Scratch: /tmp/otbr-frontend-inputs-20260913 (WSL).
- Existing prepare.py: baseline build then fresh locked CMake build/install plus
  controller assertions passed. CMake 3.31.6, Ninja 1.13.0, npm9.2.0; initial Node
  was 24.18.0. Exact Trixie Node20.19.2 used for subsequent lock behavior checks.
- check-lock.py: passed with Node20.19.2 + npm9.2.0 and + npm7.5.2. Checks source
  inputs unchanged, lock-only incremental rebuild, manifest mismatch failure,
  corrupt lock failure, missing lock failure, restoration and identical assets.
  This is npm7 compatibility evidence, not a full historical Node12 build.
- Existing browser-check.js using Playwright CLI, installed Chromium, and actual
  locked frontend: 6/32-character QR payloads decoded at 1000/360px widths;
  repeat payload changed; missing/throwing encoder and hostile-input tests passed;
  seven local QR requests; zero external request attempts. Initial fixture favicon
  request 404 is unrelated to tests. Browser/server were closed after test.
- git diff --check passed.

Reproduction: put scratch tools/cmake/data/bin, tools/bin and the selected npm
prefix node_modules/.bin on PATH; set PYTHONPATH to scratch/tools. Node20 executable
is node20-tools/node_modules/.bin/node. Run:
  python3 tests/qr/prepare.py NEW_EMPTY_SCRATCH
  python3 tests/qr/check-lock.py NEW_EMPTY_SCRATCH
Browser uses existing tests/qr/serve.cjs and browser-check.js per README, with
/tmp/otbr-local-build.1KZZGI/qr-tools/node_modules/.bin/playwright-cli and config
/tmp/otbr-local-build.XYn1ut/browser-config.json. Browser library directory:
/tmp/otbr-local-build.1KZZGI/browser-libs/extracted/usr/lib/x86_64-linux-gnu.

The new lock changes no measured installed dependency assets. This run did not
build the full image, exercise all browser pages, operate radios, use real PSKds,
contact production, push Git, post to GitHub, or publish images. Prior independent
full-image tests are not newly established by this check.

## Exact AngularJS advisory inputs and disposition

Fresh npm9 audit of this exact tree is saved as audit.json; npm ls as npm-ls.json.
Two affected package records: Angular high; Material moderate propagated via
Angular. Angular has ten underlying advisory records. This is a current report,
not proof these were the exact advisories in historical CI's two-warning summary.
The proposed npm fix for Material is 0.8.0 (major rollback), not a justified
remediation. No audit fix was run.

Read app.js, index.html, join.dialog.html from the pinned SDK plus QR patch, and
relevant installed Angular source. This is bounded input/reachability analysis,
not an exhaustive framework audit or proof of non-exploitability. All ten reports
list no patched public angular version. Keeping the dependency lock preserves
these package warnings; Node/OS updates and removal of npm do not patch browser JS.

| Advisory | Necessary input/context | Observed application flow and disposition |
|---|---|---|
| [CVE-2022-25869](https://github.com/advisories/GHSA-prc3-vjfx-vhm9) | IE cache/interpolated textarea | No textarea in application templates; browser validation used Chromium, not IE. Trigger not identified. |
| [CVE-2025-0716](https://github.com/advisories/GHSA-j58c-ww9w-pwp5) | SVG href/xlink image source sanitization | No bound SVG image URL found in application. D3 uses text for network labels. Does not prove every Material internal SVG case unreachable. |
| [CVE-2022-25844](https://github.com/advisories/GHSA-m2h2-264f-f486) | Attacker-controlled custom locale NUMBER_FORMATS pattern | No locale override or path from API/form values to locale rules found. Trigger not identified. |
| [CVE-2024-8372](https://github.com/advisories/GHSA-m9gf-397r-hwpg) | srcset sanitization | No srcset/ng-srcset in application templates. Actual images use ng-src. Trigger not identified. |
| [CVE-2024-8373](https://github.com/advisories/GHSA-mqm9-c95h-x2p6) | source element srcset | No source/srcset flow found. Trigger not identified. |
| [CVE-2024-21490](https://github.com/advisories/GHSA-4w4v-5hc9-xrr2) | Large crafted ng-srcset | No ng-srcset flow found. Trigger not identified. |
| [CVE-2023-26116](https://github.com/advisories/GHSA-2vrf-hf26-jrp5) | Crafted input to angular.copy; installed copyType RegExp branch parses source.toString() | No direct copy or RegExp construction in app. Forms/JSON do not construct RegExp objects. Internal framework copies exist; exhaustive internal reachability not claimed. |
| [CVE-2023-26117](https://github.com/advisories/GHSA-2qqx-w9hr-q5gx) | Crafted $resource input | angular-resource is neither installed nor loaded; app uses $http with fixed local endpoint names. Trigger not identified in delivered frontend. |
| [CVE-2023-26118](https://github.com/advisories/GHSA-qwqh-hm9m-p5hr) | Large crafted URL input validator | No input type=url in app templates. Existing text/password controls do not invoke that validator by their declared types. |
| [CVE-2026-11998](https://github.com/advisories/GHSA-7x27-g8rg-x87w) | SCE resource-URL regex matcher policy bypass | No custom SCE matcher configuration; join template URL is literal join.dialog.html. No API-controlled script/iframe/template resource URL found. Trigger not identified. |

Actual dynamic image bindings are status item.icon (assigned the fixed local
res/img/icon-info.png in app.js) and qrImage (local encoder result in a constant
Angular template). QR adversarial fixture confirms supplied text remains QR data
in that tested flow. It does not establish blanket safety of all Angular flows.

No new focused remediation is justified by these observed inputs. The existing QR
patch already removes the concrete remote credential-image/template-concatenation
flow; it is distinct from fixing these framework CVEs. If complete removal of
AngularJS package advisories is an acceptance requirement, select a maintained
replacement or separately review a maintained patched distribution with its
licensing and compatibility implications. That is a separate material dependency
migration decision, outside this bounded locking change. No zero-risk claim.