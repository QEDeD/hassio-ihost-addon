import importlib.util
from pathlib import Path
import sys
import unittest

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

    def test_discovery_retains_srv_addresses_without_txt_or_instance(self):
        text = '=;eth0;IPv6;private-name;_matter._tcp;local;device.local;fd00::2;5540;"private TXT"\n'
        result = o.discovery_records(text)
        self.assertEqual(result[0]['address'], 'fd00::2')
        self.assertEqual(result[0]['port'], 5540)
        self.assertNotIn('private', str(result))
        self.assertEqual(o.discovery_records('=;x;x;x;x;x;x;bad;port;txt'), [])


if __name__ == '__main__':
    unittest.main()
