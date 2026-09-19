#!/usr/bin/env python3
"""One explicit unbind request, installed only in the separate recovery image.
No normal startup, key loading, binding, export, retry, or host-state rearming.
"""
import os
from pathlib import Path
import signal
import sys

import trial_entrypoint as common

guard = common.guard
DATA = Path('/data')
IMAGE_MARKER = Path('/usr/share/sdk2026-build/recovery-only')
CONFIG = Path('/usr/local/etc/cpcd-recovery.conf')
IMAGE_BYTES = b'cpc-unbind-only-v1\n'
ATTEMPT = 'unbind-attempt'
RESULT = 'unbind-result'
ATTEMPT_BYTES = b'cpc-unbind-attempt-v1\n'
RESULT_BYTES = b'cpc-unbound-confirmed-v1\n'
UNBIND_SUCCESS = rb'^(?:\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\] )?INF : Unbind successful, you may restart the daemon without the --unbind argument\r?$'
TIMEOUT = 120


def interrupted(signum, frame):
    raise common.Refused('recovery unbind interrupted; preserve attempt and evidence')


def unbind(data, options):
    common.require(os.geteuid() == 0, 'recovery requires the app service user')
    common.require(guard.read_small(IMAGE_MARKER, 64) == IMAGE_BYTES, 'recovery-only image required')
    common.require(options.get('local_service_mode') == 'recover-unbind', 'explicit recover-unbind mode required')
    common.require(not os.path.lexists(data/guard.PENDING), 'state import incomplete')
    expected = guard.read_small(common.EXPECTED_DEVICE, 1024).decode('ascii').strip()
    common.require(expected.startswith('/dev/serial/by-id/') and '\n' not in expected, 'invalid image-owned device')
    directory = data/'cpc-recovery'
    if os.path.lexists(directory):
        common.private_directory(directory)
        common.require(not any(os.path.lexists(directory/name) for name in (ATTEMPT, RESULT)),
                       'existing recovery attempt; repeat refused')
    # The unchanged template names the original key, but CPC MODE_BINDING_UNBIND
    # skips its loader. Do not inspect, normalize, replace, or require that key.
    common.CONFIG = CONFIG
    common.render(options, expected)
    common.check_device(expected)
    if not directory.exists():
        directory.mkdir(mode=0o700)
        guard.sync_dir(data)
    common.private_directory(directory)
    guard.atomic_write(directory/ATTEMPT, ATTEMPT_BYTES)
    code, success = common.command([common.CPC, '--conf', str(CONFIG), '--unbind'], TIMEOUT,
                                   success_pattern=UNBIND_SUCCESS)
    common.require(code == 0 and success, 'unbind failed or confirmation absent; preserve attempt and evidence')
    try:
        guard.atomic_write(directory/RESULT, RESULT_BYTES)
    except BaseException:
        if os.path.lexists(directory/RESULT):
            (directory/RESULT).unlink()
            guard.sync_dir(directory)
        raise
    print('CPC unbound confirmed; no claim of newly deleted state. App remains stopped.', flush=True)


def archive_binding(data, options):
    common.require(os.geteuid() == 0, 'recovery requires the app service user')
    common.require(guard.read_small(IMAGE_MARKER, 64) == IMAGE_BYTES, 'recovery-only image required')
    common.require(options.get('local_service_mode') == 'archive-binding', 'explicit archive-binding mode required')
    common.require(not os.path.lexists(data/guard.PENDING), 'state import incomplete')
    directory = data/'cpc-recovery'
    common.private_directory(directory)
    common.require(guard.read_small(directory/ATTEMPT, 64) == ATTEMPT_BYTES and
                   guard.read_small(directory/RESULT, 64) == RESULT_BYTES, 'confirmed unbind required')
    intent = directory/'archive-attempt'
    archive = data/'cpc-archive-before-rebind'
    common.require(not os.path.lexists(intent) and not os.path.lexists(archive), 'existing archive or attempt; repeat refused')
    source = data/'cpc'
    common.private_directory(source)
    # A separate durable intent prevents automatic retry after an uncertain fsync.
    guard.atomic_write(intent, b'cpc-archive-attempt-v1\n')
    source.rename(archive)
    guard.sync_dir(data)
    print('Existing CPC directory archived unchanged; app remains stopped.', flush=True)

def main():
    os.umask(0o077)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    with common.locked(DATA):
        options = guard.load(DATA/'options.json')
        if options.get('local_service_mode') == 'archive-binding':
            archive_binding(DATA, options)
        else:
            unbind(DATA, options)


def cli():
    try:
        main()
    except common.Refused as error:
        print('Recovery unbind refused: '+str(error), file=sys.stderr)
        sys.exit(1)
    except BaseException:
        print('Recovery unbind refused: local validation or operation failed', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    cli()
