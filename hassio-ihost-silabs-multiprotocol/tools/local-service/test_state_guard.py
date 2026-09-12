"""Synthetic archives and private temp dirs only; never accesses HA or a radio."""
import copy
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import tarfile
import tempfile
import time
import tracemalloc
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('guard', Path(__file__).with_name('state_guard.py'))
g = importlib.util.module_from_spec(spec)
spec.loader.exec_module(g)


def tar_bytes(entries):
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode='w', format=tarfile.USTAR_FORMAT) as tf:
        for name, value, kind in entries:
            m = tarfile.TarInfo(name)
            m.type = kind
            m.size = len(value) if kind == tarfile.REGTYPE else 0
            if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE):
                m.linkname = '/do-not-follow'
            tf.addfile(m, io.BytesIO(value) if m.size else None)
    return out.getvalue()


class StateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = self.root / 'data'
        self.data.mkdir()
        self.backup = self.root / 'backup'
        self.backup.mkdir()
        self.values = {'thread': b'new-thread-state' * 20, 'zigbee': b'fresh-zigbee-state' * 100}
        self.manifest = {'version': 1, 'expires_at': int(time.time()) + 600, 'sources': {}}
        for role, slug in [('thread', '11111111'), ('zigbee', '22222222')]:
            value = self.values[role]
            self.manifest['sources'][role] = {'backup_slug': slug, 'app_slug': g.SOURCE_APPS[role],
                'size': len(value), 'sha256': hashlib.sha256(value).hexdigest()}
            self.archive(role)
        self.options = b'{"local_service_mode":"prepare","device":"private-fixture","otbr_enable":false}'
        (self.data / 'options.json').write_bytes(self.options)

    def archive(self, role, mutate=None, image_size=0, outer_mutate=None):
        entries = [('./', b'', tarfile.DIRTYPE), ('./addon.json', b'{}', tarfile.REGTYPE)]
        if image_size:
            entries.append(('./image.tar', b'x' * image_size, tarfile.REGTYPE))
        entries += [('data/', b'', tarfile.DIRTYPE),
                    ('data/options.json', b'{"wrong":"never import options"}', tarfile.REGTYPE),
                    ('data/' + g.FILES[role], self.values[role], tarfile.REGTYPE)]
        other = 'zigbee' if role == 'thread' else 'thread'
        entries.append(('data/' + g.FILES[other], b'STALE OTHER RADIO', tarfile.REGTYPE))
        if mutate:
            entries = mutate(entries)
        packed = gzip.compress(tar_bytes(entries))
        outer = [('backup.json', b'{}', tarfile.REGTYPE),
                 (g.SOURCE_APPS[role] + '.tar.gz', packed, tarfile.REGTYPE)]
        if outer_mutate:
            outer = outer_mutate(outer)
        path = self.backup / (self.manifest['sources'][role]['backup_slug'] + '.tar')
        path.write_bytes(tar_bytes(outer))
        return path

    def prepare(self):
        g.prepare(self.data, self.backup, self.manifest)

    def test_two_source_selection_preserves_options_and_permissions(self):
        self.prepare()
        for role, relative in g.FILES.items():
            p = self.data / relative
            self.assertEqual(p.read_bytes(), self.values[role])
            self.assertEqual(stat.S_IMODE(p.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(p.parent.stat().st_mode), 0o700)
        self.assertEqual((self.data / 'options.json').read_bytes(), self.options)
        self.assertFalse((self.data / g.STARTED).exists())
        self.assertFalse((self.data / g.PENDING).exists())

    def test_large_image_streamed_before_selected_member(self):
        self.archive('thread', image_size=32 * 1024 * 1024)
        tracemalloc.start()
        try:
            result = g.source_file(self.backup, 'thread', self.manifest['sources']['thread'])
            _, peak = tracemalloc.get_traced_memory()
        finally:
            tracemalloc.stop()
        self.assertEqual(result, self.values['thread'])
        self.assertLess(peak, 4 * 1024 * 1024, 'image must not be loaded into memory')

    def test_radio_restarts_preserve_new_state_and_never_reseed(self):
        self.prepare()
        g.authorize_start(self.data)
        for relative in g.FILES.values():
            (self.data / relative).write_bytes(b'newest-running-state')
        g.authorize_start(self.data)
        g.authorize_start(self.data)
        with self.assertRaises(ValueError):
            self.prepare()
        for relative in g.FILES.values():
            self.assertEqual((self.data / relative).read_bytes(), b'newest-running-state')

    def test_first_start_rejects_changed_seed(self):
        self.prepare()
        (self.data / g.FILES['thread']).write_bytes(b'changed')
        with self.assertRaises(ValueError):
            g.authorize_start(self.data)
        self.assertFalse((self.data / g.STARTED).exists())

    def test_interrupted_import_refuses_start_and_retry(self):
        original = g.atomic_write
        def fail(path, value):
            if path.name == 'host_token.nvm':
                raise OSError('simulated power failure')
            original(path, value)
        with patch.object(g, 'atomic_write', side_effect=fail):
            with self.assertRaises(OSError):
                self.prepare()
        self.assertTrue((self.data / g.PENDING).exists())
        with self.assertRaises(ValueError):
            g.authorize_start(self.data)
        with self.assertRaises(ValueError):
            self.prepare()

    def test_expiry_wrong_roles_wrong_app_and_wrong_fingerprints(self):
        base = copy.deepcopy(self.manifest)
        mutations = [lambda m: m.update(expires_at=0), lambda m: m.update(expires_at=True),
            lambda m: m.update(expires_at=int(time.time()) + 10000),
            lambda m: m['sources']['thread'].update(app_slug=g.SOURCE_APPS['zigbee']),
            lambda m: m['sources']['zigbee'].update(backup_slug='../wrong'),
            lambda m: m['sources']['zigbee'].update(sha256='0' * 64),
            lambda m: m['sources']['thread'].update(size=g.MAX_FILE + 1),
            lambda m: m['sources'].update(extra={})]
        for mutate in mutations:
            self.manifest = copy.deepcopy(base)
            mutate(self.manifest)
            with self.subTest(mutate=mutate):
                with self.assertRaises((ValueError, FileNotFoundError)):
                    self.prepare()
                self.assertEqual({p.name for p in self.data.iterdir()}, {'options.json'})

    def test_preexisting_state_and_symlinks_never_overwritten(self):
        external = self.root / 'external'
        external.mkdir()
        (self.data / 'thread').symlink_to(external, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(list(external.iterdir()), [])

    def test_missing_duplicate_link_traversal_extensions_and_late_duplicate(self):
        wanted = 'data/' + g.FILES['thread']
        mutations = [lambda es: [x for x in es if x[0] != wanted],
            lambda es: es + [(wanted, self.values['thread'], tarfile.REGTYPE)],
            lambda es: es + [('./' + wanted, self.values['thread'], tarfile.REGTYPE)],
            lambda es: es + [('../escape', b'x', tarfile.REGTYPE)],
            lambda es: es + [('/absolute', b'x', tarfile.REGTYPE)],
            lambda es: es + [('link', b'', tarfile.SYMTYPE)],
            lambda es: es + [('hardlink', b'', tarfile.LNKTYPE)],
            lambda es: es + [('pax', b'', tarfile.XHDTYPE)],
            lambda es: es + [('fifo', b'', tarfile.FIFOTYPE)],
            lambda es: es + [('sparse', b'', tarfile.GNUTYPE_SPARSE)]]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                self.archive('thread', mutate=mutate)
                with self.assertRaises((ValueError, tarfile.TarError)):
                    self.prepare()
                self.assertEqual({p.name for p in self.data.iterdir()}, {'options.json'})

    def test_outer_duplicate_truncation_bad_crc_and_work_budget(self):
        self.archive('thread', outer_mutate=lambda es: es + [es[-1]])
        with self.assertRaises(ValueError):
            self.prepare()
        path = self.archive('thread')
        path.write_bytes(path.read_bytes()[:1500])
        with self.assertRaises((ValueError, EOFError)):
            self.prepare()
        self.archive('thread', outer_mutate=lambda es: [es[0], (es[1][0], es[1][1][:-8] + bytes(8), es[1][2])])
        with self.assertRaises((ValueError, gzip.BadGzipFile, EOFError)):
            self.prepare()
        self.archive('thread', image_size=8192)
        with self.assertRaises(ValueError):
            list(g.members(io.BytesIO(tar_bytes([('big', b'x' * 8192, tarfile.REGTYPE)])), budget=4096))

    def test_missing_or_unsafe_current_state_blocks_restart(self):
        self.prepare()
        g.authorize_start(self.data)
        p = self.data / g.FILES['zigbee']
        p.unlink()
        target = self.root / 'elsewhere'
        target.write_bytes(b'private')
        os.link(target, p)
        with self.assertRaises(ValueError):
            g.authorize_start(self.data)

    def test_first_run_and_recovery_require_exact_otbr_false(self):
        self.prepare()
        argv = ['guard', '--data', str(self.data)]
        for value in (True, None, 0, 'false'):
            (self.data / 'options.json').write_text(json.dumps({'local_service_mode': 'run', 'otbr_enable': value}))
            with patch.object(g.sys, 'argv', argv), patch.object(g.os, 'execv') as start:
                with self.assertRaises(ValueError):
                    g.main()
                start.assert_not_called()
            self.assertFalse((self.data / g.STARTED).exists())
        g.authorize_start(self.data)
        for value in (True, None, 0, 'false'):
            (self.data / 'options.json').write_text(json.dumps({'local_service_mode': 'run', 'otbr_enable': value}))
            with patch.dict(g.os.environ, {'LOCAL_SERVICE_RECOVERY': '1'}), patch.object(g.sys, 'argv', argv), patch.object(g.os, 'execv') as start:
                with self.assertRaises(ValueError):
                    g.main()
                start.assert_not_called()
        for recovery in ('0', '1'):
            (self.data / 'options.json').write_text(json.dumps({'local_service_mode': 'run', 'otbr_enable': False}))
            with patch.dict(g.os.environ, {'LOCAL_SERVICE_RECOVERY': recovery}), patch.object(g.sys, 'argv', argv), patch.object(g.os, 'execv') as start:
                g.main()
                start.assert_called_once_with('/init', ['/init'])

    def test_default_mode_has_no_radio_execution(self):
        manifest_path = self.root / 'manifest.json'
        manifest_path.write_text(json.dumps(self.manifest))
        argv = ['guard', '--data', str(self.data), '--backup', str(self.backup), '--manifest', str(manifest_path)]
        with patch.object(g.sys, 'argv', argv), patch.object(g.os, 'execv') as start:
            g.main()
            start.assert_not_called()
        options = json.loads(self.options)
        options['local_service_mode'] = 'run'
        (self.data / 'options.json').write_text(json.dumps(options))
        with patch.object(g.sys, 'argv', argv), patch.object(g.os, 'execv') as start:
            g.main()
            start.assert_called_once_with('/init', ['/init'])



class PaxTimestampTests(unittest.TestCase):
    def archive(self, record):
        header = tarfile.TarInfo('././@PaxHeader')
        header.type = tarfile.XHDTYPE
        header.size = len(record)
        prefix = header.tobuf(format=tarfile.USTAR_FORMAT) + record + bytes((-len(record)) % 512)
        return prefix, tar_bytes([('data/state', b'synthetic', tarfile.REGTYPE)])

    def test_real_format_timestamp_only_is_ignored(self):
        record = b'28 mtime=1788895961.2191470\n'
        self.assertEqual(len(record), 28)
        prefix, body = self.archive(record)
        result = []
        for name, info, payload in g.members(io.BytesIO(prefix + body)):
            result.append((name, payload.read(info.size)))
        self.assertEqual(result, [('data/state', b'synthetic')])

    def test_unsafe_or_malformed_metadata_rejected(self):
        for record in [b'20 path=../../evil\n', b'12 size=999\n', b'12 mtime=1\n',
                       b'11 mtime=1\n11 mtime=2\n', b'x' * 129, b'']:
            with self.subTest(record=record):
                prefix, body = self.archive(record)
                with self.assertRaises(ValueError):
                    list(g.members(io.BytesIO(prefix + body)))

    def test_dangling_consecutive_and_budget_rejected(self):
        prefix, body = self.archive(b'11 mtime=1\n')
        for archive, budget in [(prefix + bytes(1024), 4096),
                                (prefix + prefix + body, 4096),
                                (prefix + body, 512)]:
            with self.assertRaises(ValueError):
                list(g.members(io.BytesIO(archive), budget=budget))

if __name__ == '__main__':
    unittest.main()
