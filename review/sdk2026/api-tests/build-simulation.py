#!/usr/bin/env python3
import pathlib, subprocess
root=pathlib.Path('/sdk2026-api-tests')
root.mkdir(exist_ok=True)
src='/sdk2026-native/ot-br-posix'
args=[]
for line in pathlib.Path('/sdk2026-native/build/CMakeCache.txt').read_text().splitlines():
    if '=' not in line or ':' not in line or line.startswith(('//','#')): continue
    keytype,val=line.split('=',1); key,typ=keytype.split(':',1)
    if typ not in ('BOOL','STRING','PATH') or not key.startswith(('OTBR_','OT_','CMAKE_CXX_FLAGS')): continue
    args.append(f'-D{key}:{typ}={val}')
args += ['-DBUILD_TESTING=OFF','-DOT_POSIX_RCP_HDLC_BUS=ON','-DOT_POSIX_RCP_VENDOR_BUS=OFF','-DOT_MULTIPAN_RCP=OFF','-DCMAKE_BUILD_TYPE=Release']
commands=[['cmake','-S',src,'-B',str(root/'agent-build'),'-G','Ninja',*args],['cmake','--build',str(root/'agent-build'),'--target','otbr-agent','-j2'],['cmake','-S',src+'/third_party/openthread/repo','-B',str(root/'rcp-build'),'-G','Ninja','-DOT_PLATFORM=simulation','-DOT_APP_RCP=ON','-DOT_APP_CLI=OFF','-DOT_APP_NCP=OFF','-DOT_THREAD_VERSION=1.4','-DCMAKE_BUILD_TYPE=Release'],['cmake','--build',str(root/'rcp-build'),'--target','ot-rcp','-j2']]
with (root/'build.log').open('w') as log:
    for command in commands:
        print('RUN',command[:5],flush=True)
        log.write('RUN '+repr(command)+'\n'); log.flush()
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)

