#!/usr/bin/env python3
"""Exercise the network consumer with installed Bashio/curl/jq and loopback HTTP.

Run in an add-on image containing Python, mounting the add-on read-only at /addon:
  python3 /addon/tests/test-otbr-network.py
An optional run-script path supports reproducing the pre-fix failure.
No radio, Supervisor, service startup, or firewall operations are involved.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

source = Path(sys.argv[1] if len(sys.argv) > 1 else
              '/addon/rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run').read_text()
# Execute the production declarations, API call, log-level selection and fallback
# verbatim. Stop before filesystem/firewall setup; do not emulate Bashio.
consumer = source[source.index('declare backbone_if'):source.index('mkdir -p /data/thread')]
consumer += '\nprintf "NETWORK_INTERFACE=%s\\n" "$backbone_if"\n'
response = b''
status = 200
requests = []


class Supervisor(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        requests.append(self.path)
        assert self.headers.get('Authorization') == 'Bearer synthetic-test-token'
        self.rfile.read(int(self.headers.get('Content-Length', '0')))
        code, body = status, response
        if self.path == '/addons/self/options/config':
            code, body = 200, json.dumps({'result': 'ok', 'data': {
                'otbr_log_level': 'info'}}).encode()
        elif self.path != '/network/info':
            code, body = 404, b'{}'
        self.send_response(code)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


server = HTTPServer(('127.0.0.1', 0), Supervisor)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
endpoint = f'http://127.0.0.1:{server.server_port}'


def run(endpoint_override=None):
    with tempfile.TemporaryDirectory(prefix='otbr-network-') as cache:
        env = {'PATH': os.environ['PATH'], 'HOME': cache, 'CACHE_DIR': cache,
               'SUPERVISOR_API': endpoint_override or endpoint,
               'SUPERVISOR_TOKEN': 'synthetic-test-token',
               'NO_PROXY': '*', 'no_proxy': '*', 'LOG_LEVEL': '3'}
        script = Path(cache) / 'consumer.sh'
        script.write_text(consumer)
        return subprocess.run(['/usr/bin/bashio', str(script)], env=env,
                              capture_output=True, text=True, timeout=8)


def envelope(interfaces):
    return {'result': 'ok', 'data': {'interfaces': interfaces}}


valid = envelope([{'interface': 'eth0', 'primary': False},
                  {'interface': 'wlan0', 'primary': True},
                  {'interface': 'eth1', 'primary': True}])
cases = [
    ('first_primary', valid, 200, 'wlan0'),
    ('no_primary', envelope([{'interface': 'wlan0', 'primary': False}]), 200, 'eth0'),
    ('empty_interfaces', envelope([]), 200, 'eth0'),
    ('malformed_json', b'{invalid JSON', 200, None),
    ('empty_body', b'', 200, None),
    ('multiple_documents', b'{}\n{}', 200, None),
    ('missing_result', {'data': valid['data']}, 200, None),
    ('missing_data', {'result': 'ok'}, 200, None),
    ('missing_interfaces', {'result': 'ok', 'data': {}}, 200, None),
    ('null_interfaces', envelope(None), 200, None),
    ('object_interfaces', envelope({}), 200, None),
    ('invalid_entry', envelope([None]), 200, None),
    ('missing_primary', envelope([{'interface': 'wlan0'}]), 200, None),
    ('invalid_primary', envelope([{'interface': 'wlan0', 'primary': 'true'}]), 200, None),
    ('missing_interface', envelope([{'primary': True}]), 200, None),
    ('empty_interface', envelope([{'primary': True, 'interface': ''}]), 200, None),
    ('numeric_interface', envelope([{'primary': True, 'interface': 3}]), 200, None),
    ('api_error', {'result': 'error', 'message': 'synthetic failure'}, 200, None),
    ('unauthorized', valid, 401, None),
    ('forbidden', valid, 403, None),
    ('not_found', valid, 404, None),
    ('server_error', valid, 503, None),
]
try:
    for name, body, status, expected in cases:
        response = body if isinstance(body, bytes) else json.dumps(body).encode()
        before = len(requests)
        result = run()
        output = result.stdout + result.stderr
        assert requests[before:].count('/network/info') == 1, (name, requests[before:])
        if expected is None:
            assert result.returncode != 0, (name, result)
            assert 'NETWORK_INTERFACE=' not in output, (name, result)
            assert 'Using static eth0' not in output, (name, result)
            assert 'Supervisor network information.' in output, (name, result)
        else:
            assert result.returncode == 0, (name, result)
            assert f'NETWORK_INTERFACE={expected}\n' in result.stdout, (name, result)
            assert ('Using static eth0' in output) == (name != 'first_primary'), (name, result)
        print(f'PASS {name}: exit={result.returncode} interface={expected!r}', flush=True)
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)

# Keep a port bound but not listening, avoiding reuse by an unrelated service.
with socket.socket() as refused:
    refused.bind(('127.0.0.1', 0))
    result = run(f'http://127.0.0.1:{refused.getsockname()[1]}')
output = result.stdout + result.stderr
assert result.returncode != 0 and 'NETWORK_INTERFACE=' not in output, result
assert 'Could not retrieve Supervisor network information.' in output, result
print('PASS connection_refused', flush=True)
