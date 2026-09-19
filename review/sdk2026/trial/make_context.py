#!/usr/bin/env python3
"""Generate one SDK2026 same-app context from verified existing local-service sources.
No Docker build, publication, HA API, binding or firmware action is performed.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
SOURCE_COMMIT = '391bb7c56e01ef34ae5ae0b8cd259f31fdb7d6d0'
HELPERS = 'hassio-ihost-silabs-multiprotocol/tools/local-service'


def git(checkout, *args):
    return subprocess.check_output(['git', '-C', str(checkout), *args])


def generate(args):
    source = args.helper_checkout.resolve()
    if git(source, 'rev-parse', 'HEAD').decode().strip() != SOURCE_COMMIT:
        raise ValueError('helper checkout revision differs from reviewed source')
    for name in ('make_trial_contexts.py', 'make_context.py', 'state_guard.py', 'observe.py', 'config.template.json'):
        path = HELPERS + '/' + name
        expected = git(source, 'show', SOURCE_COMMIT + ':' + path).replace(b'\r\n', b'\n')
        actual = (source/path).read_bytes().replace(b'\r\n', b'\n')
        if actual != expected:
            raise ValueError('helper source differs from reviewed commit: ' + name)
    output = args.destination
    if not output.is_absolute() or output.exists() or output.is_symlink():
        raise ValueError('destination must be a new absolute directory')
    if not re.fullmatch(r'/dev/serial/by-id/[A-Za-z0-9_.:-]+', args.device):
        raise ValueError('provide the exact by-id serial device')
    inspection = json.loads(args.image_inspect.read_text(encoding='utf-8-sig'))
    spec = importlib.util.spec_from_file_location('reviewed_trial_contexts', source/HELPERS/'make_trial_contexts.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with tempfile.TemporaryDirectory(prefix='sdk2026-context-') as temporary:
        staging = Path(temporary)/'contexts'
        module.generate(staging, args.base_image, args.expected_image_id, inspection,
                        candidate_version=args.version)
        candidate = staging/'candidate'
        config_path = candidate/'config.json'
        config = json.loads(config_path.read_text())
        assert config['slug'] == 'codex_ihost_otbr_focused'
        assert config['options']['local_service_mode'] == 'prepare'
        config['schema']['local_service_mode'] = 'list(prepare|run|bind-ecdh)'
        config['description'] = 'SDK2026.6.1 trial; explicit provisioning and current-state preservation'
        config_path.write_text(json.dumps(config, indent=2)+'\n')
        target = candidate/'rootfs/usr/local/lib/local-service/trial_entrypoint.py'
        target.write_bytes((HERE/'entrypoint.py').read_bytes().replace(b'\r\n',b'\n'))
        device = candidate/'rootfs/usr/share/sdk2026-build/bind-device'
        device.parent.mkdir(parents=True)
        device.write_text(args.device+'\n')
        dockerfile = candidate/'Dockerfile'
        old = 'ENTRYPOINT ["python3", "/usr/local/lib/local-service/state_guard.py"]'
        new = 'ENTRYPOINT ["python3", "/usr/local/lib/local-service/trial_entrypoint.py"]'
        text = dockerfile.read_text()
        assert text.count(old) == 1
        dockerfile.write_text(text.replace(old,new))
        manifest_path = candidate/'build-manifest.json'
        manifest = json.loads(manifest_path.read_text())
        manifest['helper_source_commit'] = SOURCE_COMMIT
        manifest['helper_source_path'] = HELPERS
        manifest['production_status'] = 'offline-preparation-only'
        manifest['files'] = {p.relative_to(candidate).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sorted(candidate.rglob('*')) if p.is_file() and p != manifest_path}
        manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
        # Only candidate is exported. Historical scaffold baseline/recovery images
        # are not the actual retained production rollback image and are discarded.
        shutil.copytree(candidate, output)
    print('Generated candidate context only; no build or production action performed.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination',type=Path)
    parser.add_argument('--helper-checkout',required=True,type=Path)
    parser.add_argument('--base-image',required=True)
    parser.add_argument('--expected-image-id',required=True)
    parser.add_argument('--image-inspect',required=True,type=Path)
    parser.add_argument('--device',required=True)
    parser.add_argument('--version',default='0.3.0-sdk2026')
    generate(parser.parse_args())

if __name__ == '__main__':
    main()
