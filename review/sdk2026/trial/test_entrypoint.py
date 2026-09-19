#!/usr/bin/env python3
"""Run inside isolated candidate image, using real tempio and private synthetic state."""
import contextlib
import fcntl
import io
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import entrypoint as e

FAKE = r'''#!/usr/bin/env python3
import os, pathlib, signal, subprocess, sys, time
key=pathlib.Path(sys.argv[sys.argv.index('--key')+1])
scenario=pathlib.Path(__file__).with_name('scenario').read_text()
print('NEVER_DISCLOSE_RAW_OUTPUT_OR_KEY', flush=True)
if scenario in ('timeout','group'):
    if scenario=='group':
        child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'])
        key.parent.joinpath('child.pid').write_text(str(child.pid))
    time.sleep(30)
if scenario=='signal': os.kill(os.getpid(),signal.SIGTERM)
if scenario not in ('missing','nonzero'):
    key.write_bytes(b'01'*16+b'\x00' if scenario not in ('partial','badmode') else b'01')
    os.chmod(key,0o600 if scenario!='badmode' else 0o644)
if scenario!='nomarker': print('[2026-09-19T12:34:56.000001Z] INF : Binding successful',flush=True)
sys.exit(4 if scenario=='nonzero' else 0)
'''

class BindingTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name); self.data=self.root/'data'; self.data.mkdir(mode=0o700)
        self.target=self.root/'device'; self.target.write_text('/dev/serial/by-id/test-radio\n')
        self.fake=self.root/'cpc'; self.fake.write_text(FAKE); self.fake.chmod(0o700)
        self.scenario=self.root/'scenario'; self.scenario.write_text('success')
        self.options={'local_service_mode':'bind-ecdh','device':'/dev/serial/by-id/test-radio',
                      'baudrate':'115200','flow_control':False,'cpcd_trace':False}
        self.save_options()
        self.stack=contextlib.ExitStack()
        for name,value in [('DATA',self.data),('EXPECTED_DEVICE',self.target),('CPC',str(self.fake)),
                           ('CONFIG',self.root/'cpc.conf'),('BIND_TIMEOUT',0.5)]:
            self.stack.enter_context(patch.object(e,name,value))
        # Physical serial presence is the ONLY skipped bind precondition. Real
        # tempio, real key checker, marker filesystem and child processes run.
        self.device=self.stack.enter_context(patch.object(e,'check_device'))
        self.exec=self.stack.enter_context(patch.object(e.os,'execv'))
        self.before_handlers=[signal.getsignal(s) for s in (signal.SIGINT,signal.SIGTERM)]
        self.old_umask=os.umask(0o077)
    def tearDown(self):
        self.stack.close()
        for sig,handler in zip((signal.SIGINT,signal.SIGTERM),self.before_handlers): signal.signal(sig,handler)
        os.umask(self.old_umask); self.temp.cleanup()
    def save_options(self):
        (self.data/'options.json').write_text(json.dumps(self.options))
    def run_main(self):
        output=io.StringIO()
        with contextlib.redirect_stdout(output),contextlib.redirect_stderr(output):
            e.main()
        self.assertNotIn('NEVER_DISCLOSE',output.getvalue())
        self.assertNotIn('01010101',output.getvalue())
        return output.getvalue()
    def failed_attempt(self,scenario):
        self.scenario.write_text(scenario)
        with self.assertRaises(Exception): self.run_main()
        self.assertTrue((self.data/'cpc'/e.ATTEMPT).exists())
        self.assertFalse((self.data/'cpc'/e.COMPLETE).exists())
        self.exec.assert_not_called()
        self.scenario.write_text('success')
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
        self.options['local_service_mode']='run'; self.save_options()
        with self.assertRaisesRegex(e.Refused,'incomplete'): self.run_main()
    def test_success_nul_no_init_no_repeat_and_explicit_run(self):
        self.assertIn('app remains stopped',self.run_main())
        self.assertEqual((self.data/'cpc/binding.key').read_bytes(),b'01'*16+b'\0')
        self.assertEqual((self.data/'cpc'/e.COMPLETE).read_bytes(),e.COMPLETE_BYTES)
        self.exec.assert_not_called()
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
        self.options['local_service_mode']='run'; self.save_options(); self.run_main()
        self.exec.assert_called_once_with(sys.executable,[sys.executable,e.GUARD])
    def test_nonzero(self): self.failed_attempt('nonzero')
    def test_missing(self): self.failed_attempt('missing')
    def test_partial(self): self.failed_attempt('partial')
    def test_no_success_marker(self): self.failed_attempt('nomarker')
    def test_signal(self): self.failed_attempt('signal')
    def test_timeout(self): self.failed_attempt('timeout')
    def test_timeout_cleans_descendant_group(self):
        self.failed_attempt('group')
        pid=int((self.data/'cpc/child.pid').read_text())
        status=Path('/proc')/str(pid)/'stat'
        for _ in range(30):
            if not status.exists() or status.read_text().split()[2]=='Z': break
            time.sleep(.02)
        else: self.fail('descendant survived process-group cleanup')
    def test_prior_key_never_replaced(self):
        directory=self.data/'cpc'; directory.mkdir(mode=0o700)
        key=directory/'binding.key'; key.write_bytes(b'prior-invalid-or-partial')
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
        self.assertEqual(key.read_bytes(),b'prior-invalid-or-partial')
        self.assertFalse((directory/e.ATTEMPT).exists())
    def test_existing_attempt_even_without_key(self):
        directory=self.data/'cpc'; directory.mkdir(mode=0o700); (directory/e.ATTEMPT).write_bytes(e.ATTEMPT_BYTES)
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
    def test_existing_complete_even_without_attempt(self):
        directory=self.data/'cpc'; directory.mkdir(mode=0o700); (directory/e.COMPLETE).write_bytes(e.COMPLETE_BYTES)
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
        self.options['local_service_mode']='run'; self.save_options()
        with self.assertRaisesRegex(e.Refused,'incomplete'): self.run_main()
    def test_lock_contention(self):
        with e.locked(self.data):
            with self.assertRaises(BlockingIOError): self.run_main()
        self.assertFalse((self.data/'cpc').exists())
    def test_key_fsync_failure_blocks_run(self):
        real=e.os.fsync
        def fail_key(fd):
            if os.readlink('/proc/self/fd/'+str(fd)).endswith('/binding.key'): raise OSError('SECRET_ERROR')
            return real(fd)
        with patch.object(e.os,'fsync',side_effect=fail_key):
            with self.assertRaises(OSError): self.run_main()
        self.assertTrue((self.data/'cpc/binding.key').exists())
        self.assertFalse((self.data/'cpc'/e.COMPLETE).exists())
        self.options['local_service_mode']='run'; self.save_options()
        with self.assertRaisesRegex(e.Refused,'incomplete'): self.run_main()
    def test_intent_fsync_failure_never_spawns_cpc(self):
        real=e.guard.sync_dir
        def fail(path):
            if (path/e.ATTEMPT).exists(): raise OSError('fsync failed')
            return real(path)
        with patch.object(e.guard,'sync_dir',side_effect=fail):
            with self.assertRaises(OSError): self.run_main()
        self.assertTrue((self.data/'cpc'/e.ATTEMPT).exists())
        self.assertFalse((self.data/'cpc/binding.key').exists())
    def test_abort_after_intent_never_retries(self):
        real=e.command
        def abort(args,*rest):
            if args[0]==str(self.fake): raise KeyboardInterrupt()
            return real(args,*rest)
        with patch.object(e,'command',side_effect=abort):
            with self.assertRaises(KeyboardInterrupt): self.run_main()
        self.assertTrue((self.data/'cpc'/e.ATTEMPT).exists())
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
    def test_config_failure_precedes_attempt(self):
        with patch.object(e,'TEMP','/bin/false'):
            with self.assertRaisesRegex(e.Refused,'config generation'): self.run_main()
        self.assertFalse((self.data/'cpc').exists())
    def test_unsafe_options_precede_attempt(self):
        for name,value in [('device','/dev/serial/by-id/other'),('baudrate','460800'),('flow_control',True),
                           ('network_device','other:123'),('cpcd_trace',True)]:
            with self.subTest(name=name):
                options=dict(self.options); options[name]=value
                with self.assertRaises(e.Refused): e.bind(self.data,options)
                self.assertFalse((self.data/'cpc').exists())
    def test_plaintext_mode_refused(self):
        off=self.root/'mode'; off.write_text('OFF\n')
        with patch.object(e,'MODE',off):
            with self.assertRaisesRegex(e.Refused,'encryption'): self.run_main()
        self.assertFalse((self.data/'cpc').exists())
    def test_incomplete_import_refused(self):
        (self.data/e.guard.PENDING).write_text('pending')
        with self.assertRaisesRegex(e.Refused,'import'): self.run_main()
    def test_complete_marker_corruption_blocks_run(self):
        self.run_main(); (self.data/'cpc'/e.COMPLETE).write_text('wrong')
        self.options['local_service_mode']='run'; self.save_options()
        with self.assertRaisesRegex(e.Refused,'markers'): self.run_main()
    def test_prepare_delegates_without_radio(self):
        self.options['local_service_mode']='prepare'; self.save_options(); self.run_main()
        self.exec.assert_called_once(); self.device.assert_not_called()
    def test_output_limit_aborts_without_disclosing(self):
        script=self.root/'noisy'; script.write_text('#!/bin/sh\nprintf NEVER_DISCLOSE_RAW_OUTPUT_OR_KEY\n'); script.chmod(0o700)
        with patch.object(e,'OUTPUT_LIMIT',8):
            with self.assertRaisesRegex(e.Refused,'safe bound'): e.command([str(script)],1)
    def test_actual_tempio_has_no_ha_auth_dependency(self):
        e.render(self.options,self.options['device'])
        text=e.CONFIG.read_text()
        self.assertIn('disable_encryption: false',text)
        self.assertIn('binding_key_file: /data/cpc/binding.key',text)
        self.assertIn('uart_device_baud: 115200',text)
        self.assertFalse((self.data/'cpc').exists())

    def test_wrapper_sigterm_cleans_process_group_and_no_output(self):
        self.scenario.write_text('group')
        code = ('import sys; from pathlib import Path; import entrypoint as e; '
                'e.DATA=Path('+repr(str(self.data))+'); '
                'e.EXPECTED_DEVICE=Path('+repr(str(self.target))+'); '
                'e.CPC='+repr(str(self.fake))+'; '
                'e.CONFIG=Path('+repr(str(self.root/'cpc.conf'))+'); '
                'e.BIND_TIMEOUT=60; e.check_device=lambda expected: None; e.cli()')
        process=subprocess.Popen([sys.executable,'-c',code],cwd=Path(e.__file__).parent,
                                 stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        try:
            marker=self.data/'cpc/child.pid'
            for _ in range(100):
                if marker.exists(): break
                if process.poll() is not None: self.fail('wrapper exited before signal test')
                time.sleep(.02)
            else: self.fail('child did not start')
            os.kill(process.pid,signal.SIGTERM)
            output=process.communicate(timeout=6)[0]
            self.assertNotEqual(process.returncode,0)
            self.assertNotIn(b'NEVER_DISCLOSE',output)
            self.assertNotIn(b'01010101',output)
            self.assertIn(b'interrupted',output)
            self.assertFalse((self.data/'cpc'/e.COMPLETE).exists())
            status=Path('/proc')/marker.read_text()/'stat'
            for _ in range(30):
                if not status.exists() or status.read_text().split()[2]=='Z': break
                time.sleep(.02)
            else: self.fail('grandchild survived wrapper termination')
        finally:
            if process.poll() is None: process.kill(); process.wait()
    def test_completion_fsync_failure_removes_success_claim(self):
        real=e.guard.sync_dir
        def fail(path):
            if (path/e.COMPLETE).exists(): raise OSError('completion sync failed')
            return real(path)
        with patch.object(e.guard,'sync_dir',side_effect=fail):
            with self.assertRaises(OSError): self.run_main()
        self.assertTrue((self.data/'cpc/binding.key').exists())
        self.assertTrue((self.data/'cpc'/e.ATTEMPT).exists())
        self.assertFalse((self.data/'cpc'/e.COMPLETE).exists())
        self.options['local_service_mode']='run'; self.save_options()
        with self.assertRaisesRegex(e.Refused,'incomplete'): self.run_main()
    def test_symlink_key_never_followed(self):
        directory=self.data/'cpc'; directory.mkdir(mode=0o700)
        destination=self.root/'other'; destination.write_bytes(b'preserve')
        (directory/'binding.key').symlink_to(destination)
        with self.assertRaisesRegex(e.Refused,'repeat refused'): self.run_main()
        self.assertEqual(destination.read_bytes(),b'preserve')
    def test_cli_sanitizes_arbitrary_errors(self):
        output=io.StringIO()
        with patch.object(e,'main',side_effect=OSError('NEVER_DISCLOSE_RAW_OUTPUT_OR_KEY')):
            with contextlib.redirect_stdout(output),contextlib.redirect_stderr(output):
                with self.assertRaises(SystemExit) as outcome: e.cli()
        self.assertEqual(outcome.exception.code,1)
        self.assertNotIn('NEVER_DISCLOSE',output.getvalue())

    def test_split_vendor_success_marker(self):
        script=self.root/'split'
        script.write_text('#!/usr/bin/python3\nimport os,time\nos.write(1,b"[2026-09-19T12:34:56.000001Z] INF : Binding ")\ntime.sleep(.03)\nos.write(1,b"successful\\n")\n')
        script.chmod(0o700)
        self.assertEqual(e.command([str(script)],1),(0,True))
    def test_malformed_or_false_positive_success_lines(self):
        script=self.root/'marker'
        for line in ('not Binding successful','Binding successful','ERR : Binding successful','INF : Binding successful extra',
                     'failure contained INF : Binding successful','[bad] INF : Binding successful'):
            with self.subTest(line=line):
                script.write_text('#!/usr/bin/python3\nprint('+repr(line)+')\n'); script.chmod(0o700)
                self.assertEqual(e.command([str(script)],1),(0,False))
    def test_actual_cpc_parser_reaches_missing_uart_without_key(self):
        e.render(self.options,self.options['device'])
        directory=self.root/'parser-key'; directory.mkdir(mode=0o700); key=directory/'binding.key'
        # Real binary, no mapped serial hardware. Keep raw diagnostics in memory
        # only and check the expected failing boundary, not just nonzero status.
        result=subprocess.run(['/usr/local/bin/cpcd','--conf',str(e.CONFIG),'--bind','ecdh','--key',str(key)],
                              capture_output=True,timeout=10,env={'PATH':'/usr/bin:/bin'})
        self.assertNotEqual(result.returncode,0)
        self.assertIn(b'Failed to open device',result.stdout+result.stderr)
        self.assertFalse(key.exists())
    def test_real_guard_preserves_started_current_state_without_import(self):
        self.run_main()
        before={}
        for role,relative in e.guard.FILES.items():
            path=self.data/relative; path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(('current-'+role+'-newer-than-original-backup').encode()); before[path]=path.read_bytes()
        (self.data/e.guard.COMPLETE).write_text(json.dumps({'version':1,'sources':{
            role:{'size':1,'sha256':'0'*64} for role in e.guard.FILES}}))
        (self.data/e.guard.STARTED).write_bytes(b'current state is authoritative\n')
        self.options['local_service_mode']='run'; self.save_options()
        def delegate(program,args):
            self.assertEqual(args,[sys.executable,e.GUARD])
            with patch.object(sys,'argv',[e.GUARD,'--data',str(self.data)]):
                with patch.object(e.guard.os,'execv') as init:
                    e.guard.main()
                    init.assert_called_once_with('/init',['/init'])
        self.exec.side_effect=delegate
        self.run_main()
        for path,value in before.items(): self.assertEqual(path.read_bytes(),value)
        self.assertFalse((self.data/e.guard.PENDING).exists())

    def test_success_marker_without_final_newline_is_incomplete(self):
        script=self.root/'incomplete-line'
        script.write_text('#!/usr/bin/python3\nimport os\nos.write(1,b"INF : Binding successful")\n')
        script.chmod(0o700)
        self.assertEqual(e.command([str(script)],1),(0,False))

if __name__=='__main__': unittest.main(verbosity=2)
