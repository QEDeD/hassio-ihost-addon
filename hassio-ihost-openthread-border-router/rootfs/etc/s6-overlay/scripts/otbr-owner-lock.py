#!/usr/bin/python3
"""Hold the host-network ownership gate shared by OTBR add-ons."""

import argparse
import errno
import os
import signal
import socket
import sys
from typing import Optional, Sequence


DEFAULT_SOCKET_NAME = "io.home-assistant.otbr-owner.v1"
MAX_ABSTRACT_NAME_BYTES = 107


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Atomically claim the host-network OTBR ownership gate.",
    )
    parser.add_argument(
        "--socket-name",
        default=DEFAULT_SOCKET_NAME,
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help=argparse.SUPPRESS,
    )
    return parser.parse_args(argv)


def _abstract_address(name: str) -> bytes:
    encoded_name = name.encode("utf-8")
    if not encoded_name or b"\0" in encoded_name:
        raise ValueError("the abstract socket name must be non-empty and contain no NUL")
    if len(encoded_name) > MAX_ABSTRACT_NAME_BYTES:
        raise ValueError(
            f"the abstract socket name exceeds {MAX_ABSTRACT_NAME_BYTES} bytes"
        )
    return b"\0" + encoded_name


def _exit_cleanly(_signum: int, _frame: object) -> None:
    raise SystemExit(os.EX_OK)


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        address = _abstract_address(args.socket_name)
    except (UnicodeEncodeError, ValueError) as err:
        print(f"ERROR: invalid OTBR ownership socket name: {err}.", file=sys.stderr)
        return os.EX_USAGE

    signal.signal(signal.SIGTERM, _exit_cleanly)
    signal.signal(signal.SIGINT, _exit_cleanly)

    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as owner_socket:
        try:
            owner_socket.bind(address)
        except OSError as err:
            if err.errno == errno.EADDRINUSE:
                print(
                    "ERROR: the OTBR ownership gate "
                    f"'@{args.socket_name}' is already held; "
                    "stop the other OTBR add-on before starting this one.",
                    file=sys.stderr,
                )
                return os.EX_TEMPFAIL
            print(
                f"ERROR: could not claim OTBR ownership gate "
                f"'@{args.socket_name}': {err}.",
                file=sys.stderr,
            )
            return os.EX_OSERR

        try:
            os.write(3, b"\n")
        except OSError as err:
            print(
                f"ERROR: could not notify s6 after claiming OTBR ownership: {err}.",
                file=sys.stderr,
            )
            return os.EX_OSERR

        command = args.command
        if command and command[0] == "--":
            command = command[1:]

        if command:
            os.set_inheritable(owner_socket.fileno(), True)
            try:
                os.execvp(command[0], command)
            except OSError as err:
                print(
                    f"ERROR: could not execute protected command "
                    f"'{command[0]}': {err}.",
                    file=sys.stderr,
                )
                return os.EX_OSERR

        while True:
            signal.pause()


if __name__ == "__main__":
    raise SystemExit(main())
