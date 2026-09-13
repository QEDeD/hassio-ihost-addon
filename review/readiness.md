# Require the Zigbee TCP listener in the app healthcheck

## Submission identity (operator reference)

Destination: iHost-Open-Source-Project/hassio-ihost-addon, target master.
Source branch: `QEDeD:codex/zigbeed-readiness-20260912`.
Exact head: `9536ef0ff85d91a1a08e03b03bd91f2c2cd23225`. Review base: `5a8d7dec067f9196ada5879f31f71cbf6d595bff`.
[Exact local diff](diffs/readiness.patch). Independent iHost PR.

## Final submission text

The current healthcheck can report healthy while zigbeed-tcp is still flushing its PTY and has not opened its TCP listener.

Keep the daemon liveness check and require a listening socket owned by the supervised zigbeed-tcp PID. Inspect sockets passively with ss from the existing iproute2 package: a connection probe would create a client of the Zigbee serial bridge. PID ownership supports configured ports and rejects unrelated listeners.

[CI at this exact head](https://github.com/QEDeD/hassio-ihost-addon/actions/runs/34696402324) passed syntax/ShellCheck and an isolated fixture using the released AMD64 image's actual init, s6, ss and socat. It reproduces the false-positive window and covers default/custom ports, stopped services, a live pre-listener process, unavailable supervision, a foreign listener, executable packaging and Docker health status. A connection marker confirms no probe client was created.

Application services are inert fixtures: this verifies process/socket readiness, not radio or Zigbee protocol health. Restart policy, healthcheck timing and cross-app startup behavior are unchanged. No other pending PR is required.

## Operator notes - do not paste

Ready for approval. The existing PR path filters and manual trigger work upstream. The personal-branch push trigger is a development convenience, not a required upstream branch or external checkout; removing it is optional and not a submission blocker.
