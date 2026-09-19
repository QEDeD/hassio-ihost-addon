#!/usr/bin/env python3
"""Recovery tests run offline in the candidate image; synthetic private state only."""
import contextlib
import io
import json
import os
from pathlib import Path
import signal
import tempfile
import unittest
from unittest.mock import patch
import recovery_entrypoint as r

FAKE = r'''#!/usr/bin/env python3
import json, os, pathlib, signal, sys, time
root=pathlib.Path(__file__).parent
root.joinpath('arguments').write_text(json.dumps(sys.argv[1:]))
assert root.joinpath('data/cpc-recovery/unbind-attempt').read_bytes()==b'cpc-unbind-attempt-v1\n'
scenario=root.joinpath('scenario').read_text()
print('NEVER_DISCLOSE_RAW_KEY',flush=True)
line='[2026-09-19T12:34:56.000001Z] INF : Unbind successful, you may restart the daemon without the --unbind argument'
if scenario=='timeout': time.sleep(30)
if scenario=='signal': os.kill(os.getpid(),signal.SIGTERM)
if scenario=='excess': print('x'*70000,flush=True)
if scenario=='split':
    sys.stdout.write(line[:45]); sys.stdout.flush(); time.sleep(.03); print(line[45:],flush=True)
elif scenario=='misleading': print('not '+line,flush=True)
elif scenario=='no-newline': sys.stdout.write(line); sys.stdout.flush()
elif scenario!='missing': print(line,flush=True)
sys.exit(3 if scenario=='nonzero' else 0)
'''

