#!/usr/bin/env python3
"""Validate an existing CPC key without changing it or exposing its contents."""
import os
import re
import stat
import sys

def check(path):
    directory, name = os.path.split(os.path.abspath(path))
    dfd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        ds = os.fstat(dfd)
        if ds.st_uid != os.geteuid() or ds.st_mode & 0o077:
            raise ValueError("CPC key directory must be owned by the service user and private (0700)")
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dfd)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_mode & 0o077:
                raise ValueError("CPC key must be a private regular file owned by the service user (0600)")
            content = os.read(fd, 35)
            if re.fullmatch(rb"[0-9a-fA-F]{32}(?:\n|\r)?", content) is None:
                raise ValueError("CPC key must contain exactly 32 hexadecimal characters and an optional single line ending")
        finally:
            os.close(fd)
    finally:
        os.close(dfd)

if __name__ == "__main__":
    try:
        check(sys.argv[1] if len(sys.argv) == 2 else "/data/cpc/binding.key")
    except (OSError, ValueError) as error:
        detail = str(error) if isinstance(error, ValueError) else "CPC binding key is absent or inaccessible"
        print(detail + "; refusing encrypted startup. Restore the matching key or use the approved provisioning procedure.", file=sys.stderr)
        sys.exit(1)
