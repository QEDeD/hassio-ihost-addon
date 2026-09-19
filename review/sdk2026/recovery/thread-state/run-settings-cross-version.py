import pathlib, shlex, subprocess, hashlib, json
root=pathlib.Path('/thread-state-review')
base=pathlib.Path('/sdk2026-native/build')
commands=subprocess.check_output(['ninja','-C',str(base),'-t','commands'],text=True).splitlines()
command=next(x for x in commands if ' -c ' in x and x.endswith('/src/posix/platform/settings.cpp'))
args=shlex.split(command)
clean=[]; skip=False
for arg in args:
    if skip: skip=False; continue
    if arg in ['-MD','-c']: continue
    if arg in ['-MT','-MF','-o']: skip=True; continue
    if arg.endswith('/settings.cpp'): continue
    if arg.startswith('-DOPENTHREAD_CONFIG_POSIX_SETTINGS_PATH='): arg='-DOPENTHREAD_CONFIG_POSIX_SETTINGS_PATH="/thread-state-review/store"'
    if arg in ['-DNDEBUG','-Werror','-Wfatal-errors']: continue
    clean.append(arg)
(root/'old-include/posix/platform').mkdir(parents=True,exist_ok=True)
(root/'old-include/posix/platform/settings.hpp').write_bytes((root/'baseline-posix-settings.hpp').read_bytes())
(root/'fixture.cpp').write_text(r'''
#include <openthread/platform/settings.h>
#include <openthread/platform/radio.h>
#include <openthread/logging.h>
#include <cassert>
#include <cstring>
#include <cstdio>
#include <cstdlib>
void otLogCritPlat(const char *, ...) {}
void otLogWarnPlat(const char *, ...) {}
extern "C" const char *otExitCodeToString(uint8_t) { return "fixture"; }
void otPlatRadioGetIeeeEui64(otInstance *, uint8_t *v) { memset(v,0,8); }
bool IsSystemDryRun(void) { return false; }
static void value(unsigned phase,unsigned key,unsigned char *v,unsigned n) {
    for(unsigned i=0;i<n;i++) v[i]=static_cast<unsigned char>((phase*19+key*3+i)%251);
}
int main(int argc,char **argv) {
    assert(argc==3);
    unsigned phase=atoi(argv[2]);
    otPlatSettingsInit(nullptr,nullptr,0);
    const unsigned keys[]={1,2,3,4,7,8,11,12,13,0x7f00};
    const unsigned lens[]={47,52,38,9,17,8,16,8,16,15};
    for(unsigned i=0;i<10;i++) {
        unsigned char expected[64],read[64];
        value(phase,keys[i],expected,lens[i]);
        if(!strcmp(argv[1],"write")) {
            assert(otPlatSettingsSet(nullptr,keys[i],expected,lens[i])==OT_ERROR_NONE);
        } else {
            uint16_t length=sizeof(read);
            assert(otPlatSettingsGet(nullptr,keys[i],0,read,&length)==OT_ERROR_NONE);
            assert(length==lens[i] && !memcmp(read,expected,length));
        }
    }
    const unsigned char newerOnly[]={0x10,0x20,0x30,0x40};
    if(!strcmp(argv[1],"write") && phase==2)
        assert(otPlatSettingsSet(nullptr,0x7f01,newerOnly,sizeof(newerOnly))==OT_ERROR_NONE);
    if(!strcmp(argv[1],"read") && phase>=2) {
        unsigned char found[4]; uint16_t n=sizeof(found);
        assert(otPlatSettingsGet(nullptr,0x7f01,0,found,&n)==OT_ERROR_NONE);
        assert(n==sizeof(found) && !memcmp(found,newerOnly,n));
    }
    otPlatSettingsDeinit(nullptr);
    printf("PASS %s phase=%u all 10 synthetic keys\n",argv[1],phase);
}
''')
sources={
'old':[root/'baseline-settings.cpp'],
'new':[root/'candidate-settings.cpp',root/'candidate-settings_file.cpp']}
for name,src in sources.items():
    cmd=clean[:1]+(['-I'+str(root/'old-include')] if name=='old' else [])+clean[1:]+list(map(str,src))+[str(root/'fixture.cpp'),'-o',str(root/name)]
    subprocess.run(cmd,cwd=base,check=True)
(root/'store').mkdir(exist_ok=True)
for file in (root/'store').glob('*'): file.unlink()
results=[]
for name,action,phase in [('old','write',1),('new','read',1),('new','write',2),('old','read',2),('old','write',3),('new','read',3)]:
    output=subprocess.check_output([str(root/name),action,str(phase)],text=True)
    print(name+': '+output.strip())
    results.append({'backend':name,'action':action,'phase':phase,'result':output.strip()})
files=['baseline-settings.cpp','baseline-posix-settings.hpp','candidate-settings.cpp','candidate-settings_file.cpp']
(root/'results.json').write_text(json.dumps({'scope':'Synthetic POSIX settings I/O only; not daemon, radio, counter-engine or production migration','sources':{f:hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},'checks':results,'newer_only_record_survives_old_write':True},indent=2)+'\n')
