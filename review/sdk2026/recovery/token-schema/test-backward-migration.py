"""Advance and compare SYNTHETIC fixtures only; never accepts production backups."""
import json
import pathlib
import struct
import sys

def parse(blob):
    assert blob[0] == 2
    result, offset = {}, 1
    while offset < len(blob):
        token, counter, size, count = struct.unpack_from('>IBBB', blob, offset)
        offset += 7
        payload = blob[offset:offset + size * count]
        assert len(payload) == size * count
        assert token not in result
        result[token] = (counter, size, count, payload)
        offset += len(payload)
    assert offset == len(blob)
    return result

if sys.argv[1] == 'advance':
    blob = bytearray(pathlib.Path(sys.argv[2]).read_bytes())
    offset = 1
    while offset < len(blob):
        token, counter, size, count = struct.unpack_from('>IBBB', blob, offset)
        offset += 7
        if counter:
            assert size == 4 and count == 1
            value = int.from_bytes(blob[offset:offset+4], 'little')
            blob[offset:offset+4] = ((value+1000) & 0xffffffff).to_bytes(4, 'little')
        if token in (0x1e12c, 0x11000, 0x10800, 0x10880):
            blob[offset:offset+size*count] = bytes([0x6b]) * (size*count)
        offset += size*count
    pathlib.Path(sys.argv[3]).write_bytes(blob)
else:
    assert sys.argv[1] == 'check'
    latest = parse(pathlib.Path(sys.argv[2]).read_bytes())
    backward = parse(pathlib.Path(sys.argv[3]).read_bytes())
    new_or_expanded = {0x1e12c,0x11000,0x10800,0x10880}
    original = {k: v for k, v in latest.items() if k not in new_or_expanded}
    changed = [{'id':f'0x{k:08x}', 'candidate_count':v[2],
                'baseline_count':backward[k][2] if k in backward else None,
                'candidate_payload_bytes':len(v[3])} for k,v in latest.items() if backward.get(k) != v]
    result = {
        'candidate_descriptors': len(latest), 'baseline_descriptors':len(backward),
        'original_nonempty_tokens_preserved_exactly':sum(backward.get(k)==v for k,v in original.items()),
        'original_nonempty_tokens':len(original),
        'latest_synthetic_counters_preserved_exactly':all(backward.get(k)==v for k,v in latest.items() if v[0]),
        'keys_and_restored_eui64_preserved_exactly':all(backward.get(k)==latest[k] for k in (0x1e475,0x1eb79,0x10600,0x1892c,0x1e12a)),
        'changed_or_dropped_candidate_records':changed,
    }
    print(json.dumps(result,indent=2))
    assert result['original_nonempty_tokens_preserved_exactly'] == len(original) == 26
    assert result['latest_synthetic_counters_preserved_exactly']
    assert result['keys_and_restored_eui64_preserved_exactly']
    assert {int(row['id'],16) for row in changed} == new_or_expanded
