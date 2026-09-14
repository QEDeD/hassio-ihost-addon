#!/bin/bash
# Run inside the candidate image with --network none and no devices or volumes.
set -euo pipefail
/usr/local/bin/cpcd --version
for binary in /usr/local/bin/cpcd /usr/local/bin/zigbeed /usr/sbin/otbr-agent /usr/sbin/otbr-web /usr/sbin/ot-ctl; do
  ldd "$binary" > /tmp/checked-libraries
  ! grep -q 'not found' /tmp/checked-libraries
done
python3 /sdk2026-runtime/test-key-preflight.py
s6-rc-compile /tmp/verified-service-db /package/admin/s6-overlay-*/etc/s6-rc/sources /etc/s6-overlay/s6-rc.d
test "$(cat /usr/share/sdk2026-build/cpc-mode)" = ON
grep -q '^disable_encryption: false$' /usr/local/share/cpcd.conf
test ! -e /etc/s6-overlay/s6-rc.d/mdns
/usr/sbin/otbr-web -I wpan0 -p 18080 -a 127.0.0.1 >/tmp/verified-web.log 2>&1 &
webpid=$!
trap 'kill "$webpid" 2>/dev/null || true' EXIT
python3 - <<'PY'
import pathlib,time,urllib.request
for n in range(30):
    try:
        page=urllib.request.urlopen('http://127.0.0.1:18080/',timeout=1).read()
        break
    except OSError:
        time.sleep(.1)
else:
    raise RuntimeError('web server unavailable')
root=pathlib.Path('/usr/share/otbr-web/frontend')
qr=urllib.request.urlopen('http://127.0.0.1:18080/res/js/qrcode.js').read()
assert qr==(root/'res/js/qrcode.js').read_bytes()
files=list(root.rglob('*.js'))
assert files
assert all(b'api.qrserver.com' not in p.read_bytes() for p in files)
print('HTTP root bytes:',len(page),'local QR bytes:',len(qr),'JS files checked:',len(files))
PY
printf 'Assembled image verification passed; no radio or live HA tested.\n'
