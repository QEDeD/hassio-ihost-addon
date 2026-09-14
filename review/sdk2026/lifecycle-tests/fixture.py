#!/usr/bin/env python3
import hashlib,json,os,pathlib
root=pathlib.Path('/etc/s6-overlay/s6-rc.d')
# Narrow the existing overlay user bundle to CPC and its genuine config dependency.
for entry in (root/'user/contents.d').iterdir():
    if entry.name!='cpcd': entry.unlink()
# The add-on banner calls Supervisor; it does not configure CPC.
(root/'cpcd-config/dependencies.d/banner').unlink()
pathlib.Path('/data/cpc').mkdir(parents=True,exist_ok=True)
os.chmod('/data/cpc',0o700)
pathlib.Path('/data/options.json').write_text(json.dumps({'device':'/dev/synthetic-absent','baudrate':115200,'flow_control':False,'cpcd_trace':False}))
cache=pathlib.Path('/tmp/.bashio'); cache.mkdir(exist_ok=True)
(cache/'addons.self.options.config.cache').write_text(pathlib.Path('/data/options.json').read_text())
pathlib.Path('/etc/s6-overlay/scripts/enable-check.sh').write_text('#!/bin/sh\nexit 0\n')
case=os.environ['KEY_CASE']
key=pathlib.Path('/data/cpc/binding.key')
if case=='malformed':
    key.write_text('SYNTHETIC-NONHEX-KEY-DO-NOT-LOG')
    key.chmod(0o600)
pathlib.Path('/lifecycle-before.json').write_text(json.dumps({'case':case,'exists':key.exists(),'sha256':hashlib.sha256(key.read_bytes()).hexdigest() if key.exists() else None}))
os.execv('/init',['/init'])

