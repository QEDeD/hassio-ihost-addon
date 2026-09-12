# Released-init NAT64 readiness fixture

Run from the repository root on an ephemeral Linux Docker runner:

```sh
bash hassio-ihost-silabs-multiprotocol/tests/test-otbr-nat64-s6.sh
```

This reuses the pinned released-image isolation pattern from `tests/s6`. It copies
unaltered runtime `data/check`, `otbr-agent-common`, `finish`, notification metadata
and finish timeout. Only the daemon and CLI are synthetic. The run wrapper uses
the production s6-notifyoncheck arguments; application hooks and unrelated services
are removed. The released global shutdown grace is preserved.

For false and true options, the controller delays the Unix socket and then the
loopback REST listener, asserting no CLI configuration or readiness during either
delay. Every CLI call independently asserts s6 is not ready. After readiness,
exact disable/enable sequences are checked and the checker must stop calling the
CLI. A clean daemon restart through s6 repeats these assertions for generation 2,
including the real finish script (no firewall ownership claim exists).

A third container returns CLI Error text with exit zero. The test requires the
container to stop with status 1 and emit the configuration-failure diagnostic and
CLI Error text. It does not substitute a failing process exit for this behavior.

Containers have no external networking, host mounts, hardware or network-management
capabilities. All options, sockets and state are synthetic and container-local.
The test leaves no artifacts or uploads; Docker build cache remains on its runner.
Build is bounded to 5 minutes, each controller to 60 seconds, and failure shutdown
to 20 seconds. Expected warm-image runtime is under one minute.

ShellCheck and Python syntax can be checked locally. Execution requires Docker and
has not been run on the development workstation. This tests s6/checker integration,
not real OTBR CLI semantics, IPv4 forwarding, DNS resolution or hardware behavior.
The stub response semantics are based on the pinned CLI source; packet and exact
feature-image acceptance remain separate gates.
