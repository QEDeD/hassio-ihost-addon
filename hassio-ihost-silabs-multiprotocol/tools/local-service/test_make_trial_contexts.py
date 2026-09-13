import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('trial_contexts', Path(__file__).with_name('make_trial_contexts.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class TrialPackageTests(unittest.TestCase):
    reference = 'local/otbr-integrated:ci-test'
    image_id = 'sha256:' + 'a' * 64

    def inspection(self):
        return [{'Id': self.image_id, 'RepoTags': [self.reference], 'Os': 'linux', 'Architecture': 'amd64'}]

    def generate(self, destination, **kwargs):
        m.generate(destination, self.reference, self.image_id, self.inspection(), **kwargs)

    def test_three_contexts_keep_options_guards_and_distinct_identities(self):
        original = json.loads((m.HERE / 'config.template.json').read_text())
        expected_options = dict(original['options'], otbr_nat64=False)
        expected_schema = dict(original['schema'], otbr_nat64='bool')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / 'contexts'
            self.generate(root)
            versions = set()
            for variant in ('candidate', 'baseline', 'recovery'):
                target = root / variant
                config = json.loads((target / 'config.json').read_text())
                versions.add(config['version'])
                expected_config = dict(original, version=config['version'], options=expected_options, schema=expected_schema)
                self.assertEqual(config, expected_config)
                docker = (target / 'Dockerfile').read_text()
                self.assertIn('ENTRYPOINT ["python3", "/usr/local/lib/local-service/state_guard.py"]', docker)
                self.assertIn('RUN rm /etc/s6-overlay/s6-rc.d/user/contents.d/otbr-agent-rest-discovery', docker)
                self.assertIn('ARG BUILD_VERSION=' + config['version'], docker)
                self.assertEqual('ENV LOCAL_SERVICE_RECOVERY=1' in docker, variant == 'recovery')
                for name in ('state_guard.py', 'observe.py'):
                    self.assertEqual((target / 'rootfs/usr/local/lib/local-service' / name).read_bytes(), m.legacy.normalized(m.HERE / name))
                for name, digest in m.legacy.RUNTIME.items():
                    runtime = target / name
                    self.assertEqual(runtime.exists(), variant == 'baseline')
                    if variant == 'baseline':
                        self.assertEqual(hashlib.sha256(runtime.read_bytes()).hexdigest(), digest)
                manifest = json.loads((target / 'build-manifest.json').read_text())
                expected_files = {p.relative_to(target).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in target.rglob('*') if p.is_file() and p.name != 'build-manifest.json'}
                self.assertEqual(manifest['files'], expected_files)
                if variant == 'candidate':
                    self.assertTrue(docker.startswith('FROM ' + self.reference + '\n'))
                    self.assertIn('ENV LOCAL_SERVICE_RECOVERY=0\n', docker)
                    self.assertNotIn(m.legacy.BASE, docker)
                    self.assertEqual(manifest['base']['id'], self.image_id)
                else:
                    self.assertTrue(docker.startswith('FROM ' + m.legacy.BASE + '\n'))
            self.assertEqual(len(versions), 3)

    def test_reproducible_and_rejects_existing_or_relative_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a', Path(tmp) / 'b'
            self.generate(a)
            self.generate(b)
            for variant in ('candidate', 'baseline', 'recovery'):
                self.assertEqual((a / variant / 'build-manifest.json').read_bytes(), (b / variant / 'build-manifest.json').read_bytes())
            for destination in (a, Path('relative-trial-context')):
                with self.assertRaises(ValueError):
                    self.generate(destination)

    def test_rejects_invalid_refs_and_inspection_before_writing(self):
        cases = [(ref, self.image_id, self.inspection()) for ref in
                 ('latest', 'repo:tag\nRUN bad', 'sha256:' + 'a' * 64, 'repo@sha256:' + 'a' * 64, '-repo:tag')]
        # A raw image ID has the lexical shape of a tag but is never a named tag
        # in real inspect output; an explicit lexical rejection is required too.
        cases += [(self.reference, 'sha256:abc', self.inspection()),
                  (self.reference, self.image_id, []),
                  (self.reference, self.image_id, self.inspection() * 2)]
        for key, value in [('Id', 'sha256:' + 'b' * 64), ('RepoTags', []),
                           ('Architecture', 'arm64'), ('Os', 'windows')]:
            record = copy.deepcopy(self.inspection())
            record[0][key] = value
            cases.append((self.reference, self.image_id, record))
        with tempfile.TemporaryDirectory() as tmp:
            for n, (reference, image_id, inspection) in enumerate(cases):
                destination = Path(tmp) / str(n)
                with self.subTest(reference=reference, inspection=inspection):
                    with self.assertRaises(ValueError):
                        m.generate(destination, reference, image_id, inspection)
                    self.assertFalse(destination.exists())

    def test_distinct_safe_versions_required(self):
        with tempfile.TemporaryDirectory() as tmp:
            for kwargs in ({'baseline_version': '0.2.0-integrated'},
                           {'candidate_version': '0.1.4-local'},
                           {'recovery_version': '0.2.0\nRUN bad'}):
                with self.assertRaises(ValueError):
                    self.generate(Path(tmp) / 'contexts', **kwargs)
                self.assertFalse((Path(tmp) / 'contexts').exists())

    def test_historical_hash_gate_is_still_enforced(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(m.legacy.RUNTIME, {next(iter(m.legacy.RUNTIME)): '0' * 64}):
            destination = Path(tmp) / 'contexts'
            with self.assertRaisesRegex(ValueError, 'focused runtime identity mismatch'):
                self.generate(destination)
            self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
