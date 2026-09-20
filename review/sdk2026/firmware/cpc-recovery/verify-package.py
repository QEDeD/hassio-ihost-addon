import pathlib,struct,zlib,json,hashlib,sys,os,re
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else '/offline-package')
expected_elf = os.environ.get('EXPECTED_ELF_SHA256', '780ad48b11ecd28c71e5443b8de704946b040388cde7d9de5eac354877986099')
gbl_name = os.environ.get('GBL_NAME', 'cpc-recovery-sdk2026-application-only.gbl')
assert re.fullmatch('[0-9a-f]{64}', expected_elf), 'Invalid expected ELF hash'
assert pathlib.PurePosixPath(gbl_name).name == gbl_name and '/' not in gbl_name and '\\' not in gbl_name and gbl_name.endswith('.gbl'), 'Invalid GBL basename'
def srec(path):
    out={}
    for line in path.read_text().splitlines():
        if not line: continue
        b=bytes.fromhex(line[2:]); assert len(b)==b[0]+1 and sum(b)&255==255, 'SREC checksum'
        if line[1] not in '123': continue
        n={'1':2,'2':3,'3':4}[line[1]]; a=int.from_bytes(b[1:1+n],'big')
        for i,v in enumerate(b[1+n:-1]): assert a+i not in out; out[a+i]=v
    return out
def elf(path):
    b=path.read_bytes(); assert b[:6]==b'\x7fELF\x01\x01'
    phoff=struct.unpack_from('<I',b,28)[0]; size,count=struct.unpack_from('<HH',b,42)
    out={}; segments=[]
    for i in range(count):
        typ,off,va,pa,filesz,memsz,flags,align=struct.unpack_from('<8I',b,phoff+i*size)
        if typ!=1 or not filesz: continue
        segments.append({'physical_address':hex(pa),'bytes':filesz})
        for j,v in enumerate(b[off:off+filesz]): assert pa+j not in out; out[pa+j]=v
    return out,segments
source=srec(root/'input/cpc_secondary_vcom_security_device_recovery.s37'); e,segs=elf(root/'input/cpc_secondary_vcom_security_device_recovery.out')
assert e==source,'ELF/SREC differ'
parsed=srec(root/'output/parsed-application.s37')
b=(root/'output'/gbl_name).read_bytes(); tags=[]; payload={}; off=0; app=None
while off<len(b):
    tag,n=struct.unpack_from('<II',b,off); data=b[off+8:off+8+n]; assert len(data)==n
    item={'offset':off,'tag':hex(tag),'length':n}; tags.append(item)
    assert tag in (0x03a617eb,0xf40a0af4,0xfe0101fe,0xfd0303fd,0xfc0404fc),'Unexpected non-plain/application tag'
    if tag==0x03a617eb:
        assert off==0 and n==8; ver,typ=struct.unpack('<II',data); assert ver==0x03000000 and typ==0
    if tag==0xf40a0af4: app={'type':hex(struct.unpack_from('<I',data)[0]),'version':hex(struct.unpack_from('<I',data,4)[0]),'capabilities':hex(struct.unpack_from('<I',data,8)[0]),'product_id':data[12:28].hex()}
    if tag in (0xfe0101fe,0xfd0303fd):
        a=struct.unpack_from('<I',data)[0]; item['address']=hex(a); item['end_exclusive']=hex(a+n-4)
        assert 0x4000<=a<a+n-4<=0xb4000,'Payload overlaps bootloader/NVM/outside application'
        for i,v in enumerate(data[4:]): assert a+i not in payload; payload[a+i]=v
    off+=8+n
assert tags[-1]['tag']=='0xfc0404fc' and tags[-1]['length']==4
assert zlib.crc32(b)==0x2144df1c,'GBL CRC residue'
assert parsed==payload,'Vendor parser and independent GBL payload differ'
diff=[{'address':hex(a),'source':source.get(a),'gbl':payload.get(a)} for a in sorted(set(source)|set(payload)) if source.get(a)!=payload.get(a)]
assert hashlib.sha256((root/'input/cpc_secondary_vcom_security_device_recovery.out').read_bytes()).hexdigest()==expected_elf,'Unexpected ELF input'
def rd(a,n): return bytes(payload[a+i] for i in range(n))
pointer=struct.unpack('<I',rd(0x4000+13*4,4))[0]
properties=rd(pointer,80)
assert properties[:16]==bytes.fromhex('13b779fac925ddb7adf3cfe0f1b614b8')
version,sigtype,sigloc,apptype,appver,caps=struct.unpack_from('<6I',properties,16)
assert sigtype==0 and not(apptype & (1<<6))
assert app == {'type':hex(apptype),'version':hex(appver),'capabilities':hex(caps),'product_id':properties[40:56].hex()}, 'GBL/ELF application properties differ'
pages=sorted({a//0x2000*0x2000 for a in payload})
assert pages[0]>=0x4000 and pages[-1]+0x2000<=0xb4000
report={'application_properties':{'pointer':hex(pointer),'structure_version':hex(version),'signature_type':sigtype,'signature_location':hex(sigloc),'application_type':hex(apptype),'application_version':appver,'capabilities':caps,'product_id':properties[40:56].hex(),'minimum_bootloader_version':'No such field in these properties; no GBL dependency tag emitted'},'page_size':8192,'program_page_bounds':[hex(pages[0]),hex(pages[-1]+8192)],'elf_segments':segs,'source_bytes':len(source),'gbl_program_bytes':len(payload),'tags':tags,'application_tag':app,'source_differences':diff,'sha256':hashlib.sha256(b).hexdigest()}
print(json.dumps(report,indent=2))
(root/'output/independent-validation.json').write_text(json.dumps(report,indent=2)+'\n')
assert not diff,'GBL differs from compiled source; examine metadata patches'
