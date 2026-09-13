"""Bounded assertions run inside the isolated container, using released s6."""
from pathlib import Path
import subprocess
import sys
import time

service = '/run/service/otbr-agent'
scenario = sys.argv[1]
commands = Path('/tmp/commands')
expected = ['dns server upstream disable', 'nat64 disable']
if scenario == 'on':
    expected += ['nat64 enable', 'dns server upstream enable']

def wait_for(predicate):
    deadline = time.monotonic() + 15
    while not predicate():
        if time.monotonic() >= deadline:
            raise AssertionError('Timed out waiting for fixture stage')
        time.sleep(0.05)

def read_commands():
    return commands.read_text().splitlines() if commands.exists() else []

for generation in range(1, 3 if not scenario.startswith('error') else 2):
    wait_for(lambda: Path('/tmp/generation').exists()
             and Path('/tmp/generation').read_text() == str(generation))
    prior = read_commands()
    # Give the real checker several attempts with each prerequisite absent.
    for stage in ('allow-socket', 'allow-rest'):
        time.sleep(1)
        assert read_commands() == prior, 'CLI ran before socket/REST prerequisites'
        ready = subprocess.check_output(['s6-svstat', '-o', 'ready', service], text=True).strip()
        assert ready == 'false', f'Premature readiness: {ready}'
        Path(f'/tmp/{stage}-{generation}').touch()
        if stage == 'allow-socket':
            wait_for(lambda: Path(f'/tmp/socket-{generation}').exists())
    if scenario.startswith('error'):
        print('NAT64_FIXTURE_ERROR_ARMED', flush=True)
        break
    subprocess.run(['s6-svwait', '-U', '-t', '15000', service], check=True, timeout=17)
    wanted = prior + [f'{generation} {command}' for command in expected]
    actual = read_commands()
    assert actual == wanted, f'CLI sequence generation={generation}: actual={actual!r}; expected={wanted!r}'
    time.sleep(1)
    actual = read_commands()
    assert actual == wanted, f'CLI after readiness: actual={actual!r}; expected={wanted!r}'
    print(f'NAT64_FIXTURE_READY={generation}', flush=True)
    if generation == 1:
        # The synthetic daemon exits cleanly, exercising the real finish and restart.
        subprocess.run(['s6-svc', '-r', service], check=True, timeout=3)
print(f'PASS: released s6 NAT64 readiness ({scenario})', flush=True)
