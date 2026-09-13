#!/usr/bin/env python3
"""Prepare three same-app trial contexts; never invokes Docker or production APIs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('local_context', HERE / 'make_context.py')
legacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(legacy)


def inspected_image(reference, expected_id, inspection):
    # Deliberately accept only a simple tagged CI-local repository, not arbitrary
    # Dockerfile text, a raw image ID, or a registry digest as a FROM argument.
    if not isinstance(reference, str) or reference.startswith('sha256:') or not re.fullmatch(
            r'[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}', reference):
        raise ValueError('combined image must be a simple repository:tag reference')
    if not isinstance(expected_id, str) or not re.fullmatch(r'sha256:[0-9a-f]{64}', expected_id):
        raise ValueError('expected image ID must be sha256:<64 lowercase hex digits>')
    if not isinstance(inspection, list) or len(inspection) != 1 or not isinstance(inspection[0], dict):
        raise ValueError('provide the single-image JSON array from docker image inspect')
    record = inspection[0]
    tags = record.get('RepoTags')
    if not isinstance(tags, list) or any(not isinstance(tag, str) for tag in tags):
        raise ValueError('inspection must include a RepoTags list')
    if record.get('Id') != expected_id or reference not in tags:
        raise ValueError('combined image tag/ID does not match inspection')
    if record.get('Os') != 'linux' or record.get('Architecture') != 'amd64':
        raise ValueError('trial packaging requires a Linux AMD64 image')
    return {'reference': reference, 'id': expected_id, 'os': 'linux', 'architecture': 'amd64'}


def generate(destination, combined_image, expected_image_id, inspection,
             candidate_version='0.2.0-integrated', baseline_version='0.2.1-baseline',
             recovery_version='0.2.2-recovery'):
    destination = Path(destination)
    if not destination.is_absolute() or destination.exists() or destination.is_symlink():
        raise ValueError('destination must be a new absolute directory')
    identity = inspected_image(combined_image, expected_image_id, inspection)
    versions = (candidate_version, baseline_version, recovery_version)
    if len(set(versions)) != 3 or any(not isinstance(v, str) or not re.fullmatch(
            r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-z0-9][a-z0-9.-]*)?', v) for v in versions):
        raise ValueError('provide three distinct package versions')
    if set(versions) & {'0.1.4-local', '0.1.5-recovery'}:
        raise ValueError('trial versions must differ from existing local/recovery versions')
    for variant, version in zip(('candidate', 'baseline', 'recovery'), versions):
        target = destination / variant
        # Keep the original generator and its source-hash checks intact. Recovery
        # scaffolding contains no historical runtime overlay, as required by the
        # integrated candidate. Baseline alone gets the known five-file overlay.
        legacy.generate(target, recovery=variant != 'baseline')
        config_path = target / 'config.json'
        config = json.loads(config_path.read_text())
        old_version = config['version']
        config['version'] = version
        config['options']['otbr_nat64'] = False
        config['schema']['otbr_nat64'] = 'bool'
        config_path.write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
        docker_path = target / 'Dockerfile'
        dockerfile = docker_path.read_text().replace('ARG BUILD_VERSION=' + old_version + '\n',
                                                   'ARG BUILD_VERSION=' + version + '\n')
        if variant == 'candidate':
            dockerfile = dockerfile.replace('FROM ' + legacy.BASE + '\n', 'FROM ' + combined_image + '\n', 1)
            # Override any inherited recovery mode as well as the scaffold gate.
            dockerfile = dockerfile.replace('ENV LOCAL_SERVICE_RECOVERY=1\n', 'ENV LOCAL_SERVICE_RECOVERY=0\n', 1)
        docker_path.write_text(dockerfile, encoding='utf-8')
        manifest_path = target / 'build-manifest.json'
        manifest = {'variant': variant, 'version': version, 'slug': config['slug'],
                    'base': identity if variant == 'candidate' else {'reference': legacy.BASE},
                    'files': {p.relative_to(target).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted(target.rglob('*')) if p.is_file() and p != manifest_path}}
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--combined-image', required=True)
    parser.add_argument('--expected-image-id', required=True)
    parser.add_argument('--image-inspect', required=True, type=Path)
    parser.add_argument('--candidate-version', default='0.2.0-integrated')
    parser.add_argument('--baseline-version', default='0.2.1-baseline')
    parser.add_argument('--recovery-version', default='0.2.2-recovery')
    args = parser.parse_args()
    generate(args.destination, args.combined_image, args.expected_image_id,
             json.loads(args.image_inspect.read_text(encoding='utf-8-sig')),
             args.candidate_version, args.baseline_version, args.recovery_version)


if __name__ == '__main__':
    main()
