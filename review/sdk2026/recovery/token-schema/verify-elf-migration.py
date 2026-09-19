"""Verify an isolated exact-ELF migration using generated synthetic files only."""
import json
import pathlib
import re
import struct
import sys

def parse(path):
    blob = pathlib.Path(path).read_bytes()
    assert blob[0] == 2
    records, offset = {}, 1
    while offset < len(blob):
        token, counter, size, count = struct.unpack_from('>IBBB', blob, offset)
        offset += 7
        payload = blob[offset:offset+size*count]
        assert len(payload) == size*count and token not in records
        records[token] = (counter,size,count,payload)
        offset += len(payload)
    assert offset == len(blob)
    return records

before, after = parse(sys.argv[1]), parse(sys.argv[2])
nonempty = {key:value for key,value in before.items() if value[2]}
checks = pathlib.Path(sys.argv[3]).read_text().splitlines()
assert len(checks) == 4
assert all(re.fullmatch(r'default_check id=0x[0-9a-f]+ count=[0-9]+ mismatches=0',line) for line in checks)
preserved = sum(after.get(key)==value for key,value in nonempty.items())
assert preserved == len(nonempty) == 26
assert {int(re.search('id=(0x[0-9a-f]+)',line).group(1),16) for line in checks} == {0x1e12c,0x11000,0x10800,0x10880}
print(json.dumps({'image':sys.argv[4], 'zigbeed_sha256':sys.argv[5],
 'baseline_descriptors':len(before),'migrated_descriptors':len(after),
 'nonempty_tokens_preserved_exactly':preserved,
 'all_counters_keys_restored_eui64_preserved_exactly':True,
 'new_and_expanded_default_checks':checks,'passed':True},indent=2))
