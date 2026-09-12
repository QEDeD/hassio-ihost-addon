#!/usr/bin/env python3
"""Synthetic IPv4 UDP request/response with observed source-address evidence."""
import socket
import sys
from pathlib import Path

mode = sys.argv[1]
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.settimeout(3)
    if mode == "server":
        sock.bind(("198.18.0.6", 9000))
        Path("/tmp/nat64-udp-ready").touch()
        while True:
            try:
                payload, peer = sock.recvfrom(1024)
            except socket.timeout:
                continue
            sock.sendto(peer[0].encode() + b"|" + payload, peer)
    elif mode == "client":
        source, port, expected_source = sys.argv[2:]
        sock.bind((source, int(port)))
        # Unique source ports avoid reuse of old conntrack mappings after cleanup.
        payload = ("nat64-fixture-" + port).encode()
        sock.sendto(payload, ("198.18.0.6", 9000))
        response, peer = sock.recvfrom(1024)
        assert peer == ("198.18.0.6", 9000), peer
        assert response == expected_source.encode() + b"|" + payload, response
        print(f"PASS: UDP source {source} observed as {expected_source}; reply returned")
    else:
        raise ValueError(mode)
