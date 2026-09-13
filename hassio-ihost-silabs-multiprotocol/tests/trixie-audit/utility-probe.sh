#!/bin/bash
set -euo pipefail
if [[ ${AUDIT_CONFIG_QUERY:-1} == 1 ]]; then
python3 - <<'PY'
import subprocess, sys
from pathlib import Path
assert sys.version_info[:2] == (3, 13), sys.version
header = Path('/tmp/mbedtls-config.h')
header.write_text('#define MBEDTLS_AES_C\n//#define MBEDTLS_DES_C\n')
for symbol, expected in [('MBEDTLS_AES_C', 0), ('MBEDTLS_DES_C', 1)]:
    result = subprocess.run([sys.executable, '/audit/mbedtls-config.py', '-f', str(header), 'get', symbol], capture_output=True, text=True, timeout=5)
    assert result.returncode == expected and not result.stderr, (symbol, result)
print('PASS: actual bundled mbedTLS config.py present/absent statuses under Python 3.13')
PY
fi
ip -6 route add blackhole fd00:dead:beef::1/128 table 88
ip -6 route show table openthread | grep -F 'blackhole fd00:dead:beef::1'
socat -V | head -n 3
socat TCP-LISTEN:19999,reuseaddr,fork EXEC:/bin/cat &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in {1..50}; do
    if nc -z -w 1 127.0.0.1 19999; then break; fi
    sleep 0.1
done
nc -z -w 1 127.0.0.1 19999
ss -H -ltnp 'sport = :19999'
printf 'hello\n' | timeout 3s socat -T1 - TCP:127.0.0.1:19999 | grep -qx hello
if nc -6 -z -w 1 ::1 19999; then
    echo 'OBSERVED: generic socat TCP-LISTEN accepts IPv6'
else
    echo 'OBSERVED: generic socat TCP-LISTEN does not accept IPv6'
fi
kill "$pid"
wait "$pid" || true
trap - EXIT
socat 'TCP6-LISTEN:19998,bind=[::1],ipv6only=1,reuseaddr,fork' EXEC:/bin/cat &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for _ in {1..50}; do
    if nc -6 -z -w 1 ::1 19998; then break; fi
    sleep 0.1
done
nc -6 -z -w 1 ::1 19998
printf 'control\n' | timeout 3s socat -T1 - 'TCP6:[::1]:19998' | grep -qx control
if printf 'generic\n' | timeout 3s socat -T1 - 'TCP:[::1]:19998' | grep -qx generic; then
    echo 'OBSERVED: generic socat client accepts IPv6 literal'
else
    echo 'OBSERVED: generic socat client rejects IPv6 literal; explicit TCP6 control passed'
fi
kill "$pid"
wait "$pid" || true
trap - EXIT
printf 'PASS: routing table name, real IPv4 socat data and nc readiness\n'
