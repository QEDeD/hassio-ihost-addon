"""Only synthetic Unix/TCP listeners; no Thread stack or radio access."""
from pathlib import Path
import signal
import socket
import time

signal.signal(signal.SIGTERM, lambda *_: exit(0))
generation_path = Path('/tmp/generation')
generation = int(generation_path.read_text()) + 1 if generation_path.exists() else 1
unix_path = Path('/run/openthread-wpan0.sock')
unix_path.unlink(missing_ok=True)
generation_path.write_text(str(generation))
print(f'NAT64_FIXTURE_DAEMON={generation}', flush=True)

def gate(name):
    deadline = time.monotonic() + 20
    while not Path(f'/tmp/{name}-{generation}').exists():
        if time.monotonic() >= deadline:
            raise TimeoutError(name)
        time.sleep(0.05)

gate('allow-socket')
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as unix:
    unix.bind(str(unix_path))
    unix.listen()
    Path(f'/tmp/socket-{generation}').touch()
    gate('allow-rest')
    with socket.socket() as rest:
        rest.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        rest.bind(('127.0.0.1', 18081))
        rest.listen()
        while True:
            connection, _ = rest.accept()
            connection.close()
