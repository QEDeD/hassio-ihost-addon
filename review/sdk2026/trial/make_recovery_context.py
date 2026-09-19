#!/usr/bin/env python3
"""Generate a separate same-slug recovery-only image context; never installs it."""
import argparse
import contextlib
import hashlib
import io
import json
from pathlib import Path
import shutil
import tempfile

import make_context as trial

HERE = Path(__file__).resolve().parent


def generate(args):
    output = args.destination
    if not output.is_absolute() or output.exists() or output.is_symlink():
        raise ValueError('destination must be a new absolute directory')
    with tempfile.TemporaryDirectory(prefix='sdk2026-unbind-') as temporary:
        staging = Path(temporary)/'context'
        delegated = argparse.Namespace(**vars(args)); delegated.destination = staging
        with contextlib.redirect_stdout(io.StringIO()):
            trial.generate(delegated)
        config_path = staging/'config.json'
        config = json.loads(config_path.read_text())
        # Preserve existing options/schema for in-place update validation. All
        # modes except recover-unbind are nevertheless refused by this entrypoint.
        config['schema']['local_service_mode'] = 'list(prepare|run|bind-ecdh|recover-unbind|archive-binding)'
        config['description'] = 'Recovery-only: explicit unbind or separate CPC evidence archival; no network stacks'
        assert config['slug'] == 'codex_ihost_otbr_focused'
        assert config['options']['local_service_mode'] == 'prepare'
        config_path.write_text(json.dumps(config,indent=2)+'\n')
        target = staging/'rootfs/usr/local/lib/local-service/recovery_entrypoint.py'
        target.write_bytes((HERE/'recovery_entrypoint.py').read_bytes().replace(b'\r\n',b'\n'))
        marker = staging/'rootfs/usr/share/sdk2026-build/recovery-only'
        marker.write_bytes(b'cpc-unbind-only-v1\n')
        dockerfile = staging/'Dockerfile'
        old = 'ENTRYPOINT ["python3", "/usr/local/lib/local-service/trial_entrypoint.py"]'
        new = 'ENTRYPOINT ["python3", "/usr/local/lib/local-service/recovery_entrypoint.py"]'
        text = dockerfile.read_text()
        assert text.count(old) == 1
        dockerfile.write_text(text.replace(old,new)+'\nHEALTHCHECK NONE\n')
        manifest_path = staging/'build-manifest.json'
        manifest = json.loads(manifest_path.read_text())
        manifest['variant'] = 'recovery-only-explicit-cpc-unbind'
        manifest['normal_startup'] = 'refused; no init delegation'
        manifest['files'] = {p.relative_to(staging).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sorted(staging.rglob('*')) if p.is_file() and p != manifest_path}
        manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
        shutil.copytree(staging, output)
    print('Generated recovery-only context; no build, install, or radio operation performed.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination',type=Path)
    parser.add_argument('--helper-checkout',required=True,type=Path)
    parser.add_argument('--base-image',required=True)
    parser.add_argument('--expected-image-id',required=True)
    parser.add_argument('--image-inspect',required=True,type=Path)
    parser.add_argument('--device',required=True)
    parser.add_argument('--version',default='0.3.2-sdk2026-recovery-unbind')
    generate(parser.parse_args())


if __name__=='__main__': main()
