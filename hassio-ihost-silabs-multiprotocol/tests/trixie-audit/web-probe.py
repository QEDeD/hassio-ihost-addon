#!/usr/bin/env python3
"""Exercise the installed native web server with no OT agent, radio or network."""
import http.client
import json
from pathlib import Path
import shutil
import socket
import subprocess
import time

root = Path('/usr/share/otbr-web/frontend')
assert root.is_dir(), root
binary = shutil.which('otbr-web')
assert binary, 'installed otbr-web missing'

def request(path, method='GET', body=None):
    conn = http.client.HTTPConnection('127.0.0.1', 18765, timeout=3)
    try:
        conn.request(method, path, body, {'Connection': 'close'})
        response = conn.getresponse()
        content = response.read()
        assert int(response.getheader('Content-Length')) == len(content)
        return response.status, content
    finally:
        conn.close()

with open('/tmp/otbr-web-probe.log', 'wb') as log:
    process = subprocess.Popen([binary, '-s', '-I', 'audit-no-radio', '-a', '127.0.0.1', '-p', '18765'], stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + 8
        while True:
            assert process.poll() is None, 'native web process exited during startup'
            try:
                with socket.create_connection(('127.0.0.1', 18765), timeout=.2):
                    break
            except OSError:
                if time.monotonic() > deadline:
                    raise AssertionError('native web startup timed out')
                time.sleep(.1)
        for url, file in [('/', 'index.html'), ('/index.html', 'index.html'), ('/res/js/app.js', 'res/js/app.js'), ('/res/js/angular.min.js', 'res/js/angular.min.js'), ('/join.dialog.html', 'join.dialog.html')]:
            status, content = request(url)
            assert status == 200, (url, status)
            assert content == (root/file).read_bytes(), (url, 'asset mismatch')
            print('PASS native asset', url, len(content))
        for path in ['/audit-file-does-not-exist', '/../../../../etc/passwd']:
            status, content = request(path)
            assert status == 400, (path, status)
            assert b'root:x:' not in content
            print('PASS rejected path', path)
        # These are failure-path checks: no OpenThread control socket is present.
        status, content = request('/get_qrcode')
        assert status == 200 and json.loads(content)['result'] == 'failed'
        print('PASS absent-agent JSON response')
        # Commission parses JSON before attempting a control connection. No radio
        # or daemon exists, even if malformed input unexpectedly passes parsing.
        for body in [b'', b'{broken']:
            status, content = request('/commission', 'POST', body)
            result = json.loads(content)
            assert status == 200 and isinstance(result, dict) and result['error'] != 0, (status, result)
            print('PASS malformed commission JSON', len(body), result['error'])
        assert request('/')[1] == (root/'index.html').read_bytes()
        assert process.poll() is None
        print('PASS native web remains responsive after failure cases')
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
        print(Path('/tmp/otbr-web-probe.log').read_text(errors='replace'))
