import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('observe', Path(__file__).with_name('observe.py'))
o = importlib.util.module_from_spec(spec)
spec.loader.exec_module(o)


class ObservationTests(unittest.TestCase):
    def test_thread_error_is_not_success_even_if_exit_zero(self):
        r = o.capture([sys.executable, '-c', 'print("Error 35: InvalidCommand")'])
        self.assertEqual(r['status'], 'error')

    def test_capture_does_not_kill_successful_command_at_stdout_eof(self):
        r = o.capture([sys.executable, '-c', 'print("Done")'])
        self.assertEqual(r['status'], 'ok')
        self.assertEqual(r['exit'], 0)

    def test_timeout_and_output_bound(self):
        r = o.capture([sys.executable, '-c', 'import time; time.sleep(5)'], 0.1)
        self.assertEqual(r['status'], 'timeout')
        r = o.capture([sys.executable, '-c', 'print("x" * 100000)'])
        self.assertEqual(r['status'], 'output_limit')
        self.assertLessEqual(len(r['output']), o.LIMIT)

    def test_missing_binary_is_explicit(self):
        self.assertEqual(o.capture(['/not-a-real-binary'])['status'], 'unavailable')

    def test_netdata_excludes_commissioning_and_service_payloads(self):
        text = 'Prefixes:\nfd00::/64 paos med 0000\nRoutes:\nfd01::/64 s med 0000\nServices:\nprivate-service\nCommissioning:\nprivate-commissioning\nDone\n'
        result = o.prefixes_and_routes(text)
        self.assertIn('fd00::/64', result)
        self.assertIn('fd01::/64', result)
        self.assertNotIn('private', result)

    def test_srv_records_exclude_txt_instance_and_invalid_targets(self):
        text = ('Private._matter._tcp SRV 0 0 5540 fixture.local. ; comment\n'
                'Private._matter._tcp TXT "private TXT"\n'
                'Bad._matter._tcp SRV 0 0 999999 fixture.local.\n'
                'Remote._matter._tcp SRV 0 0 443 external.example.\n')
        self.assertEqual(o.srv_records(text, '_matter._tcp'),
                         [{'service': '_matter._tcp', 'target': 'fixture.local.', 'port': 5540}])
        self.assertNotIn('Private', str(o.srv_records(text, '_matter._tcp')))
        self.assertEqual(o.srv_records(text, '_meshcop._udp'), [])

    def test_ipv6_fields_and_interface_are_retained(self):
        text = ('09:00:00 Add 40000002 7 fixture.local. fe80::17%eth0 120\n'
                '09:00:00 Add 40000002 7 other.local. 2001:db8::1 120\n'
                '09:00:00 Add 40000002 7 fixture.local. invalid 120\n')
        self.assertEqual(o.ipv6_records(text, 'fixture.local.'),
                         [{'interface_index': 7, 'address': 'fe80::17'}])

    def test_discovery_bounds_queries_and_preserves_resolution_failure(self):
        text = ''.join('P%d._matter._tcp SRV 0 0 5540 h%d.local.\n' % (i, i) for i in range(6))
        with patch.object(o, 'capture', side_effect=[{'status': 'ok', 'output': text}] +
                          [{'status': 'error'}] * 4) as capture:
            result = o.discovery_records('_matter._tcp', 7)
        self.assertTrue(result['truncated'])
        self.assertEqual(len(result['records']), 4)
        self.assertTrue(all(r['address_status'] == 'error' for r in result['records']))
        self.assertEqual(capture.call_count, 5)
        self.assertEqual(capture.call_args_list[0].args[0][:3], ['dns-sd', '-i', '7'])


if __name__ == '__main__':
    unittest.main()
