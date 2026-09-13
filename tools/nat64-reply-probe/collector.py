#!/usr/bin/env python3
"""Bounded IPv4 NAT64 reply collector. Run only for the approved live trial.

Waits for the externally injected first request's response, acknowledges it,
then sends exactly one second request through the observed translation tuple.
No pairing credentials or automatic retries. Raw evidence stays local.
"""
import argparse
import ipaddress
import json
from pathlib import Path
import socket
import struct
import time
from probe import correlate, decode


def run(bind, port, expected_source, directory, evidence):
    ipaddress.IPv4Address(bind)
    ipaddress.IPv4Address(expected_source)
    if not 1024 <= port <= 65535:
        raise ValueError('Use an explicit unprivileged collector port')
    manifest = json.loads((directory / 'manifest.json').read_text())
    first, second = manifest['probes']
    if second['counter'] <= first['counter'] + 16:
        raise ValueError('Regenerate packets with reserved acknowledgement counters')
    evidence.mkdir(exist_ok=False)
    deadline = time.monotonic() + 30
    peer = None
    stage = 0
    seen = set()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind((bind, port))
        print('READY: waiting for translated response', flush=True)
        for index in range(8):
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError('Collector deadline reached')
            sock.settimeout(remaining)
            data, sender = sock.recvfrom(2048)
            if sender[0] != expected_source or (peer and sender != peer):
                raise ValueError('Unexpected source; stopped without responding')
            result = correlate(decode(data), manifest)
            (evidence / f'reply-{index}.bin').write_bytes(data)
            (evidence / f'reply-{index}.json').write_text(json.dumps(
                {'time': time.time(), 'peer': sender, **result}, indent=2))
            if peer is None:
                if result['exchange'] != first['exchange']:
                    raise ValueError('First reply belongs to wrong exchange')
                peer = sender
                sock.connect(peer)
            request = first if result['exchange'] == first['exchange'] else second
            if result['requires_ack']:
                ack = struct.pack('<BHBIQ', 4, 0, 0, request['counter'] + 16,
                                  int(manifest['source_node']))
                ack += struct.pack('<BBHHI', 3, 0x10, result['exchange'], 0,
                                   result['counter'])
                sock.send(ack)
            key = (result['exchange'], result['counter'])
            if key in seen:
                continue
            seen.add(key)
            if result['opcode'] != 0x40:
                continue
            if stage == 0:
                print('Translated rejection received; sending reverse-path request', flush=True)
                sock.send((directory / second['file']).read_bytes())
                stage = 1
            elif result['exchange'] == second['exchange']:
                print('PASS: two correlated rejections; same-socket reverse UDP exchange', flush=True)
                return
        raise RuntimeError('Packet limit reached without complete evidence')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bind', required=True)
    p.add_argument('--port', required=True, type=int)
    p.add_argument('--expected-source', required=True)
    p.add_argument('--packets', required=True, type=Path)
    p.add_argument('--evidence', required=True, type=Path)
    args = p.parse_args()
    run(args.bind, args.port, args.expected_source, args.packets, args.evidence)
