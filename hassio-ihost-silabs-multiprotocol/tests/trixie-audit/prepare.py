#!/usr/bin/env python3
"""Instrument only immutable acquisition/identity checks in PR79's Dockerfile."""
import os
from pathlib import Path

path = Path(os.environ["AUDIT_CONTEXT"]) / "Dockerfile"
text = path.read_text()
def replace_once(old, new):
    global text
    assert text.count(old) == 1, old
    text = text.replace(old, new)
replace_once("debian:trixie AS cross-builder-base", os.environ["BUILDER_IMAGE"] + " AS cross-builder-base")
replace_once("&& curl -O https://www.silabs.com/documents/login/software/slc_cli_linux.zip",
             "&& echo '" + os.environ["SLC_SHA256"] + " /usr/src/slc_cli_linux.zip' | sha256sum -c -")
replace_once("&& mkdir $CPCD_DIR/build", "&& test \"$(git -C $CPCD_DIR rev-parse HEAD)\" = " + os.environ["CPC_REVISION"] + " \\\n    && mkdir $CPCD_DIR/build")
replace_once("&& cd gecko_sdk", "&& test \"$(git -C gecko_sdk rev-parse HEAD)\" = " + os.environ["SDK_REVISION"] + " \\\n    && cd gecko_sdk")
# Audit-only source retention permits direct execution after normal source cleanup.
text += "\nCOPY --from=zigbeed-builder /usr/src/gecko_sdk/util/third_party/openthread/third_party/mbedtls/repo/scripts/config.py /audit/mbedtls-config.py\n"
path.write_text(text)
print("Audit-only adaptations: immutable builder/base, checked SLC COPY instead of duplicate mutable download, unchanged CPC/SDK tag identity assertions")
