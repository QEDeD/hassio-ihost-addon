"""Synthetic migration regression: input is public descriptor metadata, never real state."""
import csv
import json
import pathlib
import struct
import subprocess
import tempfile
import sys

root = pathlib.Path(__file__).resolve().parent
rows = list(csv.DictReader((root / 'baseline-backup-20260914.csv').open()))

def fixture():
    blob = bytearray([2])
    for row in rows:
        token = int(row['id'], 16)
        counter, size, count = (int(row[key]) for key in ('counter', 'size', 'count'))
        blob += struct.pack('>IBBB', token, counter, size, count)
        blob += bytes((token + index) % 251 + 1 for index in range(size * count))
    return bytes(blob)

def parse(blob):
    assert blob[0] == 2
    result, offset = {}, 1
    while offset < len(blob):
        token, counter, size, count = struct.unpack_from('>IBBB', blob, offset)
        offset += 7
        assert token not in result
        payload = blob[offset:offset + size * count]
        assert len(payload) == size * count
        result[token] = (counter, size, count, payload)
        offset += len(payload)
    assert offset == len(blob)
    return result

original = fixture()
with tempfile.TemporaryDirectory(prefix='synthetic-token-test-') as work:
    path = pathlib.Path(work) / 'host_token.nvm'
    path.write_bytes(original)
    proc = subprocess.run([str(root / 'extract-descriptors'), '--synthetic-load'],
                          cwd=work, text=True, capture_output=True)
    before, after = parse(original), parse(path.read_bytes())
    existing = [token for token, record in before.items() if record[2] > 0]
    preserved = [token for token in existing if after.get(token) == before[token]]
    result = {
        'fixture_bytes': len(original), 'baseline_descriptors': len(before),
        'baseline_nonempty_tokens': len(existing),
        'nonempty_tokens_preserved_exactly': len(preserved),
        'counter_tokens_preserved_exactly': all(after.get(token) == record for token, record in before.items() if record[0]),
        'network_key_tokens_preserved_exactly': all(after.get(token) == before[token] for token in (0x1e475,0x1eb79,0x10600,0x1892c)),
        'restored_eui64_preserved_exactly': after.get(0x1e12a) == before[0x1e12a],
        'loader_exit': proc.returncode,
        'default_checks': [line for line in proc.stderr.splitlines() if line.startswith('default_check ')],
        'all_defaults_correct': proc.returncode == 0,
    }
    print(json.dumps(result, indent=2))
    assert len(preserved) == len(existing), 'existing synthetic state changed'
    if '--expect-default-defect' in sys.argv:
        assert proc.returncode == 8, 'expected packed-default regression was not reproduced'
        assert result['default_checks'][-1].endswith('mismatches=64')
    else:
        assert proc.returncode == 0, 'new/expanded token default mismatch'
