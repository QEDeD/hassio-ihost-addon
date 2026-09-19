import csv, pathlib
root = pathlib.Path('/token-schema')
blob = bytearray([2])
for row in csv.DictReader((root/'baseline-backup-20260914.csv').open()):
    token = int(row['id'],16)
    counter, size, count = (int(row[key]) for key in ('counter','size','count'))
    blob += token.to_bytes(4,'big') + bytes([counter,size,count])
    blob += bytes((token+index)%251+1 for index in range(size*count))
(root/'synthetic-baseline.nvm').write_bytes(blob)
print('Synthetic baseline created from metadata only:',len(blob),'bytes')
