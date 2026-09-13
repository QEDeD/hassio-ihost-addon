#!/usr/bin/env python3
"""Prepare and verify the pinned, patched OTBR frontend in a fresh scratch directory."""
import argparse
from pathlib import Path
import shutil
import subprocess
from urllib.request import urlopen

REF = "da661283f301b53eec04d1016009e60bc7e34a1f"
FRONTEND = "util/third_party/ot-br-posix/src/web/web-service/frontend"
FILES = ("CMakeLists.txt", "index.html", "package.json", "res/js/app.js", "join.dialog.html")
REPO = Path(__file__).resolve().parents[2]
PATCH = REPO / "hassio-ihost-silabs-multiprotocol/otbr-patches/0001-web-generate-commissioning-qr-locally.patch"


def run(*args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scratch", type=Path, help="new or empty scratch directory")
    args = parser.parse_args()
    scratch = args.scratch.resolve()
    if scratch.exists() and any(scratch.iterdir()):
        parser.error("scratch directory must be empty; existing files are never removed")
    for command in ("patch", "cmake", "node", "npm"):
        if not shutil.which(command):
            parser.error(f"required command is missing: {command}")
    generator = "Ninja" if shutil.which("ninja") else "Unix Makefiles"
    if generator == "Unix Makefiles" and not shutil.which("make"):
        parser.error("ninja or make is required")
    sdk = scratch / "sdk"
    frontend = sdk / FRONTEND
    for name in FILES:
        target = frontend / name
        target.parent.mkdir(parents=True, exist_ok=True)
        url = f"https://raw.githubusercontent.com/SiliconLabs/simplicity_sdk/{REF}/{FRONTEND}/{name}"
        with urlopen(url, timeout=60) as response:
            target.write_bytes(response.read())
    for flags in (("--dry-run",), ()):
        with PATCH.open("rb") as patch:
            run("patch", *flags, "-p1", cwd=sdk, stdin=patch)
    (sdk / "CMakeLists.txt").write_text(
        "cmake_minimum_required(VERSION 3.10)\n"
        "project(qr_frontend_check NONE)\n"
        "set(OTBR_WEB_DATADIR share/otbr-web)\n"
        f"add_subdirectory({FRONTEND})\n", encoding="utf-8")
    build = scratch / "build"
    install = scratch / "install"
    run("cmake", "-S", sdk, "-B", build, "-G", generator,
        f"-DCMAKE_INSTALL_PREFIX={install}")
    run("cmake", "--build", build, "--target", "otbr-web-frontend")
    run("cmake", "--install", build)
    installed = install / "share/otbr-web/frontend"
    run("node", REPO / "tests/qr/check.cjs", installed, installed / "res/js/qrcode.js")
    assert (installed / "res/js/qrcode.LICENSE.txt").is_file()
    print(f"Installed frontend ready: {installed}")


if __name__ == "__main__":
    main()
