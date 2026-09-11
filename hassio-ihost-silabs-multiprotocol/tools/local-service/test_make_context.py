import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('make_context', Path(__file__).with_name('make_context.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class PackageTests(unittest.TestCase):
    def test_fixed_and_recovery_identity_defaults_and_reproducibility(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, recovery in [('fixed', False), ('fixed2', False), ('recovery', True)]:
                m.generate(root / name, recovery)
                config = json.loads((root / name / 'config.json').read_text())
                self.assertEqual(config['slug'], 'codex_ihost_otbr_focused')
                self.assertEqual(config['boot'], 'manual')
                self.assertIs(config['options']['otbr_enable'], False)
                self.assertEqual(config['options']['local_service_mode'], 'prepare')
                self.assertIs(config['host_pid'], False)
                dockerfile = (root / name / 'Dockerfile').read_text()
                self.assertIn(m.BASE, dockerfile)
                self.assertIn('LABEL io.hass.version=', dockerfile)
                self.assertEqual('ENV LOCAL_SERVICE_RECOVERY=1' in dockerfile, recovery)
                self.assertEqual((root / name / next(iter(m.RUNTIME))).exists(), not recovery)
                self.assertNotIn('trial-deadline', str(list((root / name).rglob('*'))))
            self.assertEqual((root / 'fixed/build-manifest.json').read_bytes(),
                             (root / 'fixed2/build-manifest.json').read_bytes())
            with self.assertRaises(ValueError):
                m.generate(root / 'fixed')


if __name__ == '__main__':
    unittest.main()
