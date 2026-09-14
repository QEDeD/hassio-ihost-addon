import hashlib,json,struct,zlib,pathlib,re
p=pathlib.Path(__file__).parent/'donglee_mg21_multipan_beta_4.6.0_115200.gbl'
b=p.read_bytes(); tags=[]; pos=0
while pos<len(b):
 tag,n=struct.unpack_from('<II',b,pos); data=b[pos+8:pos+8+n]
 assert len(data)==n
 item={'offset':hex(pos),'tag':hex(tag),'length':n}
 if tag==0xfd0303fd:
  address=struct.unpack_from('<I',data)[0]
  item.update(address=hex(address),data_length=n-4,end_exclusive=hex(address+n-4))
 elif n<100: item['payload_hex']=data.hex()
 tags.append(item);pos+=8+n
assert pos==len(b)
result={'file':p.name,'size':len(b),'sha256':hashlib.sha256(b).hexdigest(),'crc32_entire_file':hex(zlib.crc32(b)),'gbl_crc_residue_matches':zlib.crc32(b)==0x2144df1c,'tags':tags,'relevant_ascii_strings':[x.decode('ascii') for x in re.findall(rb'[ -~]{8,}',b) if any(k in x for k in [b'CPC',b'SL-OPENTHREAD',b'SDKs/'])]}
(p.parent/'gbl-inspection.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
