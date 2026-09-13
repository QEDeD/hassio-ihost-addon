#!/usr/bin/env python3
"""Real container image switches; synthetic data and stub /init, never a radio."""
import argparse
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
import uuid

HERE = Path(__file__).resolve().parent


def image_id(value):
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', value):
        raise argparse.ArgumentTypeError('use an explicit immutable local image ID: sha256:<64 lowercase hex digits>')
    return value


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True, type=image_id)
    parser.add_argument('--baseline', required=True, type=image_id,
                        help='current production-code image, with the same guarded entrypoint')
    parser.add_argument('--recovery', required=True, type=image_id,
                        help='guarded image that enforces OTBR off')
    return parser.parse_args(argv)


def main():
    args = arguments()
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
        options = json.loads((HERE / 'config.template.json').read_text())['options']
        options.update({'local_service_mode': 'run', 'otbr_enable': False,
                        'otbr_nat64': False, 'nondefault_sentinel': 'preserve-this-option'})
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
        def verify(starts):
            assert (data / 'stub-starts').read_text() == str(starts)
            for role, relative in guard.FILES.items():
                expected = ('synthetic-' + role).encode()
                expected += b''.join(b'|runtime-' + str(n).encode() for n in range(1, starts + 1))
                assert (data / relative).read_bytes() == expected
            assert json.loads(options_path.read_text()) == options

        # Initial handoff must be OTBR off. Subsequent synthetic starts exercise
        # production-code rollback with OTBR on; /init remains a stub throughout.
        run(args.candidate, 0)
        verify(1)
        options['otbr_enable'] = True
        options_path.write_text(json.dumps(options))
        for starts, selected in enumerate((args.candidate, args.baseline, args.candidate), 2):
            run(selected, 0)
            verify(starts)

        # Separately exercise the deliberately OTBR-off recovery package.
        options['otbr_enable'] = False
        options_path.write_text(json.dumps(options))
        run(args.recovery, 0)
        verify(5)
        # Existing state survives a rejected recovery startup; /init never runs.
        options['otbr_enable'] = True
        options_path.write_text(json.dumps(options))
        run(args.recovery, 1)
        verify(5)
        print(json.dumps({'image_switches': [args.candidate, args.candidate, args.baseline, args.candidate, args.recovery],
                          'stub_starts': 5, 'radio_states_preserved': True,
                          'options_preserved': True, 'unsafe_recovery_start_refused': True,
                          'normal_radio_init_executed': False, 'real_radio_compatibility_verified': False}))


if __name__ == '__main__':
    main()
