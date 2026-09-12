#!/usr/bin/env python3
"""Generate a new local-only build context; never installs/builds/starts an app."""
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ADDON = HERE.parent.parent
BASE = 'ghcr.io/ihost-open-source-project/hassio-ihost-silabs-multiprotocol-amd64@sha256:f69bd95b16c23c018351b55659e3767f6573edf8f87061c58d1e610a2ce8ccef'
RUNTIME = {
 'rootfs/etc/s6-overlay/scripts/otbr-agent-common': 'aa383a42a12d414a57d6c927c9fc99a004841d3eb6279dce302e5791e513125b',
 'rootfs/etc/s6-overlay/scripts/otbr-enable-check.sh': '84921f81d974c2a7899b534eec3fc89347f74d9727b82d01174704e5b605897b',
 'rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/run': 'ccb405a7de851638bd9cce842e5f455da898a1b48958d24f16c19560740d139d',
 'rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/finish': '9ddbc9545cce3be1f1006160767c9cf287171d082ad7e82d88f0cf24a9457dc1',
 'rootfs/etc/s6-overlay/s6-rc.d/otbr-agent/timeout-finish': '876e13f4e07bb39705302c01f445ffd2d2c3b180a207e4d959d6b671c67da09b',
}


def normalized(path):
    return path.read_text(encoding='utf-8-sig').replace('\r\n', '\n').encode()


def generate(destination, recovery=False):
    if not destination.is_absolute() or destination.exists():
        raise ValueError('destination must be a new absolute directory')
    # Verify before creating anything; this is not a generic patch overlay.
    source = {name: normalized(ADDON / name) for name in RUNTIME}
    for name, value in source.items():
        if hashlib.sha256(value).hexdigest() != RUNTIME[name]:
            raise ValueError('focused runtime identity mismatch: ' + name)
    config = json.loads((HERE / 'config.template.json').read_text())
    if recovery:
        config['version'] = '0.1.3-recovery'
    destination.mkdir(parents=True)
    def write(name, value):
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)
    write('config.json', (json.dumps(config, indent=2) + '\n').encode())
    if not recovery:
        for name, value in source.items():
            write(name, value)
    for name in ('state_guard.py', 'observe.py'):
        write('rootfs/usr/local/lib/local-service/' + name, normalized(HERE / name))
    for name, value in {
        'type': 'longrun\n',
        'run': '#!/bin/sh\npython3 /usr/local/lib/local-service/observe.py\nexec sleep infinity\n',
        'dependencies.d/base': '',
    }.items():
        write('rootfs/etc/s6-overlay/s6-rc.d/local-observe/' + name, value.encode())
    write('rootfs/etc/s6-overlay/s6-rc.d/user/contents.d/local-observe', b'')
    dockerfile = ('FROM ' + BASE + '\n' + ('ENV LOCAL_SERVICE_RECOVERY=1\n' if recovery else '') + 'COPY rootfs/ /\n'
        # HA's automatic discovery flow can create a missing Thread dataset.
        # Keep setup manual until active dataset availability is verified.
        'RUN rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent-rest-discovery\n'
        'RUN chmod 0755 /etc/s6-overlay/s6-rc.d/local-observe/run'
        + ('' if recovery else ' /etc/s6-overlay/scripts/otbr-agent-common /etc/s6-overlay/scripts/otbr-enable-check.sh /etc/s6-overlay/s6-rc.d/otbr-agent/run /etc/s6-overlay/s6-rc.d/otbr-agent/finish')
        + '\nARG BUILD_VERSION=' + config['version'] + '\nARG BUILD_ARCH=amd64\n'
        + 'LABEL io.hass.version="${BUILD_VERSION}" io.hass.type="app" io.hass.arch="${BUILD_ARCH}"\n'
        + 'ENTRYPOINT ["python3", "/usr/local/lib/local-service/state_guard.py"]\n')
    write('Dockerfile', dockerfile.encode())
    manifest = {'base': BASE, 'variant': 'recovery-otbr-off-only' if recovery else 'focused',
                'files': {str(p.relative_to(destination)): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(destination.rglob('*')) if p.is_file()}}
    write('build-manifest.json', (json.dumps(manifest, indent=2) + '\n').encode())


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('destination', type=Path)
    parser.add_argument('--recovery', action='store_true')
    args = parser.parse_args()
    generate(args.destination, args.recovery)
