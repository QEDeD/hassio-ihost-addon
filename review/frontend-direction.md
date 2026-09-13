# Proposed discussion on OpenThread RFC3382 — not posted

The legacy GUI still depends on end-of-life AngularJS and AngularJS Material.
A small frontend replacement could remove that dependency while retaining the
existing administration and diagnostic workflows. RFC3382 already proposes UI
modernization; PR3542 explores streaming on the current HTTP implementation, so
the final server architecture appears open.

Before developing a replacement, is somebody already working on the frontend,
and would a separately reviewable frontend contribution be welcome? Could it
initially target the existing REST API rather than wait for server consolidation?
Are there preferred frontend libraries, build-tool constraints or expectations
for ongoing maintenance that should guide a proposal?

A proposal would preserve current features, including the newer ePSKc panel,
configurable API addressing and HTTPS behavior, and include workflow regression
tests. Locally served assets and a small dependency set would be priorities.
No framework choice or implementation commitment has been made.

Context: https://github.com/openthread/ot-br-posix/issues/3382
Related: https://github.com/openthread/ot-br-posix/pull/3542

Operator note: the older Silicon Labs SDK in the iHost image does not provide
all those current APIs. An eventual upstream frontend and a downstream backport
need separate compatibility decisions. This discussion does not authorize either
implementation, a promise of long-term maintenance, or publication.
