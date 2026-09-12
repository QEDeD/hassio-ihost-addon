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