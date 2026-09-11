#!/usr/bin/env python3
"""One-time, two-source state import; subsequent starts preserve evolving state.

No network calls. Archives are never extracted. Output contains status only.
An interrupted import deliberately needs operator recovery before radio startup.
"""
import argparse
import fcntl
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tarfile
import tempfile
import time

FILES = {'thread': 'thread/0_b43522fffec11b30.data', 'zigbee': 'zigbeed/host_token.nvm'}
SOURCE_APPS = {'thread': 'local_codex_otbr_radio_trial_9de61ea',
               'zigbee': '81bc2df9_hassio_ihost_silabs_multiprotocol'}
MAX_ARCHIVE = 512 * 1024 * 1024
MAX_FILE = 1024 * 1024
COMPLETE = 'local-state-import.json'
PENDING = 'local-state-import.pending'
STARTED = 'local-radio-started'


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def checked(path, directory=False):
    path = Path(path)
    require(path.is_absolute() and '..' not in path.parts, 'invalid local path')
    for parent in reversed(path.parents):
        require(stat.S_ISDIR(parent.lstat().st_mode), 'unsafe parent')
    info = path.lstat()
    require(stat.S_ISDIR(info.st_mode) if directory else
            stat.S_ISREG(info.st_mode) and info.st_nlink == 1, 'unsafe file type')
    return path


def read_small(path, limit=MAX_FILE):
    path = checked(path)
    require(path.stat().st_size <= limit, 'file too large')
    with path.open('rb') as stream:
        value = stream.read(limit + 1)
    require(len(value) <= limit, 'file too large')
    return value


def load(path):
    value = json.loads(read_small(path, 16384))
    require(isinstance(value, dict), 'invalid JSON object')
    return value


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_write(path, value):
    fd, name = tempfile.mkstemp(prefix='.import-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            os.fchmod(stream.fileno(), 0o600)
            stream.write(value)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        sync_dir(path.parent)
    finally:
        if os.path.lexists(name):
            os.unlink(name)


class LimitedReader:
    """Read a fixed-size member without buffering it; cap decompressed work."""
    def __init__(self, stream, size):
        self.stream, self.left = stream, size

    def read(self, size=-1):
        require(size >= 0, 'unbounded archive read')
        size = min(size, self.left)
        value = self.stream.read(size)
        self.left -= len(value)
        return value


def exact(stream, size):
    value = stream.read(size)
    require(len(value) == size, 'truncated archive')
    return value


def drain(stream):
    while stream.read(65536):
        pass


def members(stream, budget=MAX_ARCHIVE):
    """Small strict tar reader: reject extension/link/sparse headers, duplicates.

    HA's observed archives use plain directory/regular headers. Unlike TarFile's
    extension processing, no attacker-sized PAX/long-name allocation can occur.
    """
    seen, used = set(), 0
    for _ in range(256):
        block = exact(stream, 512)
        used += 512
        require(used <= budget, 'archive work limit')
        if block == bytes(512):
            require(exact(stream, 512) == bytes(512), 'invalid archive end')
            used += 512
            while True:
                tail = stream.read(65536)
                if not tail:
                    return
                used += len(tail)
                require(used <= budget and not any(tail), 'invalid archive tail')
        info = tarfile.TarInfo.frombuf(block, 'utf-8', 'strict')
        require(info.type in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE),
                'unsupported archive member type')
        name = info.name
        if name.startswith('./'):
            name = name[2:]
        if info.isdir():
            name = name.rstrip('/')
            if name == '.':
                name = ''
        require(not name.startswith('/') and
                (name == '' or all(p not in ('', '.', '..') for p in name.split('/'))),
                'unsafe archive path')
        require(name not in seen, 'duplicate archive member')
        seen.add(name)
        require(info.size >= 0 and (not info.isdir() or info.size == 0), 'invalid member size')
        padded = (info.size + 511) // 512 * 512
        require(used + padded <= budget, 'archive work limit')
        payload = LimitedReader(stream, info.size)
        yield name, info, payload
        drain(payload)
        require(payload.left == 0, 'truncated member')
        require(not any(exact(stream, padded - info.size)), 'invalid archive padding')
        used += padded
    raise ValueError('too many archive members')


