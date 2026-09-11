#!/usr/bin/env python3
"""Finite, read-only in-app observations. Discovery sends bounded mDNS queries.

No dataset/key commands, shell interpreter, host PID access or exec API.
Logs contain private addresses. Keep them out of source control.
"""
import ipaddress
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time

LIMIT = 32768


def capture(argv, seconds=5):
    try:
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   start_new_session=True)
    except OSError as error:
        return {'status': 'unavailable', 'error': type(error).__name__}
    output, status = bytearray(), 'ok'
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + seconds
    try:
        while True:
            if time.monotonic() >= deadline:
                status = 'timeout'
                break
            if not selector.select(min(0.2, deadline - time.monotonic())):
                continue
            chunk = os.read(process.stdout.fileno(), 4096)
            if not chunk:
                break
            output.extend(chunk[:LIMIT - len(output)])
            if len(output) >= LIMIT:
                status = 'output_limit'
                break
        if status == 'ok':
            try:
                process.wait(timeout=max(0.1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                status = 'timeout'
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        code = process.wait(timeout=2)
    finally:
        selector.close()
        process.stdout.close()
    text = output.decode('utf-8', errors='replace')
    if status == 'ok' and (code != 0 or re.search(r'(?m)^Error(?:\s|:)', text)):
        status = 'error'
    return {'status': status, 'exit': code, 'output': text}


def prefixes_and_routes(text):
    result, section = [], False
    for line in text.splitlines():
        if line.endswith(':'):
            section = line in ('Prefixes:', 'Routes:')
            if section:
                result.append(line)
        elif section and line.strip() != 'Done':
            result.append(line)
    return '\n'.join(result)


def discovery_records(text):
    records = []
    for line in text.splitlines():
        fields = line.split(';')
        if len(fields) < 9 or fields[0] != '=':
            continue
        try:
            address = ipaddress.ip_address(fields[7])
            port = int(fields[8])
            if not 0 < port <= 65535:
                continue
        except ValueError:
            continue
        records.append({'interface': fields[1], 'protocol': fields[2],
                        'service': fields[4], 'target': fields[6],
                        'address': str(address), 'port': port})
    return records


def sample(backbone, discover=False):
    observations = {}
    commands = {
        'thread_state': ['ot-ctl', '-I', 'wpan0', 'state'],
        'netdata': ['ot-ctl', '-I', 'wpan0', 'netdata', 'show'],
        'omr': ['ot-ctl', '-I', 'wpan0', 'br', 'omrprefix'],
        'border_routing': ['ot-ctl', '-I', 'wpan0', 'br', 'state'],
        'ipv6_addresses': ['ip', '-j', '-6', 'address', 'show'],
        'ipv6_routes': ['ip', '-j', '-6', 'route', 'show', 'table', 'all'],
        'ipv6_rules': ['ip', '-6', 'rule', 'show'],
    }
    for name, argv in commands.items():
        value = capture(argv)
        if name == 'netdata' and 'output' in value:
            value['output'] = prefixes_and_routes(value['output'])
        observations[name] = value
    sysctls = {}
    for interface in ('all', backbone):
        for setting in ('forwarding', 'accept_ra', 'accept_ra_defrtr', 'accept_ra_rtr_pref',
                        'accept_ra_rt_info_min_plen', 'accept_ra_rt_info_max_plen',
                        'accept_ra_pinfo', 'autoconf'):
            try:
                sysctls[interface + '/' + setting] = (
                    Path('/proc/sys/net/ipv6/conf') / interface / setting).read_text().strip()
            except OSError:
                sysctls[interface + '/' + setting] = 'unavailable'
    observations['sysctls_read_only'] = sysctls
    if discover:
        records = {}
        for service in ('_meshcop._udp', '_matterc._udp', '_matter._tcp'):
            value = capture(['avahi-browse', '--parsable', '--resolve', '--terminate', service], 8)
            records[service] = {'status': value['status'],
                                'records': discovery_records(value.get('output', ''))}
        observations['active_mdns_queries'] = records
    return observations


def main():
    options = json.loads(Path('/data/options.json').read_text())
    if options.get('local_observe') is not True:
        return
    backbone = options.get('local_backbone', '')
    if not isinstance(backbone, str) or not re.fullmatch(r'[a-zA-Z0-9_.-]{1,15}', backbone):
        raise ValueError('invalid backbone interface')
    time.sleep(20)
    # Fixed finite series; runtime includes bounded command durations.
    for index in range(20):
        print(json.dumps({'local_observation': index, 'utc_epoch': int(time.time()),
                          'results': sample(backbone, discover=index in (0, 19))}), flush=True)
        if index != 19:
            time.sleep(30)


if __name__ == '__main__':
    main()
