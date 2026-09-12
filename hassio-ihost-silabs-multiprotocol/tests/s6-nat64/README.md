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

Two failure containers return CLI Error text with exit zero. The test requires each
container to stop with status 1 and emit the configuration-failure diagnostic and
CLI Error text. One daemon exits cleanly on SIGTERM; the other deliberately ignores
SIGTERM and requires the copied production 3000-ms timeout-kill. Finish must report
status 1 in both cases, with signal 0 and signal 9 respectively. The stalled case
must take at least two seconds, while the existing 20-second shutdown bound stays
unchanged and no global grace override is added.

After shutdown the runner reads container-local command/generation files through
Docker's tar stream, requiring exactly the two disable attempts and no daemon
restart. It also rejects s6-rc's successful-start notification for the agent.
This checks the permanent-failure path that releases s6-rc's pending startup lock;
merely requesting halt cannot satisfy these assertions if startup remains pending.
This covers a responsive finish after clean exit or daemon kill. Forced finish
expiry before initial readiness is not demonstrated by these scenarios.

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

## Synthetic Bashio configuration

The pinned image's build history records `BASHIO_VERSION=0.17.0`.
That version's [config function](https://github.com/hassio-addons/bashio/blob/v0.17.0/lib/config.sh)
reads `bashio::addon.config`, whose [implementation](https://github.com/hassio-addons/bashio/blob/v0.17.0/lib/addons.sh)
first reads cache key `addons.self.options.config`; on a miss it requests
`/addons/self/options/config` from Supervisor. Writing `/data/options.json`
does not populate this source. Run 34700442152 consequently used missing options:
the off case happened to pass, but the on case failed its command sequence.

The fixture now uses the released `bashio::cache.set` to seed that key with the
synthetic JSON options object and asserts both values through real
`bashio::config` before starting notifyoncheck. No cache path or configuration
function is replaced, and no Supervisor server, token or networking is needed.
The runner also rejects the observed Supervisor lookup error diagnostics.
