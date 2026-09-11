#!/usr/bin/env python3
"""Real container image switches; synthetic data and stub /init, never a radio."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent
FIXED = 'local/otbr-persistent-prep:0.1.0-dnssd'
RECOVERY = 'local/otbr-persistent-prep:0.1.1-recovery-dnssd'


def main():
    spec = importlib.util.spec_from_file_location('guard', HERE / 'state_guard.py')
    guard = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(guard)
    with tempfile.TemporaryDirectory(prefix='otbr-image-switch-') as tmp:
        root = Path(tmp)
        data = root / 'data'
        data.mkdir()
        stub = root / 'stub-init'
        stub.write_text('''#!/usr/bin/python3
import json
from pathlib import Path
p=Path('/data')
counter=p/'stub-starts'
count=int(counter.read_text())+1 if counter.exists() else 1
counter.write_text(str(count))
for name in ['thread/0_b43522fffec11b30.data','zigbeed/host_token.nvm']:
    q=p/name
    q.write_bytes(q.read_bytes()+b'|runtime-'+str(count).encode())
print(json.dumps({'stub_init':count}))
''')
        stub.chmod(0o755)
        sources = {}
        for role, relative in guard.FILES.items():
            value = ('synthetic-' + role).encode()
            path = data / relative
            path.parent.mkdir(mode=0o700)
            path.write_bytes(value)
            path.chmod(0o600)
            sources[role] = {'size': len(value), 'sha256': hashlib.sha256(value).hexdigest()}
        (data / guard.COMPLETE).write_text(json.dumps({'version': 1, 'sources': sources}))
        options = {'local_service_mode': 'run', 'otbr_enable': False,
                   'nondefault_sentinel': 'preserve-this-option'}
        options_path = data / 'options.json'
        options_path.write_text(json.dumps(options))
        def run(image, expected):
            name = 'otbr-image-switch-' + uuid.uuid4().hex
            argv = ['docker', 'run', '--rm', '--pull=never', '--name', name,
                '--network', 'none', '--read-only', '--user', str(os.getuid()) + ':' + str(os.getgid()), '--cap-drop', 'ALL',
                '--security-opt', 'no-new-privileges', '--pids-limit', '32', '--memory', '64m',
                '--mount', 'type=bind,source=' + str(data) + ',target=/data',
                '--mount', 'type=bind,source=' + str(stub) + ',target=/init,readonly', image]
            try:
                r = subprocess.run(argv, capture_output=True, text=True, timeout=25)
            except subprocess.TimeoutExpired:
                subprocess.run(['docker', 'rm', '-f', name], capture_output=True, timeout=10)
                raise
            if r.returncode != expected:
                raise RuntimeError('Unexpected fixture container result: ' + r.stdout + r.stderr)
            return r.stdout
        for image in (FIXED, FIXED, RECOVERY, FIXED):
            run(image, 0)
        assert (data / 'stub-starts').read_text() == '4'
        for role, relative in guard.FILES.items():
            assert (data / relative).read_bytes() == ('synthetic-' + role).encode() + b'|runtime-1|runtime-2|runtime-3|runtime-4'
        assert json.loads(options_path.read_text()) == options
        # Existing state survives a rejected recovery startup; /init never runs.
        options['otbr_enable'] = True
        options_path.write_text(json.dumps(options))
        run(RECOVERY, 1)
        assert (data / 'stub-starts').read_text() == '4'
        assert json.loads(options_path.read_text()) == options
        print(json.dumps({'image_switches': [FIXED, FIXED, RECOVERY, FIXED],
                          'stub_starts': 4, 'radio_states_preserved': True,
                          'options_preserved': True, 'unsafe_recovery_start_refused': True,
                          'normal_radio_init_executed': False}))


if __name__ == '__main__':
    main()
