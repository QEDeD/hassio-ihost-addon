#!/usr/bin/env python3
"""Run only inside an isolated --network none test container; never normal init."""
import json
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, '/usr/local/lib/local-service')
from observe import discovery_records


def main():
    if not Path('/.dockerenv').exists():
        raise RuntimeError('requires an isolated Docker test container')
    processes = []
    with open('/tmp/mdns-fixture.log', 'w') as log:
        try:
            processes.append(subprocess.Popen(['/usr/sbin/mdnsd', '-debug'],
                                               stdout=log, stderr=subprocess.STDOUT))
            for attempt in range(20):
                result = subprocess.run(['dns-sd', '-V'], stdout=subprocess.DEVNULL,
                                        stderr=subprocess.DEVNULL, timeout=2)
                if result.returncode == 0:
                    break
                time.sleep(0.1)
            else:
                raise RuntimeError('mDNSResponder did not become ready')
            processes.append(subprocess.Popen(
                ['dns-sd', '-lo', '-P', 'Private Fixture', '_matter._tcp', 'local.',
                 '5540', 'fixture.local.', '2001:db8::17', 'private=fixture'],
                stdout=log, stderr=subprocess.STDOUT))
            time.sleep(0.3)
            result = discovery_records('_matter._tcp', -1)
            assert result['status'] == 'ok', result
            assert result['records'] == [{
                'service': '_matter._tcp', 'target': 'fixture.local.', 'port': 5540,
                'address_status': 'ok',
                'addresses': [{'interface_index': -1, 'address': '2001:db8::17'}]}], result
            assert 'private' not in json.dumps(result).lower(), result
            assert not result['truncated'], result
            print(json.dumps({'synthetic_local_only_dns_sd': 'passed', 'result': result}))
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=2)


if __name__ == '__main__':
    main()
