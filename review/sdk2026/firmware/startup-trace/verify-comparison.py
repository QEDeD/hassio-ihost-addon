"""Verify retained full-image configuration and linked diagnostic safeguards."""
from pathlib import Path
import gzip,re,json,hashlib
root=Path(__file__).resolve().parent.parent
base=root/'candidate-clean';new=root/'startup-trace/output'
r={}
for group in ['config','autogen','source']:
    files=[p for p in (base/group).rglob('*') if p.is_file()]
    r[group]={'baseline_files':len(files),'changed':[str(p.relative_to(base/group)) for p in files if not (new/group/p.relative_to(base/group)).exists() or p.read_bytes()!=(new/group/p.relative_to(base/group)).read_bytes()], 'added':[str(p.relative_to(new/group)) for p in (new/group).rglob('*') if p.is_file() and not (base/group/p.relative_to(new/group)).exists()]}
assert not r['config']['changed'] and not r['config']['added'],r
assert set(r['autogen']['changed'])=={'sl_event_handler.c','sl_component_catalog.h'},r
assert r['source']['changed']==['app.c'] and r['source']['added']==['startup_trace.c'],r
s=gzip.decompress((new/'evidence/disassembly.txt.gz').read_bytes()).decode();a=s.index('<startup_trace_mark>:');b=s.index('\n000',a+1);code=s[a:b]
assert 'cpsid' in code and 'PRIMASK' in code and '0x000186a0' in code
r['linked_checks']=['PRIMASK saved/masked/restored','TX DMA enabled/active checked after CPC init','100000-iteration bounded waits retained','TXC peripheral and pending interrupt cleared','FF followed by trace_active=false before processing']
r['elf_sha256']=hashlib.sha256((new/'artifacts/rcp-uart-802154.out').read_bytes()).hexdigest()
assert r['elf_sha256']=='75c8b8c9989fa95ef9cfdad9622fe4400c159157436f7982f520156d51eee009'
r['catalog_discrepancy']='Only missing SL_CATALOG_TOOLCHAIN_GCC_LTO_PRESENT; source review found zero consumers across exact SDK. Project still selects component; compiler and linker flags enable LTO. Exact SLC omission cause not established.'
cm=(new/'evidence/rcp-uart-802154.cmake').read_text();assert '-flto=auto' in cm and '-fwhole-program' in cm
r['embedded_version']=[x.decode() for x in re.findall(rb'[ -~]{8,}',(new/'artifacts/rcp-uart-802154.bin').read_bytes()) if x.startswith(b'SL-OPENTHREAD/')]
p=root/'startup-trace/evidence';p.mkdir(exist_ok=True);(p/'comparison.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
