#!/usr/bin/env python3
"""Explicit single-attempt CPC provisioning; ordinary starts reuse state_guard.
Only installed in the same-slug trial wrapper, never a normal s6 service.
"""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import selectors
import signal
import stat
import subprocess
import sys
import time

import state_guard as guard

DATA = Path('/data')
EXPECTED_DEVICE = Path('/usr/share/sdk2026-build/bind-device')
MODE = Path('/usr/share/sdk2026-build/cpc-mode')
TEMPLATE = Path('/usr/local/share/cpcd.conf')
CONFIG = Path('/usr/local/etc/cpcd-bind.conf')
CPC = '/usr/local/bin/cpcd'
TEMP = '/usr/bin/tempio'
CHECKER = '/usr/local/bin/cpc-key-preflight'
GUARD = '/usr/local/lib/local-service/state_guard.py'
ATTEMPT = 'binding-attempt'
COMPLETE = 'binding-complete'
ATTEMPT_BYTES = b'cpc-ecdh-attempt-v1\n'
COMPLETE_BYTES = b'cpc-ecdh-complete-v1\n'
BIND_TIMEOUT = 120
OUTPUT_LIMIT = 65536
BIND_SUCCESS = rb'^(?:\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\] )?INF : Binding successful\r?$'

class Refused(Exception):
    pass

def require(ok, message):
    if not ok:
        raise Refused(message)

def interrupted(signum, frame):
    raise Refused('binding interrupted; inspect retained attempt')

@contextlib.contextmanager
def locked(data):
    guard.checked(data, directory=True)
    fd = os.open(data/'.local-state.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_nlink == 1 and info.st_uid == os.geteuid()
                and not info.st_mode & 0o077, 'unsafe state lock')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        os.close(fd)

def stop_group(process):
    # Always reap our process and terminate descendants, including after leader exit.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            continue
    process.wait(timeout=2)

def command(args, timeout, payload=None, success_pattern=BIND_SUCCESS):
    """Discard raw output; retain only bounded success-marker recognition."""
    # Defer termination until the spawned process is inside the cleanup scope.
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
    process = None
    try:
        process = subprocess.Popen(args, stdin=subprocess.PIPE if payload is not None else subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True,
                               # This entrypoint is single-threaded. Do not let the
                               # temporary parent signal mask survive into CPCd.
                               preexec_fn=lambda: signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask),
                               env={'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
                                    'LANG': 'C.UTF-8'})
    except BaseException:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        raise
    seen = False
    total = 0
    tail = b''
    deadline = time.monotonic() + timeout
    try:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        if payload is not None:
            require(len(payload) <= 4096, 'configuration input too large')
            process.stdin.write(payload)
            process.stdin.close()
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                require(remaining > 0, 'command timed out; inspect retained attempt')
                for key, mask in selector.select(min(remaining, 0.1)):
                    chunk = os.read(key.fd, 4096)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(chunk)
                    require(total <= OUTPUT_LIMIT, 'command output exceeded safe bound')
                    tail += chunk
                    while b'\n' in tail:
                        line, tail = tail.split(b'\n', 1)
                        seen |= bool(re.search(success_pattern, line))
                    require(len(tail) <= 8192, 'command output line exceeded safe bound')
            remaining = deadline - time.monotonic()
            require(remaining > 0, 'command timed out; inspect retained attempt')
            code = process.wait(timeout=remaining)
        return code, seen
    finally:
        cleanup_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM, signal.SIGINT})
        try:
            stop_group(process)
            process.stdout.close()
            if process.stdin is not None and not process.stdin.closed:
                process.stdin.close()
        finally:
            signal.pthread_sigmask(signal.SIG_SETMASK, cleanup_mask)

def private_directory(path):
    guard.checked(path, directory=True)
    info = path.stat()
    require(info.st_uid == os.geteuid() and not info.st_mode & 0o077, 'unsafe CPC directory')

def key_valid(data):
    key = data/'cpc/binding.key'
    guard.checked(key)
    require(command([sys.executable, CHECKER, str(key)], 10)[0] == 0, 'binding key validation failed')
    return key

def run_gate(data):
    directory = data/'cpc'
    if not os.path.lexists(directory):
        return  # Existing missing-key runtime gate remains authoritative.
    private_directory(directory)
    attempted = os.path.lexists(directory/ATTEMPT)
    completed = os.path.lexists(directory/COMPLETE)
    if attempted or completed:
        require(attempted and completed, 'binding incomplete; normal startup refused')
        require(guard.read_small(directory/ATTEMPT, 64) == ATTEMPT_BYTES and
                guard.read_small(directory/COMPLETE, 64) == COMPLETE_BYTES, 'invalid binding markers')
        key_valid(data)

