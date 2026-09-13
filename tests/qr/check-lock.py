#!/usr/bin/env python3
"""Check frontend CMake lock inputs and fail-closed behavior in prepared scratch."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

FRONTEND = Path("util/third_party/ot-br-posix/src/web/web-service/frontend")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scratch", type=Path)
    args = parser.parse_args()
    source = args.scratch / "sdk" / FRONTEND
    binary = args.scratch / "build" / FRONTEND
    manifest = source / "package.json"
    lock = source / "package-lock.json"
    originals = {path: path.read_bytes() for path in (manifest, lock)}
    assets = {path.relative_to(binary): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in (binary / "node_modules").rglob("*")
              if path.is_file() and (path.name.endswith(".min.js") or
                                     path.name.endswith(".min.css") or path.name == "qrcode.js")}

    def build(ok):
        result = subprocess.run(["cmake", "--build", str(args.scratch / "build"),
                                 "--target", "otbr-web-frontend"], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert (result.returncode == 0) == ok, result.stdout
        return result.stdout

    try:
        build(True)
        for path, original in originals.items():
            assert path.read_bytes() == original, f"source rewritten: {path}"
        # Editing only the lock must trigger copying and a fresh clean install.
        lock.write_bytes(originals[lock] + b"\n")
        build(True)
        assert (binary / "package-lock.json").read_bytes() == lock.read_bytes()
        # npm ci rejects a manifest update without its corresponding lock update.
        data = json.loads(originals[manifest])
        data["dependencies"]["qrcode-generator"] = "2.0.3"
        manifest.write_text(json.dumps(data))
        assert "npm" in build(False).lower()
        assert manifest.read_text() == json.dumps(data)
        manifest.write_bytes(originals[manifest])
        # A corrupt source lock cannot silently reuse already-present assets.
        lock.write_text("{invalid json")
        assert "npm" in build(False).lower()
        lock.unlink()
        build(False)
    finally:
        for path, original in originals.items():
            path.write_bytes(original)
        build(True)
    for relative, digest in assets.items():
        assert hashlib.sha256((binary / relative).read_bytes()).hexdigest() == digest, relative
    for path, original in originals.items():
        assert path.read_bytes() == original
        assert (binary / path.name).read_bytes() == original
    print("Frontend lock checks passed: unchanged inputs, lock-only rebuild, manifest mismatch, corrupt/missing lock, restored asset hashes.")


if __name__ == "__main__":
    main()