class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.root=Path(self.temp.name)
        self.data=self.root/'data'; self.data.mkdir(mode=0o700)
        self.target=self.root/'device'; self.target.write_text('/dev/serial/by-id/test-radio\n')
        self.marker=self.root/'recovery-only'; self.marker.write_bytes(r.IMAGE_BYTES)
        self.fake=self.root/'cpc'; self.fake.write_text(FAKE); self.fake.chmod(0o700)
        self.scenario=self.root/'scenario'; self.scenario.write_text('success')
        self.options={'local_service_mode':'recover-unbind','device':'/dev/serial/by-id/test-radio','baudrate':'115200','flow_control':False,'cpcd_trace':False}
        self.save_options()
        for name in ('cpc/binding.key','cpc/binding-attempt','thread/current.data','zigbee/host_token.nvm'):
            path=self.data/name; path.parent.mkdir(mode=0o700,exist_ok=True); path.write_bytes(b'PRIVATE_PARTIAL_OR_EXISTING_STATE\0')
        self.original={p.relative_to(self.data):p.read_bytes() for p in self.data.rglob('*') if p.is_file()}
        self.stack=contextlib.ExitStack()
        for module,name,value in [(r,'DATA',self.data),(r,'IMAGE_MARKER',self.marker),(r,'CONFIG',self.root/'recovery.conf'),(r,'TIMEOUT',.4),(r.common,'EXPECTED_DEVICE',self.target),(r.common,'CPC',str(self.fake)),(r.common,'CONFIG',self.root/'recovery.conf')]:
            self.stack.enter_context(patch.object(module,name,value))
        self.stack.enter_context(patch.object(r.common,'check_device'))
        self.exec=self.stack.enter_context(patch.object(r.os,'execv',side_effect=AssertionError('no init')))
        self.key=self.stack.enter_context(patch.object(r.common,'key_valid',side_effect=AssertionError('no key loading')))
        self.handlers=[signal.getsignal(s) for s in (signal.SIGINT,signal.SIGTERM)]
        self.umask=os.umask(0o077)
    def tearDown(self):
        self.exec.assert_not_called(); self.key.assert_not_called()
        for name,contents in self.original.items():
            if str(name)!='options.json':
                path=self.data/name
                if name.parts[0]=='cpc' and not (self.data/'cpc').exists(): path=self.data/'cpc-archive-before-rebind'/Path(*name.parts[1:])
                self.assertEqual(path.read_bytes(),contents)
        self.stack.close()
        for sig,handler in zip((signal.SIGINT,signal.SIGTERM),self.handlers): signal.signal(sig,handler)
        os.umask(self.umask); self.temp.cleanup()
    def save_options(self): (self.data/'options.json').write_text(json.dumps(self.options))
    def run_main(self):
        out=io.StringIO()
        with contextlib.redirect_stdout(out),contextlib.redirect_stderr(out): r.main()
        self.assertNotIn('NEVER_DISCLOSE',out.getvalue()); return out.getvalue()
    def test_success_one_unbind_no_host_key_change(self):
        self.assertIn('unbound confirmed',self.run_main())
        self.assertEqual(json.loads((self.root/'arguments').read_text()),['--conf',str(r.CONFIG),'--unbind'])
        self.assertEqual((self.data/'cpc-recovery'/r.RESULT).read_bytes(),r.RESULT_BYTES)
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
    def test_split_marker(self): self.scenario.write_text('split'); self.test_success_one_unbind_no_host_key_change()
    def failed(self,scenario):
        self.scenario.write_text(scenario)
        with self.assertRaises(Exception): self.run_main()
        self.assertTrue((self.data/'cpc-recovery'/r.ATTEMPT).exists())
        self.assertFalse((self.data/'cpc-recovery'/r.RESULT).exists())
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
    def test_nonzero(self): self.failed('nonzero')
    def test_missing_marker(self): self.failed('missing')
    def test_misleading_marker(self): self.failed('misleading')
    def test_unterminated_marker(self): self.failed('no-newline')
    def test_timeout(self): self.failed('timeout')
    def test_signal(self): self.failed('signal')
    def test_excess_output(self): self.failed('excess')
    def test_other_modes(self):
        for mode in ('prepare','run','bind-ecdh',''):
            self.options['local_service_mode']=mode; self.save_options()
            with self.assertRaisesRegex(r.common.Refused,'explicit'): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
    def test_missing_image_marker(self):
        self.marker.unlink()
        with self.assertRaises(Exception): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
    def test_invalid_options_before_attempt(self):
        self.options['flow_control']=True; self.save_options()
        with self.assertRaises(Exception): self.run_main()
        self.assertFalse((self.data/'cpc-recovery').exists())
    def test_lock_contention(self):
        with r.common.locked(self.data):
            with self.assertRaises(BlockingIOError): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
    def test_existing_result(self):
        path=self.data/'cpc-recovery'; path.mkdir(mode=0o700); (path/r.RESULT).write_bytes(r.RESULT_BYTES)
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
    def test_pending_import(self):
        (self.data/r.guard.PENDING).write_text('pending')
        with self.assertRaisesRegex(r.common.Refused,'import incomplete'): self.run_main()
    def test_attempt_fsync_failure_no_radio(self):
        real=r.guard.sync_dir
        def fail(path):
            if (path/r.ATTEMPT).exists(): raise OSError('PRIVATE')
            return real(path)
        with patch.object(r.guard,'sync_dir',side_effect=fail),self.assertRaises(OSError): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
    def test_result_fsync_failure_preserves_attempt(self):
        real=r.guard.sync_dir
        def fail(path):
            if (path/r.RESULT).exists(): raise OSError('PRIVATE')
            return real(path)
        with patch.object(r.guard,'sync_dir',side_effect=fail),self.assertRaises(OSError): self.run_main()
        self.assertTrue((self.data/'cpc-recovery'/r.ATTEMPT).exists())
        self.assertFalse((self.data/'cpc-recovery'/r.RESULT).exists())
    def test_cli_suppresses_exception_detail(self):
        output=io.StringIO()
        with patch.object(r,'main',side_effect=OSError('PRIVATE')),contextlib.redirect_stderr(output),self.assertRaises(SystemExit): r.cli()
        self.assertNotIn('PRIVATE',output.getvalue())

    def prepare_archive(self):
        self.options['local_service_mode']='archive-binding'; self.save_options()
        directory=self.data/'cpc-recovery'; directory.mkdir(mode=0o700)
        (directory/r.ATTEMPT).write_bytes(r.ATTEMPT_BYTES)
        (directory/r.RESULT).write_bytes(r.RESULT_BYTES)
    def test_archive_preserves_unknown_files_no_process_no_repeat(self):
        self.prepare_archive()
        unknown=self.data/'cpc/unknown'; unknown.mkdir(); (unknown/'future-state').write_bytes(b'unchanged')
        self.assertIn('archived unchanged',self.run_main())
        self.assertFalse((self.data/'cpc').exists())
        self.assertEqual((self.data/'cpc-archive-before-rebind/unknown/future-state').read_bytes(),b'unchanged')
        self.assertFalse((self.root/'arguments').exists())
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
    def test_archive_requires_exact_confirmation(self):
        self.prepare_archive(); (self.data/'cpc-recovery'/r.RESULT).write_text('ambiguous')
        with self.assertRaises(Exception): self.run_main()
        self.assertTrue((self.data/'cpc').exists())
    def test_archive_existing_destination_refused(self):
        self.prepare_archive(); (self.data/'cpc-archive-before-rebind').mkdir()
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
    def test_archive_symlink_source_refused(self):
        self.prepare_archive(); (self.data/'cpc').rename(self.root/'original-cpc'); (self.data/'cpc').symlink_to(self.root/'original-cpc',target_is_directory=True)
        with self.assertRaises(Exception): self.run_main()
    def test_archive_sync_failure_no_retry(self):
        self.prepare_archive(); real=r.guard.sync_dir
        def fail(path):
            if path==self.data and (path/'cpc-archive-before-rebind').exists(): raise OSError('PRIVATE')
            return real(path)
        with patch.object(r.guard,'sync_dir',side_effect=fail),self.assertRaises(OSError): self.run_main()
        self.assertFalse((self.data/'cpc').exists())
        with self.assertRaisesRegex(r.common.Refused,'repeat refused'): self.run_main()
        self.assertFalse((self.root/'arguments').exists())
if __name__=='__main__': unittest.main(verbosity=2)