def render(options, expected):
    require(guard.read_small(MODE, 8) == b'ON\n', 'compiled encryption must be ON')
    require(options.get('device') == expected, 'device differs from approved target')
    require(options.get('baudrate') == '115200' and options.get('flow_control') is False,
            'binding requires 115200 baud and no flow control')
    require(options.get('network_device') in (None, '') and options.get('cpcd_trace') is False,
            'binding forbids network device and tracing')
    fields = {name: options[name] for name in ('device', 'baudrate', 'flow_control', 'cpcd_trace')}
    # Reuse the existing template and tempio renderer. Bashio's current config
    # reader requires Supervisor auth, so do not invoke it before normal init.
    guard.checked(TEMPLATE)
    if os.path.lexists(CONFIG):
        guard.checked(CONFIG)
    require(command([TEMP, '-template', str(TEMPLATE), '-out', str(CONFIG)], 10,
                    json.dumps(fields).encode())[0] == 0, 'CPC config generation failed')
    text = guard.read_small(CONFIG, 16384).decode('ascii')
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        name, sep, value = line.partition(':')
        require(bool(sep) and name not in values, 'invalid generated CPC config')
        values[name] = value.strip()
    checks = {'uart_device_file': expected, 'uart_device_baud': '115200', 'uart_hardflow': 'false',
              'disable_encryption': 'false', 'binding_key_file': '/data/cpc/binding.key',
              'stdout_trace': 'false', 'enable_frame_trace': 'false', 'trace_to_file': 'false',
              'bootloader_recovery_pins_enabled': 'false', 'bus_type': 'UART'}
    require(all(values.get(k) == v for k, v in checks.items()), 'CPC config differs from binding policy')
    require(values.get('trace_to_syslog', 'false') == 'false' and
            values.get('trace_level', 'info') in ('info', 'warn', 'error'), 'CPC tracing refused')

def check_device(expected):
    require(stat.S_ISCHR(Path(expected).stat().st_mode), 'approved serial device unavailable')

def bind(data, options):
    require(os.geteuid() == 0, 'binding requires the app service user')
    require(not os.path.lexists(data/guard.PENDING), 'state import is incomplete')
    expected = guard.read_small(EXPECTED_DEVICE, 1024).decode('ascii').strip()
    require(expected.startswith('/dev/serial/by-id/') and '\n' not in expected,
            'invalid image-owned device target')
    directory = data/'cpc'
    if os.path.lexists(directory):
        private_directory(directory)
        require(not any(os.path.lexists(directory/name) for name in (ATTEMPT, COMPLETE, 'binding.key')),
                'existing binding state; replacement or repeat refused')
    render(options, expected)  # No serial access. Fail before attempt is consumed.
    # Require the approved by-id target to resolve to an actual character device.
    check_device(expected)
    if not directory.exists():
        directory.mkdir(mode=0o700)
        guard.sync_dir(data)
    private_directory(directory)
    guard.atomic_write(directory/ATTEMPT, ATTEMPT_BYTES)
    # Revalidate absence after durable intent; no vendor fopen may replace a key.
    require(not os.path.lexists(directory/'binding.key'), 'binding key already exists')
    code, success = command([CPC, '--conf', str(CONFIG), '--bind', 'ecdh', '--key', str(directory/'binding.key')],
                            BIND_TIMEOUT)
    require(code == 0 and success, 'CPC binding failed or success was not confirmed')
    key = key_valid(data)
    fd = os.open(key, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    guard.sync_dir(directory)
    try:
        guard.atomic_write(directory/COMPLETE, COMPLETE_BYTES)
    except BaseException:
        # A failed final directory sync must not leave a visible success claim.
        # Preserve attempt/key; best-effort remove only the incomplete claim.
        if os.path.lexists(directory/COMPLETE):
            (directory/COMPLETE).unlink()
            guard.sync_dir(directory)
        raise
    print('CPC binding completed; app remains stopped. Explicit normal start still required.', flush=True)

def main():
    os.umask(0o077)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    with locked(DATA):
        options = guard.load(DATA/'options.json')
        mode = options.get('local_service_mode')
        if mode == 'bind-ecdh':
            bind(DATA, options)
            return
        if mode == 'run':
            run_gate(DATA)
        require(mode in ('prepare', 'run'), 'unsupported local service mode')
    # Existing guard acquires the same lock and enforces its unchanged state gates.
    os.execv(sys.executable, [sys.executable, GUARD])

def cli():
    try:
        main()
    except Refused as error:
        print('CPC binding/start refused: '+str(error), file=sys.stderr)
        sys.exit(1)
    except BaseException:
        # Never expose arbitrary filesystem, options, key, or subprocess content.
        print('CPC binding/start refused: local validation or operation failed', file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    cli()
