"""Decode only the fixed metadata snapshot, never arbitrary payload/RAM bytes."""
import ast
import binascii
import json
from pathlib import Path
import re

PREFIX = b"\r\n@POST1:"
MAX_RECORD_BYTES = 1024

class SnapshotError(ValueError):
    pass


def field_names():
    names = json.loads(Path(__file__).with_name("fields.json").read_text())
    if not isinstance(names, list) or not names or not all(isinstance(n, str) for n in names) or len(set(names)) != len(names):
        raise SnapshotError("Invalid diagnostic schema")
    return names


def decode(raw):
    names = field_names()
    if raw.count(PREFIX) != 1:
        raise SnapshotError("Expected exactly one terminal snapshot")
    start = raw.index(PREFIX)
    end = raw.find(b"\r\n", start + len(PREFIX))
    if end < 0:
        raise SnapshotError("Truncated terminal snapshot")
    record = raw[start + 2:end]
    if end + 2 - start > MAX_RECORD_BYTES:
        raise SnapshotError("Oversized terminal snapshot")
    parts = record.split(b":")
    if len(parts) != len(names) + 3 or parts[0] != b"@POST1":
        raise SnapshotError("Unexpected terminal snapshot field count")
    if not re.fullmatch(rb"[0-9A-F]{4}", parts[1]) or int(parts[1],16) != len(names):
        raise SnapshotError("Invalid declared field count")
    if not all(re.fullmatch(rb"[0-9A-F]{8}", word) for word in parts[2:-1]):
        raise SnapshotError("Invalid terminal snapshot word")
    if not re.fullmatch(rb"[0-9A-F]{4}", parts[-1]):
        raise SnapshotError("Invalid terminal snapshot checksum")
    if binascii.crc_hqx(record.rsplit(b":",1)[0], 0) != int(parts[-1],16):
        raise SnapshotError("Terminal snapshot checksum mismatch")
    values = dict(zip(names, (int(word,16) for word in parts[2:-1])))
    if values.get("format_version") != 1:
        raise SnapshotError("Unsupported terminal snapshot version")
    if values.get("build_id") != 0x504F5331:
        raise SnapshotError("Unexpected terminal diagnostic build discriminator")
    return values


def extract_received(text):
    """Only private serialx RX after the final RUN; ignore TX and earlier probes."""
    received = bytearray()
    launched = False
    for line in text.splitlines():
        if re.search(r"\bserialx\.[^ ]+ DEBUG Immediately writing <GeckoBootloaderOption\.RUN_FIRMWARE: b'2'>$", line):
            received.clear()
            launched = True
            continue
        if not launched:
            continue
        match = re.search(r"\bserialx\.[^ ]+ DEBUG Received (b.*)$", line)
        if match:
            value = ast.literal_eval(match.group(1))
            if not isinstance(value, bytes):
                raise SnapshotError("RX log is not bytes")
            if len(received) + len(value) > 8192:
                raise SnapshotError("Terminal raw capture exceeds bound")
            received.extend(value)
    if not launched:
        raise SnapshotError("No final launch in raw log")
    return bytes(received)


if __name__ == "__main__":
    import sys
    print(json.dumps(decode(extract_received(Path(sys.argv[1]).read_text())), indent=2))
