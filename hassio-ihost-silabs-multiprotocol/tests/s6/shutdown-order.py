"""Exercise s6 shutdown ordering, not the real mDNS protocol or SIGPIPE."""
import pathlib
import signal
import socket
import sys
import time

SOCKET = "/run/s6-test-mdns.sock"


def request():
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(2)
        client.connect(SOCKET)
        client.sendall(b"goodbye")
        if client.recv(2) != b"ok":
            raise RuntimeError("missing server response")


def stop_server(_signal, _frame):
    print("S6_TEST_MDNS_STOP", flush=True)
    sys.exit(0)


def stop_client(_signal, _frame):
    # Let an incorrectly concurrent server stop finish before using it.
    time.sleep(0.5)
    try:
        request()
    except (OSError, RuntimeError) as error:
        print(f"S6_TEST_DEPENDENCY_GONE: {error}", flush=True)
        sys.exit(42)
    print("S6_TEST_CLIENT_STOP_COMPLETE", flush=True)
    sys.exit(0)


if sys.argv[1] == "server":
    signal.signal(signal.SIGTERM, stop_server)
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
        server.bind(SOCKET)
        server.listen(1)
        while True:
            connection, _ = server.accept()
            with connection:
                connection.recv(64)
                connection.sendall(b"ok")
else:
    signal.signal(signal.SIGTERM, stop_client)
    for attempt in range(100):
        try:
            request()
            break
        except OSError:
            time.sleep(0.05)
    else:
        raise RuntimeError("fixture server did not become ready")
    pathlib.Path("/run/s6-test-client-ready").touch()
    print("S6_TEST_CLIENT_READY", flush=True)
    while True:
        signal.pause()
