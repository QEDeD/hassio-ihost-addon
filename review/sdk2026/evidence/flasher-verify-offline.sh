#!/bin/sh
set -eu
cd /bundle
apk info -v | sort > /tmp/packages-before
set --
for package in /bundle/apks/*.apk; do
 name=${package##*/}
 name=${name%-r*}
 name=${name%-*}
 if ! apk info --exists "$name" >/dev/null 2>&1; then set -- "$@" "$package"; fi
done
apk add --no-network --virtual .codex-sdk2026-flasher "$@"
python3 -m venv /tmp/codex-sdk2026-flasher
/tmp/codex-sdk2026-flasher/bin/pip install --no-index --find-links /bundle/wheels universal-silabs-flasher==1.1.0
/tmp/codex-sdk2026-flasher/bin/pip check
/tmp/codex-sdk2026-flasher/bin/pip freeze > /bundle/requirements-resolved.txt
/tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher --help
/tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher flash --help
for firmware in /bundle/firmware/*.gbl; do
 /tmp/codex-sdk2026-flasher/bin/universal-silabs-flasher dump-gbl-metadata --firmware "$firmware"
done
apk del --no-network .codex-sdk2026-flasher
apk info -v | sort > /tmp/packages-after
diff -u /tmp/packages-before /tmp/packages-after
printf 'OFFLINE_FLASHER_AND_PACKAGE_RESTORATION_PASS\n'
