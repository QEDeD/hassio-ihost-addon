# Released s6 lifecycle regression

Run `bash hassio-ihost-silabs-multiprotocol/tests/test-otbr-s6.sh`.
The fixture uses the pinned released init and production OTBR finish handler,
with application services replaced and no radio access or networking.

The shutdown-order case copies the production `otbr-agent -> mdns` dependency.
A synthetic client uses a Unix-socket service during graceful TERM cleanup.
The test requires that request to succeed, the client to finish before the
server receives TERM, and container exit status to remain zero. The other
three cases still require daemon failure status 23, including stalled cleanup.

For the local negative control, the same image was started with `/bin/sh` as
entrypoint and `rm /etc/s6-overlay/s6-rc.d/otbr-agent/dependencies.d/mdns; exec /init`.
After `/run/s6-test-client-ready` appeared, ordinary `docker stop` stopped the
server before client cleanup: the request failed and container exit was 42.
With the dependency present, cleanup succeeded and container exit was zero.

This checks the service lifetime contract. It does not reproduce the observed
production SIGPIPE or demonstrate that mDNS shutdown caused that signal.
It does not exercise the real DNS-SD protocol or guarantee daemon readiness.
