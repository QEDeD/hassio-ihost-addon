#!/usr/bin/env python3
"""Synthetic key cases; never loads the production key or contacts a radio."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

checker = str(Path(__file__).with_name("cpc-key-preflight.py"))
key = b"0123456789abcdef0123456789abcdef"
count = 0
with tempfile.TemporaryDirectory() as temp:
    directory = Path(temp) / "cpc"
    directory.mkdir(mode=0o700)
    path = directory / "binding.key"
    def run(expected):
        global count
        result = subprocess.run([sys.executable, checker, str(path)], capture_output=True)
        assert (result.returncode == 0) == expected, result.stderr
        assert key not in result.stdout + result.stderr, "Key exposed in diagnostics"
        count += 1
    # CPC v4.9.1 ECDH writer includes a trailing NUL (keys.c:416).
    for ending in (b"", b"\n", b"\r", b"\x00"):
        path.write_bytes(key + ending); path.chmod(0o600); run(True)
        assert path.read_bytes() == key + ending, "Valid key was modified"
    for bad in (b"", key + b"\r\n", b"G" * 32, key + b"extra", key + b"\nsecond line",
                key + b"\x00\x00", key + b"\x00\n", key + b"\x00extra",
                key[:16] + b"\x00" + key[16:], key[:-1] + b"\x00"):
        path.write_bytes(bad); run(False); assert path.read_bytes() == bad
    path.unlink(); run(False); assert not path.exists(), "Missing key was created"
    path.write_bytes(key); path.chmod(0o644); run(False)
    path.chmod(0o600); directory.chmod(0o755); run(False); directory.chmod(0o700)
    target = directory / "other.key"; path.rename(target); path.symlink_to(target); run(False); path.unlink()
    path.mkdir(); run(False); path.rmdir()
    os.mkfifo(path, 0o600); run(False); path.unlink()
print(f"{count} synthetic key checks passed; no key creation, rewriting or disclosure")
