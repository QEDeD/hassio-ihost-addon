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
