# Require the Zigbee TCP listener in the app healthcheck

Head: QEDeD:codex/zigbeed-readiness-20260912 at 9536ef0ff85d91a1a08e03b03bd91f2c2cd23225

[Exact comparison](https://github.com/iHost-Open-Source-Project/hassio-ihost-addon/compare/5a8d7dec067f9196ada5879f31f71cbf6d595bff...QEDeD:9536ef0ff85d91a1a08e03b03bd91f2c2cd23225)

### PR body

The current healthcheck can report healthy as soon as zigbeed is running, while zigbeed-tcp is still flushing the PTY and has not opened its TCP listener.

Keep the daemon liveness check and additionally require a listening TCP socket owned by the supervised zigbeed-tcp PID. Inspect sockets passively with ss from the existing iproute2 dependency: opening a probe connection would create a client of the Zigbee serial bridge. PID ownership accommodates the configured port and rejects unrelated listeners.

[CI at this exact head](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34696402324) passed syntax/ShellCheck and an isolated fixture using the released AMD64 image's actual init, s6, ss and socat. It reproduces the old false-positive window and verifies default/custom ports, stopped services, a live pre-listener process, unavailable supervision, an independently verified foreign listener, executable packaging, and Docker health status. A connection marker verifies that the checks create no TCP client.

The fixture replaces application services with inert processes and needs no radio or host networking. This establishes process/socket readiness, not Zigbee protocol or radio health. It does not change Supervisor API behavior, cross-app startup ordering, restart policy or healthcheck timing. Fresh physical Zigbee responses are documented; full candidate acceptance remains unresolved because of the earlier group-command BUSY finding. Combined-image validation is recorded in the [integration evidence](../INTEGRATION.md). The unchanged 0.2.3-ordered image passed the physical NAT64 UDP enabled/disabled comparison and the final 21-sample, 629-second health observation; it remains running with NAT64 off. The earlier light dropout also occurred on baseline. Three earlier group-command BUSY failures still lack a controlled comparison or explicit acceptance disposition. ARM build/linkage/native-web checks passed at integration 11bef36 in [CI34749205311](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34749205311); this is not physical ARM radio acceptance. Combined-image evidence must not be presented as CI executed at this individual contribution head.

This PR is independent of the firewall contribution and requires no other pending PR.
