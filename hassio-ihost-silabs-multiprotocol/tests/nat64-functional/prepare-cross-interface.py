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
    replace_once("        # Disable the bind9 service on the BR otherwise bind9 may respond to Thread devices' DNS queries\n", '''        # Eliminate a possible path through Docker's host gateway. Only this
        # disposable BR namespace is changed; both connected networks remain.
        br.bash('ip -4 route flush default')
        route = json.loads(''.join(br.bash(f'ip -j -4 route get {dns_server_addr}')))
        self.assertEqual(len(route), 1)
        self.assertNotIn(route[0]['dev'], (config.BACKBONE_IFNAME, 'lo'))
        # A syntax/setup error must not satisfy the negative route prerequisite.
        with self.assertRaises(subprocess.CalledProcessError) as no_infra_route:
            br.bash(f'ip -4 route get {dns_server_addr} oif {config.BACKBONE_IFNAME} 2>&1')
        self.assertIn('Network is unreachable', no_infra_route.exception.output)
        answers = br.bash(f'dig +time=2 +tries=1 +short @{dns_server_addr} {TEST_DOMAIN} AAAA')
        self.assertEqual({line.strip() for line in answers}, TEST_DOMAIN_IP6_ADDRESSES)

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
