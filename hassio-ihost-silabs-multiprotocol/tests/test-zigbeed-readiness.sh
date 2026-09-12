#!/usr/bin/env bash
# Released tools and real s6 supervision; no radio, host networking or TCP probes.
set -euo pipefail
module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="ihost-zigbeed-readiness-test:local"
container="ihost-zigbeed-readiness-$$"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker build --file "$module_dir/tests/readiness/Dockerfile" --tag "$image" "$module_dir"
docker run --detach --network none --name "$container" "$image" >/dev/null
check=/etc/s6-overlay/scripts/zigbeed-healthcheck

wait_health() {
    local expected="$1" actual
    for _ in {1..60}; do
        actual="$(docker inspect --format '{{.State.Health.Status}}' "$container")"
        if [[ "$actual" == "$expected" ]]; then return; fi
        sleep 0.25
    done
    docker logs "$container"
    printf 'Expected %s, observed %s\n' "$expected" "$actual" >&2
    return 1
}
assert_unhealthy() {
    if docker exec "$container" "$check"; then
        echo 'Healthcheck unexpectedly succeeded' >&2
        return 1
    fi
    wait_health unhealthy
}
assert_healthy() {
    docker exec "$container" "$check"
    wait_health healthy
}

# Wait for actual s6 services, then reproduce the released false-positive check.
for _ in {1..60}; do
    if docker exec "$container" sh -c '[ "$(s6-svstat -u /run/service/zigbeed)" = true ]' 2>/dev/null; then break; fi
    sleep 0.25
done
docker exec "$container" sh -c '[ "$(s6-svstat -u /run/service/zigbeed)" = true ]'
assert_unhealthy
printf 'PASS: released check succeeds while TCP listener is absent; new check rejects it\n'

docker exec "$container" touch /fixture/listen
wait_health healthy
assert_healthy
printf 'PASS: default configured listener is healthy\n'

# Stop only the listener service and put an unrelated process on the same port.
docker exec "$container" s6-svc -d /run/service/zigbeed-tcp
docker exec "$container" s6-svwait -D -t 5000 /run/service/zigbeed-tcp
assert_unhealthy
docker exec --detach "$container" socat TCP-LISTEN:9999,reuseaddr,fork 'EXEC:touch /fixture/accepted'
assert_unhealthy
printf 'PASS: a foreign listener on the configured port cannot satisfy health\n'

# Use another real bind/port and reproduce a live pre-listener process again.
docker exec "$container" sh -c 'rm /fixture/listen; printf "19999\n" > /fixture/port'
docker exec "$container" s6-svc -u /run/service/zigbeed-tcp
docker exec "$container" s6-svwait -u -t 5000 /run/service/zigbeed-tcp
assert_unhealthy
docker exec "$container" touch /fixture/listen
wait_health healthy
assert_healthy
printf 'PASS: live process without listener fails; custom configured port succeeds\n'

docker exec "$container" s6-svc -d /run/service/zigbeed
docker exec "$container" s6-svwait -D -t 5000 /run/service/zigbeed
assert_unhealthy
printf 'PASS: lost zigbeed process fails even with listener present\n'

# Queries must fail closed if the supervised listener service cannot be queried.
docker exec "$container" s6-svc -u /run/service/zigbeed
wait_health healthy
docker exec "$container" mv /run/service/zigbeed-tcp /run/service/zigbeed-tcp-hidden
assert_unhealthy
docker exec "$container" mv /run/service/zigbeed-tcp-hidden /run/service/zigbeed-tcp
wait_health healthy

# The fixture listener executes touch only upon accept; passive checks never do.
for _ in {1..5}; do docker exec "$container" "$check"; done
docker exec "$container" test ! -e /fixture/accepted
printf 'PASS: supervisor-query failure fails closed; checks created no TCP client\n'
