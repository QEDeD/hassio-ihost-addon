# OTBR lifecycle tests

Run the mocked lifecycle test from the repository root:

```sh
bash hassio-ihost-silabs-multiprotocol/tests/test-otbr-firewall.sh
```

The real-kernel smoke test is isolated in a disposable Docker network namespace.
Run it only on a development machine with Docker available, from the repository root:

```sh
addon=hassio-ihost-silabs-multiprotocol
image="local/silabs-otbr-kernel-test:local"
docker build --pull --tag "${image}" --file "${addon}/tests/kernel/Dockerfile" "${addon}"
docker run --rm \
  --cap-drop ALL \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --network none \
  --read-only \
  --pids-limit 128 \
  --security-opt no-new-privileges \
  --tmpfs /run:rw,nosuid,nodev,noexec,size=1m \
  --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m \
  "${image}"
```

Never use host networking or run this kernel test directly against a production host.
The kernel suite verifies rule installation, ordering and preservation in the real
network namespace; it does not send packets. Its xtables-lock scenario uses a
controlled lock probe, not a claim about native nft lock contention.

The released-image s6 test exercises actual container shutdown without a radio:

```sh
bash hassio-ihost-silabs-multiprotocol/tests/test-otbr-s6.sh
```

This requires AMD64 Docker. It starts one inert service under the released s6
runtime and uses the production finish/helper files. Cleanup failure, a bounded
command stall, and forced finish-timeout expiry must retain the daemon's failure
status and prevent another start. It uses no host networking, devices or host
mounts. Logs and container inspection remain in a temporary directory; set
`OTBR_S6_EVIDENCE_DIR` to choose it. CI reports synthetic test output in its log.

The forced-expiry case enlarges global shutdown grace to isolate the service
finish timeout. It does not establish shutdown timing under the default global
grace period.

## Supervisor network response

Run the focused consumer regression in an add-on image containing Python 3,
Bashio, curl and jq. Set `image` to the release or candidate image being checked:

```sh
addon=hassio-ihost-silabs-multiprotocol
image=ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64:1.0.2
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges --pids-limit 128 --tmpfs /tmp \
  --mount "type=bind,source=$(pwd)/${addon},target=/addon,readonly" \
  --entrypoint python3 "${image}" /addon/tests/test-otbr-network.py
```

This executes the production network consumer through its eth0 fallback with
installed Bashio/curl/jq against a synthetic loopback Supervisor. It checks first
primary selection, valid no-primary/empty-list fallback, malformed JSON and
structure, invalid interface fields, API error responses, HTTP failures and
connection refusal. API failures must exit before fallback; log output must not
be accepted as an interface. This is a consumer test, not complete service,
firewall, radio or live Supervisor acceptance.
