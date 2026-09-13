#!/usr/bin/env python3
"""Derive a separate DNS-interface test from the exact pinned SDK baseline.

Usage: prepare-cross-interface.py PATH/TO/test_upstream_dns.py
The original is never written. Run the generated sibling with
OTBR_DNS_EXPECT_FAILURE=1 (default binding) or 0 (binding disabled).
"""
import argparse
import ast
import hashlib
from pathlib import Path

PINNED_SHA256 = "f8b46902df66433850e364ec46964151914ce493248d973f4e216235cf5973ac"


def prepare(source):
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != PINNED_SHA256:
        raise ValueError("Source is not the exact da661283f301b53eec04d1016009e60bc7e34a1f DNS test")
    text = data.decode("utf-8")

    def replace_once(old, new):
        nonlocal text
        if text.count(old) != 1:
            raise ValueError(f"Expected one pinned source anchor: {old!r}")
        text = text.replace(old, new, 1)

    replace_once("import unittest\n", "import unittest\nimport json\nimport os\nimport subprocess\n")
    replace_once("class UpstreamDns(thread_cert.TestCase):", "class UpstreamDnsCrossInterface(thread_cert.TestCase):")
    replace_once("            'name': 'BR',", "            'name': 'BR',\n            'backbone_network_id': 0,")
    replace_once("            'name': 'DNS Server',", "            'name': 'DNS Server',\n            'backbone_network_id': 1,")
    replace_once("    def test(self):\n", '''    def test(self):
        # Require an explicit comparison-cell expectation, never infer success.
        expected_failure = os.environ.get('OTBR_DNS_EXPECT_FAILURE')
        self.assertIn(expected_failure, ('0', '1'))
        self.expect_dns_failure = expected_failure == '1'
''')
    replace_once("        self._start_dns_server(dns_server)\n", '''        # Existing harness owns both bridges and destroys containers before them.
        # BR keeps eth0 as infrastructure; DNS is reached on its added interface.
        subprocess.check_call([
            'docker', 'network', 'connect',
            dns_server.backbone_network, br._docker_name,
        ])
        self._start_dns_server(dns_server)
''')
    replace_once("        # Disable the bind9 service on the BR otherwise bind9 may respond to Thread devices' DNS queries\n", '''        # Confirm the ordinary route uses the added DNS-side interface.
        route = json.loads(''.join(br.bash(f'ip -j -4 route get {dns_server_addr}')))
        self.assertEqual(len(route), 1)
        self.assertNotIn(route[0]['dev'], (config.BACKBONE_IFNAME, 'lo'))

        answers = br.bash(f'dig +time=2 +tries=1 +short @{dns_server_addr} {TEST_DOMAIN} AAAA')
        self.assertEqual({line.strip() for line in answers}, TEST_DOMAIN_IP6_ADDRESSES)
        # A forced-oif route lookup can succeed without a reachable DNS server.
        # Use a real IPv4 UDP DNS exchange, with the resolver's socket binding.
        bound_probe = """
import errno
import socket
import struct
import sys
server, interface, name = sys.argv[1:]
question = b''.join(bytes([len(label)]) + label.encode('ascii') for label in name.split('.'))
query = struct.pack('!6H', 0x5144, 0x0100, 1, 0, 0, 0) + question + bytes([0]) + struct.pack('!HH', 28, 1)
# First require the identical raw query to work unbound; malformed requests or
# broken probe transport cannot be mistaken for an interface-binding failure.
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.settimeout(2)
    sock.sendto(query, (server, 53))
    response, peer = sock.recvfrom(4096)
    header = struct.unpack('!6H', response[:12])
    assert peer == (server, 53), peer
    assert header[0] == 0x5144 and header[1] & 0x8000 and header[1] & 15 == 0 and header[3] > 0, header
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    # Keep setup outside the expected reachability-failure handler.
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, interface.encode('ascii'))
    sock.settimeout(2)
    try:
        sock.sendto(query, (server, 53))
        sock.recvfrom(4096)
    except socket.timeout:
        print('PASS: infra-bound DNS socket timed out; identical unbound query succeeded')
    except OSError as error:
        if error.errno not in (errno.ENETUNREACH, errno.EHOSTUNREACH):
            raise
        print('PASS: infra-bound DNS socket unreachable, errno=' + str(error.errno))
    else:
        raise AssertionError('Infra-bound DNS socket unexpectedly received a response')
"""
        br.bash(shlex.join(['timeout', '6s', 'python3', '-c', bound_probe,
                            dns_server_addr, config.BACKBONE_IFNAME, TEST_DOMAIN]))

        # Disable the bind9 service on the BR otherwise bind9 may respond to Thread devices' DNS queries
''')
    replace_once("        resolved_names = ed.dns_resolve(TEST_DOMAIN)\n", '''        if self.expect_dns_failure:
            # Pinned node.py raises Exception(line) for CLI Error lines. Error 28
            # is the DNS client's ResponseTimeout, not a Python/pexpect timeout.
            with self.assertRaisesRegex(Exception, r'\\AError 28: ResponseTimeout\\Z'):
                ed.dns_resolve(TEST_DOMAIN)
            self.assertEqual('leader', br.get_state())
            self.assertEqual('router', ed.get_state())
            return

        resolved_names = ed.dns_resolve(TEST_DOMAIN)
''')
    ast.parse(text)
    return text


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    output = args.source.with_name("test_upstream_dns_cross_interface.py")
    generated = prepare(args.source)
    # Refuse to overwrite an earlier generated or hand-edited case.
    with output.open("x", encoding="utf-8", newline="\n") as target:
        target.write(generated)
    print(output)


if __name__ == "__main__":
    main()
