"""Extract only startup markers from private serialx RX logs, never TX firmware data."""
import ast
import json
import re
import sys
from pathlib import Path


def extract(text):
    # Firmware bytes in upload TX logs may contain marker strings: ignore all TX.
    received = bytearray()
    launched = False
    for line in text.splitlines():
        sent = re.search(r"\bserialx\.[^ ]+ DEBUG Sending (b.*)$", line)
        if sent and ast.literal_eval(sent.group(1)) == b"2":
            # The upload's final RUN supersedes any application launch during probe.
            received.clear()
            launched = True
            continue
        if not launched:
            continue
        match = re.search(r"\bserialx\.[^ ]+ DEBUG Received (b.*)$", line)
        if not match:
            continue
        value = ast.literal_eval(match.group(1))
        if not isinstance(value, bytes):
            raise ValueError("RX log is not bytes")
        received.extend(value)
    if not launched:
        raise ValueError("No logged bootloader RUN command; capture is incomplete")
    # A small fixed grammar excludes arbitrary device data/credentials.
    return [m.decode("ascii") for m in re.findall(rb"\r\n@S[0-9A-F]{2}\r\n", received)]


if __name__ == "__main__":
    print(json.dumps({"markers": extract(Path(sys.argv[1]).read_text())}, indent=2))
