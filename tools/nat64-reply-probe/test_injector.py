import socket, subprocess
s=socket.socket(socket.AF_INET6,socket.SOCK_DGRAM)
s.bind(('::1',0)); s.settimeout(2)
payload=b'local-only-nat64-sender-check'
p=subprocess.run(['/out/inject6','::1','::1','34567',str(s.getsockname()[1])],input=payload,capture_output=True)
assert p.returncode==0,p.stderr
received,peer=s.recvfrom(1024)
assert received==payload and peer[0]=='::1' and peer[1]==34567,(received,peer)
try:
 s.recvfrom(1024)
 raise AssertionError('Unexpected second packet')
except socket.timeout: pass
for args,data in [(['::1','::1','34567','12345'],b'x'*513),(['::1','ff02::1','34567','12345'],b'x'),(['::1','::1','0','12345'],b'x')]:
 p=subprocess.run(['/out/inject6']+args,input=data,capture_output=True)
 assert p.returncode==2,(args,p.returncode)
print('PASS: real kernel accepted UDP checksum; exact payload/ports; one packet; oversized/multicast/zero-port rejected')