def source_file(backup, role, source):
    require(set(source) == {'backup_slug', 'app_slug', 'size', 'sha256'}, 'invalid source fields')
    require(isinstance(source['backup_slug'], str) and
            re.fullmatch('[0-9a-f]{8}', source['backup_slug']), 'invalid backup slug')
    require(source['app_slug'] == SOURCE_APPS[role], 'wrong source app')
    require(type(source['size']) is int and 0 < source['size'] <= MAX_FILE and
            isinstance(source['sha256'], str) and re.fullmatch('[0-9a-f]{64}', source['sha256']),
            'invalid source fingerprint')
    path = checked(backup / (source['backup_slug'] + '.tar'))
    require(path.stat().st_size <= MAX_ARCHIVE, 'outer archive too large')
    found = None
    with path.open('rb') as outer:
        for name, info, payload in members(outer):
            if name != source['app_slug'] + '.tar.gz':
                continue
            require(info.isfile() and 0 < info.size <= MAX_ARCHIVE, 'invalid app archive')
            with gzip.GzipFile(fileobj=payload) as packed:
                for inner_name, inner_info, inner_payload in members(packed):
                    if inner_name != 'data/' + FILES[role]:
                        continue
                    require(inner_info.isfile() and inner_info.size == source['size'],
                            'invalid selected state member')
                    found = exact(inner_payload, inner_info.size)
    require(found is not None, 'missing state member')
    require(hashlib.sha256(found).hexdigest() == source['sha256'], 'source fingerprint mismatch')
    return found


def prepare(data, backup, manifest):
    require(not any(os.path.lexists(data / name) for name in
                    (COMPLETE, PENDING, STARTED, 'thread', 'zigbeed')), 'state already exists')
    require(set(manifest) == {'version', 'expires_at', 'sources'} and type(manifest['version']) is int and manifest['version'] == 1,
            'invalid import manifest')
    expiry = manifest['expires_at']
    require(type(expiry) is int and time.time() < expiry <= time.time() + 900,
            'expired or invalid import window')
    require(isinstance(manifest['sources'], dict) and set(manifest['sources']) == set(FILES),
            'invalid source roles')
    values = {role: source_file(backup, role, manifest['sources'][role]) for role in FILES}
    atomic_write(data / PENDING, b'import incomplete\n')
    for role, relative in FILES.items():
        path = data / relative
        path.parent.mkdir(mode=0o700)
        sync_dir(data)
        atomic_write(path, values[role])
        require(read_small(path) == values[role], 'state readback mismatch')
    atomic_write(data / COMPLETE, json.dumps(manifest, sort_keys=True).encode())
    (data / PENDING).unlink()
    sync_dir(data)


def authorize_start(data):
    require(not os.path.lexists(data / PENDING), 'import incomplete')
    marker = load(data / COMPLETE)
    require(marker.get('version') == 1 and set(marker.get('sources', {})) == set(FILES),
            'missing import provenance')
    started = os.path.lexists(data / STARTED)
    if started:
        require(read_small(data / STARTED, 64) == b'current state is authoritative\n',
                'invalid radio marker')
    for role, relative in FILES.items():
        value = read_small(data / relative)
        require(bool(value), 'missing current state')
        if not started:
            source = marker['sources'][role]
            require(len(value) == source['size'] and
                    hashlib.sha256(value).hexdigest() == source['sha256'], 'seed changed before first start')
    if not started:
        atomic_write(data / STARTED, b'current state is authoritative\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', type=Path, default=Path('/data'))
    parser.add_argument('--backup', type=Path, default=Path('/backup'))
    parser.add_argument('--manifest', type=Path, default=Path('/share/otbr-local-seed.json'))
    args = parser.parse_args()
    data = checked(args.data, directory=True)
    lockfd = os.open(data / '.local-state.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(lockfd, 'wb') as lock:
        require(stat.S_ISREG(os.fstat(lock.fileno()).st_mode) and
                os.fstat(lock.fileno()).st_nlink == 1, 'unsafe lock')
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        options = load(data / 'options.json')
        mode = options.get('local_service_mode')
        if os.environ.get('LOCAL_SERVICE_RECOVERY') == '1':
            require(options.get('otbr_enable') is False, 'recovery requires OTBR disabled')
        if mode == 'prepare':
            prepare(data, checked(args.backup, directory=True), load(args.manifest))
            print('{"status":"imported; radio not started"}')
        elif mode == 'run':
            if not os.path.lexists(data / STARTED):
                require(options.get('otbr_enable') is False, 'first run requires OTBR disabled')
            authorize_start(data)
            print('{"status":"starting with current private state"}', flush=True)
            os.execv('/init', ['/init'])
        else:
            raise ValueError('select prepare or run explicitly')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        reason = str(error) if type(error) is ValueError else type(error).__name__
        print('local state refused: ' + reason, file=sys.stderr)
        sys.exit(1)
