#!/bin/bash
# Run inside each disposable audit image with --network none, --read-only,
# --cap-drop ALL and writable /tmp tmpfs. No service startup or real Supervisor.
set -euo pipefail
python3 - <<'PY'
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

library = Path('/usr/lib/bashio/bashio.sh')
assert library.is_file(), 'Installed Bashio library missing'
mode = 'primary'
requests = []

class Supervisor(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        requests.append(self.path)
        assert self.headers.get('Authorization') == 'Bearer synthetic-audit-token'
        self.rfile.read(int(self.headers.get('Content-Length', '0')))
        status = 200
        if self.path == '/addons/self/options/config':
            data = {'flow_control': False, 'cpcd_trace': 0,
                    'otbr_enable': False, 'otbr_firewall': False,
                    'baudrate': 115200, 'otbr_log_level': 'INFO',
                    'device': '/dev/synthetic-radio'}
            body = json.dumps({'result': 'ok', 'data': data}).encode()
        elif self.path != '/network/info':
            status, body = 404, b'{"result":"error","message":"unexpected path"}'
        elif mode == 'malformed':
            body = b'{invalid JSON'
        elif mode == 'http_failure':
            status, body = 503, b'{"result":"error","message":"synthetic failure"}'
        else:
            interfaces = [{'interface': 'eth0', 'primary': False}]
            if mode == 'primary':
                interfaces += [{'interface': 'wlan0', 'primary': True},
                               {'interface': 'eth1', 'primary': True}]
            body = json.dumps({'result': 'ok', 'data': {'interfaces': interfaces}}).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

server = HTTPServer(('127.0.0.1', 0), Supervisor)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
endpoint = 'http://127.0.0.1:' + str(server.server_port)

# Bashio bashio.sh enables errexit/errtrace/nounset/pipefail itself.
# Use the installed library and its real curl/jq/cache implementations. A fresh
# cache for every child prevents successful cases from hiding failed requests.
def run(script, endpoint_override=None):
    with tempfile.TemporaryDirectory(prefix='bashio-audit-') as cache:
        env = {'PATH': os.environ['PATH'], 'HOME': cache,
               'SUPERVISOR_API': endpoint_override or endpoint,
               'SUPERVISOR_TOKEN': 'synthetic-audit-token', 'CACHE_DIR': cache,
               'NO_PROXY': '*', 'no_proxy': '*', 'LOG_LEVEL': '2'}
        return subprocess.run(['/bin/bash', '-c',
                               'source /usr/lib/bashio/bashio.sh\n' + script],
                              env=env, capture_output=True, text=True, timeout=8)

# Same assignment and jq expression as rootfs/.../otbr-agent/run. Do not wrap
# the function itself in an `if`: that would change Bash errexit semantics.
network = '''backbone_if="$(bashio::api.supervisor 'GET' '/network/info' '' 'first(.interfaces[] | select (.primary == true)) .interface')"
printf '%s' "$backbone_if"
'''
try:
    version = run('printf "%s" "$BASHIO_VERSION"')
    assert version.returncode == 0, version
    print('BASHIO_VERSION_VARIABLE=' + version.stdout, flush=True)
    for mode, expected_status, expected_output in [
            ('primary', 0, 'wlan0'), ('missing_primary', 0, ''),
            ('malformed', 0, ''), ('http_failure', 1, '')]:
        before = len(requests)
        result = run(network)
        assert requests[before:] == ['/network/info'], (mode, requests[before:])
        assert (result.returncode, result.stdout) == (expected_status, expected_output), (
            mode, result.returncode, result.stdout, result.stderr)
        if mode == 'malformed':
            assert result.stderr, 'Malformed JSON must expose the jq parse diagnostic'
        print(f'BASHIO_NETWORK case={mode} status={result.returncode} output={result.stdout!r}', flush=True)

    # has_value tests nonempty text: false and 0 are values; missing is null.
    config = run('''
[[ "$(bashio::config flow_control)" == false ]]
bashio::config.has_value flow_control
[[ "$(bashio::config cpcd_trace)" == 0 ]]
bashio::config.has_value cpcd_trace
[[ "$(bashio::config baudrate)" == 115200 ]]
[[ "$(bashio::config device)" == /dev/synthetic-radio ]]
[[ "$(bashio::string.lower "$(bashio::config otbr_log_level)")" == info ]]
[[ "$(bashio::config network_device)" == null ]]
if bashio::config.has_value network_device; then exit 20; fi
bashio::config.false otbr_enable
if bashio::config.true otbr_enable; then exit 21; fi
if bashio::config.true otbr_firewall; then exit 22; fi
if bashio::config.false network_device; then exit 23; fi
if bashio::config.true network_device; then exit 24; fi
if bashio::config.false cpcd_trace; then exit 25; fi
if bashio::config.true cpcd_trace; then exit 26; fi
''')
    assert config.returncode == 0, (config.returncode, config.stdout, config.stderr)
    assert '/addons/self/options/config' in requests, requests
    print('PASS: real Bashio config false/zero/missing, boolean predicates, has_value and log-level conversion', flush=True)
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)

# Reserve a local TCP port without listening: connection refusal cannot reach a
# different service or race with another process claiming the released port.
with socket.socket() as refused:
    refused.bind(('127.0.0.1', 0))
    result = run(network, 'http://127.0.0.1:' + str(refused.getsockname()[1]))
assert result.returncode == 1 and result.stdout == '', result
print('BASHIO_NETWORK case=connection_refused status=1 output=empty', flush=True)
print('OBSERVED: missing primary and malformed JSON produce success with empty interface in this call context; compare release and candidate before attributing a regression', flush=True)
print('PASS: actual installed Bashio against bounded synthetic loopback Supervisor; no full add-on startup or live Supervisor acceptance', flush=True)
PY
