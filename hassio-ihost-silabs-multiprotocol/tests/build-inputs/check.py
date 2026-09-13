"""Isolated checks of the Dockerfile/SDK-patch acquisition commands.

Run using the adjacent Dockerfile as documented in BUILDING.md.
"""
import pathlib,subprocess,re,tempfile,os,ssl,http.server,threading,json,urllib.request
repo=pathlib.Path('/product')
def run(args,**kw):return subprocess.run(args,capture_output=True,text=True,timeout=90,**kw)
with tempfile.TemporaryDirectory() as d:
 work=pathlib.Path(d);sdk=work/'sdk/util/third_party/ot-br-posix/script';sdk.mkdir(parents=True)
 url='https://raw.githubusercontent.com/SiliconLabs/simplicity_sdk/da661283f301b53eec04d1016009e60bc7e34a1f/util/third_party/ot-br-posix/script/bootstrap'
 (sdk/'bootstrap').write_bytes(urllib.request.urlopen(url,timeout=30).read())
 patch=repo/'otbr-patches/0001-verify-mdns-source-download.patch'
 r=run(['patch','--batch','-p1','-i',str(patch)],cwd=work/'sdk');assert r.returncode==0,r.stderr
 patched=(sdk/'bootstrap').read_text()
 assert run(['bash','-n',str(sdk/'bootstrap')]).returncode==0
 begin=patched.index('        && wget --https-only');end=patched.index('        && mkdir -p $MDNS_RESPONDER_SOURCE_NAME',begin)
 block=patched[begin:end].strip()[3:].rstrip().removesuffix('\\').rstrip()
 cmd='MDNS_RESPONDER_SOURCE_NAME=mDNSResponder-1790.80.10; '+block
 r=run(['bash','-ec',cmd],cwd=work);assert r.returncode==0,r.stderr
 print('PASS exact patched HTTPS download and checksum',flush=True)
 archive=work/'mDNSResponder-1790.80.10.tar.gz';archive.write_bytes(b'invalid source')
 checksum=next(l.strip()[3:].rstrip().removesuffix('\\').rstrip() for l in patched.splitlines() if 'sha256sum -c -' in l)
 r=run(['bash','-ec','MDNS_RESPONDER_SOURCE_NAME=mDNSResponder-1790.80.10; '+checksum+' && touch EXTRACTED'],cwd=work)
 assert r.returncode!=0 and not (work/'EXTRACTED').exists();print('PASS bad source rejected before extraction')
 docker=(repo/'Dockerfile').read_text();slc=next(l.strip()[3:].rstrip().removesuffix('\\').rstrip() for l in docker.splitlines() if 'sha256sum -c -' in l)
 os.symlink('/slc.zip',work/'slc_cli_linux.zip');r=run(['bash','-ec',slc],cwd=work);assert r.returncode==0,r.stderr
 (work/'slc_cli_linux.zip').unlink();(work/'slc_cli_linux.zip').write_bytes(b'wrong generator')
 r=run(['bash','-ec',slc+' && touch GENERATED'],cwd=work);assert r.returncode!=0 and not (work/'GENERATED').exists()
 (work/'slc_cli_linux.zip').unlink();assert run(['bash','-ec',slc],cwd=work).returncode!=0
 print('PASS exact SLC check: tested archive accepted; incorrect and missing rejected')
 cert=work/'cert.pem';key=work/'key.pem'
 r=run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost']);assert r.returncode==0
 class Handler(http.server.BaseHTTPRequestHandler):
  def do_GET(self):self.send_response(200);self.end_headers();self.wfile.write(b'untrusted')
  def log_message(self,*a):pass
 class Server(http.server.ThreadingHTTPServer):
  def handle_error(self,request,client_address):
   import sys
   if not isinstance(sys.exception(),(BrokenPipeError,ConnectionResetError,ssl.SSLError)): super().handle_error(request,client_address)
 server=Server(('127.0.0.1',0),Handler);ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);ctx.load_cert_chain(cert,key);server.socket=ctx.wrap_socket(server.socket,server_side=True)
 t=threading.Thread(target=server.serve_forever,daemon=True);t.start()
 r=run(['wget','--https-only','--timeout=30','--tries=3','-O',str(work/'untrusted'),f'https://localhost:{server.server_port}/source']);server.shutdown();server.server_close()
 assert r.returncode==5,(r.returncode,r.stderr);print('PASS untrusted TLS certificate rejected')
 r=run(['wget','--https-only','--timeout=30','--tries=1','-O',str(work/'missing'),'https://codeload.github.com/apple-oss-distributions/mDNSResponder/tar.gz/0000000000000000000000000000000000000000'])
 assert r.returncode==8,(r.returncode,r.stderr);print('PASS HTTP failure rejected')
print('PASS acquisition checks; not a full image/generator/runtime test')
