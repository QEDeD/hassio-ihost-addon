#!/usr/bin/env python3
"""Prepare synthetic CASE rejection probes; inspect correlated plaintext replies.

No networking, device credentials, pairing, or persistent changes. Generated
packets use random nonmatching DestinationIDs and a throwaway P-256 public key.
"""
import argparse
import json
import secrets
import struct
from pathlib import Path


def build(out):
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat
    out.mkdir(parents=True, exist_ok=False)
    source = secrets.randbits(64) or 1
    base_counter = secrets.randbelow(0xFFFFFFFD)
    exchanges = secrets.SystemRandom().sample(range(1, 65536), 2)
    manifest = {'source_node': str(source), 'probes': []}
    for index, exchange in enumerate(exchanges, 1):
        key = ec.generate_private_key(ec.SECP256R1()).public_key().public_bytes(
            Encoding.X962, PublicFormat.UncompressedPoint)
        session = secrets.randbelow(65535) + 1
        # Anonymous structure; context-tagged byte strings and uint16.
        tlv = (b'\x15\x30\x01\x20' + secrets.token_bytes(32)
               + b'\x25\x02' + struct.pack('<H', session)
               + b'\x30\x03\x20' + secrets.token_bytes(32)
               + b'\x30\x04\x41' + key + b'\x18')
        counter = base_counter + index
        # SourceNodeID only; unencrypted session 0. Initiator + reliable request.
        packet = struct.pack('<BHBIQ', 4, 0, 0, counter, source)
        packet += struct.pack('<BBHH', 5, 0x30, exchange, 0) + tlv
        (out / f'sigma1-request-{index}.bin').write_bytes(packet)
        (out / f'sigma1-request-{index}.tlv').write_bytes(tlv)
        manifest['probes'].append({'exchange': exchange, 'counter': counter,
                                    'session': session, 'file': f'sigma1-request-{index}.bin'})
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared two synthetic exchanges; no packets sent.')


def decode(packet):
    if len(packet) < 14:
        raise ValueError('Truncated packet')
    flags, session, security, counter = struct.unpack_from('<BHBI', packet)
    if flags & 0xF8 or session != 0 or security != 0:
        raise ValueError('Not supported plaintext unicast framing')
    offset = 8
    result = {'counter': counter}
    if flags & 4:
        result['source_node'] = str(struct.unpack_from('<Q', packet, offset)[0])
        offset += 8
    dest = flags & 3
    if dest == 1:
        result['destination_node'] = str(struct.unpack_from('<Q', packet, offset)[0])
        offset += 8
    elif dest:
        raise ValueError('Group/reserved destination not accepted')
    ef, opcode, exchange = struct.unpack_from('<BBH', packet, offset)
    offset += 4
    if ef & ~7:
        raise ValueError('Unsupported payload header flags')
    protocol = struct.unpack_from('<H', packet, offset)[0]
    offset += 2
    if ef & 2:
        result['acknowledged_counter'] = struct.unpack_from('<I', packet, offset)[0]
        offset += 4
    result.update(exchange=exchange, opcode=opcode, protocol=protocol,
                  initiator=bool(ef & 1), requires_ack=bool(ef & 4))
    if opcode == 0x40 and protocol == 0:
        general, status_protocol, status = struct.unpack_from('<HIH', packet, offset)
        result.update(general_status=general, status_protocol=status_protocol,
                      protocol_status=status)
    return result


def inspect(path, manifest_path):
    result = decode(path.read_bytes())
    manifest = json.loads(manifest_path.read_text())
    probe = next((p for p in manifest['probes'] if p['exchange'] == result['exchange']), None)
    if not probe or result['protocol'] != 0 or result['initiator']:
        raise ValueError('Uncorrelated exchange/protocol/direction')
    if result.get('destination_node') != manifest['source_node']:
        raise ValueError('Reply destination does not match probe identity')
    if 'acknowledged_counter' in result and result['acknowledged_counter'] != probe['counter']:
        raise ValueError('Wrong acknowledgement counter')
    if result['opcode'] == 0x10:
        if result.get('acknowledged_counter') != probe['counter']:
            raise ValueError('ACK must match the probe counter')
        result['evidence'] = 'correlated ACK only; not CASE rejection proof'
    elif result['opcode'] == 0x40:
        if result.get('status_protocol') != 0 or result.get('protocol_status') != 1 or result.get('general_status') != 1:
            raise ValueError('Unexpected status (including Busy): stop and inspect')
        result['evidence'] = 'correlated NoSharedTrustRoots rejection'
    else:
        raise ValueError('Unexpected reply; stop and inspect')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('build'); p.add_argument('output', type=Path)
    p = sub.add_parser('inspect'); p.add_argument('packet', type=Path); p.add_argument('manifest', type=Path)
    args = parser.parse_args()
    if args.command == 'build':
        build(args.output)
    else:
        inspect(args.packet, args.manifest)
