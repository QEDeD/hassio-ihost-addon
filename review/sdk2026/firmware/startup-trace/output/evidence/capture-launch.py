"""Keep the pinned flasher connection open across startup; does not add a serial owner.
Use only in an explicitly approved one-shot diagnostic procedure, with private DEBUG logs.
"""
import hashlib
import importlib.metadata
from pathlib import Path

GECKO_SHA256 = "0bf3416d42ec8bd658cdf892e5b83ee2eccac3cfd69836b82a8b70b9a872b9ee"
CAPTURE_SECONDS = 30.0


def configure_capture(gecko):
    if importlib.metadata.version("universal-silabs-flasher") != "1.1.0":
        raise RuntimeError("Only the reviewed flasher1.1.0 is supported")
    if hashlib.sha256(Path(gecko.__file__).read_bytes()).hexdigest() != GECKO_SHA256:
        raise RuntimeError("Bootloader source differs from the reviewed wheel")
    if gecko.RUN_APPLICATION_DELAY != 2.0:
        raise RuntimeError("Unexpected existing launch timeout override")
    # Only wait longer on the already-open connection after RUN.
    # Upload, XMODEM, reset, parser and failure behavior remain vendor code.
    gecko.RUN_APPLICATION_DELAY = CAPTURE_SECONDS


if __name__ == "__main__":
    from universal_silabs_flasher import gecko_bootloader
    from universal_silabs_flasher.__main__ import main
    configure_capture(gecko_bootloader)
    main()
