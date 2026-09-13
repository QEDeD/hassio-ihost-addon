# Zigbee TCP healthcheck regression

The released image checks only whether the supervised `zigbeed` process is up.
Its `zigbeed-tcp` service subsequently spends six iterations flushing the PTY
before executing `socat TCP-LISTEN`. A probe during that window can report healthy
without a listening Zigbee endpoint.

The replacement preserves the daemon check and requires a listening TCP socket
owned by the supervised `zigbeed-tcp` PID. `ss` is supplied by the existing
`iproute2` installation. Process ownership accommodates the service's configured
port without accepting an unrelated listener on a host-networked installation.
The check makes no connection, so it cannot create a client of the serial bridge.
This is a process/socket health contract, not proof of radio or protocol readiness.
It does not change Supervisor API behavior, startup ordering or service restarts.

Run from a Linux host with Docker:

```sh
bash hassio-ihost-silabs-multiprotocol/tests/test-zigbeed-readiness.sh
```

The fixture pins the released AMD64 1.0.2 image, retains its actual init, s6,
socat and ss, and replaces all application services with inert processes. It
uses an explicit gate to reproduce the pre-listener interval deterministically.
No devices, privileged mode, host networking, host mounts or production data are
used. The container has no network connectivity; its synthetic listeners only
exist in its isolated network namespace. A marker records any accepted TCP
connection. Tests require that no health probe creates one.

Coverage: original check succeeds without listener; replacement fails without
listener; default and custom ports succeed; stopped daemon, stopped listener,
live pre-listener process and failed supervision query fail; an unrelated
same-port listener does not satisfy health. Docker health status is also checked.
The fixture does not validate a full source build, ARM, physical Zigbee traffic,
or ordering between independently started Home Assistant apps.
