#!/usr/bin/env python3
"""Actual SDK resolver regression, run in a disposable compiler/source snapshot.
No real sockets: linker wrappers observe sends/binds and inject syscall errors.
"""
import pathlib
import resource
import shlex
import shutil
import subprocess
import sys
import tempfile

resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
fixture = pathlib.Path(__file__).resolve().parent
patch = pathlib.Path(sys.argv[1]).resolve()
sdk = pathlib.Path('/opt/silabs/sdks/simplicity_sdk_2026.6.1')
original = sdk/'openthread_stack/util/third_party/ot-br-posix/third_party/openthread/repo'
build = pathlib.Path('/sdk2026-native/build')
commands = subprocess.check_output(['ninja', '-C', str(build), '-t', 'commands'], text=True)
command = next(line for line in commands.splitlines() if ' -c ' in line and line.endswith('/src/posix/platform/resolver.cpp'))
args = shlex.split(command)
flags = []
i = 1
while i < len(args):
    if args[i] in ('-o', '-c', '-MT', '-MF'):
        i += 2
    elif args[i] in ('-MD', '-DNDEBUG', '-Werror'):
        i += 1
    else:
        flags.append(args[i]); i += 1
flags += ['-O0', '-g', '-ffunction-sections', '-fdata-sections']

with tempfile.TemporaryDirectory(prefix='sdk2026-dns-') as directory:
    root = pathlib.Path(directory)
    shutil.copytree(original/'src', root/'src')
    def compile_and_run(policy):
        selected = ['-I'+str(root/'src/posix/platform'), '-I'+str(root/'src/core'), *flags,
                    '-DOPENTHREAD_POSIX_CONFIG_UPSTREAM_DNS_BIND_TO_INFRA_NETIF='+str(policy)]
        sources = [root/'src/posix/platform/resolver.cpp', root/'src/posix/platform/mainloop.cpp', fixture/'test-resolver.cpp']
        objects = []
        for number, source in enumerate(sources):
            target = root/(str(number)+'.o'); objects.append(str(target))
            subprocess.run(['g++', *selected, '-c', str(source), '-o', str(target)], check=True)
        executable = root/'test-resolver'
        subprocess.run(['g++', *objects, '-Wl,--gc-sections',
                        '-Wl,--wrap=socket,--wrap=setsockopt,--wrap=sendto,--wrap=close,--wrap=read',
                        '-o', str(executable)], check=True)
        return subprocess.run([str(executable)], capture_output=True, text=True)

    # The previously selected SDK2026 recipe globally disabled interface binding.
    # The behavioral assertion must detect this semantic bug in original source.
    before = compile_and_run(0)
    assert before.returncode != 0 and 'sent[0].interface==' in before.stderr, before.stdout+before.stderr
    print('PASS negative control: original SDK + legacy global override fails RDNSS binding assertion', flush=True)
    subprocess.run(['patch', '--batch', '--fuzz=0', '-d', str(root), '-p1', '-i', str(patch)], check=True)
    after = compile_and_run(1)
    print(after.stdout, end='')
    if after.returncode:
        print(after.stderr, file=sys.stderr)
        raise SystemExit(after.returncode)
    print('PASS exact upstream patch, six actual-source behavior groups; no physical network exercised')
