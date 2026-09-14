#!/usr/bin/env python3
import asyncio, dataclasses, importlib.metadata, json, os, pathlib, subprocess, time, traceback
import aiohttp
from python_otbr_api import OTBR, KeyFormat
from python_otbr_api.models import ActiveDataSet, PendingDataSet
ROOT=pathlib.Path('/sdk2026-api-tests')
URL='http://127.0.0.1:8081'
results={'client_version':importlib.metadata.version('python-otbr-api'),'checks':[], 'requests':[]}
def passed(name):
    results['checks'].append(name)
    print('PASS',name,flush=True)
async def main():
    trace=aiohttp.TraceConfig()
    async def on_end(session,ctx,params):
        results['requests'].append({'method':params.method,'path':params.url.path,'status':params.response.status})
    trace.on_request_end.append(on_end)
    async with aiohttp.ClientSession(trace_configs=[trace]) as session:
        for attempt in range(100):
            try:
                async with session.get(URL+'/api/actions') as r:
                    if r.status==200: break
            except aiohttp.ClientError: pass
            await asyncio.sleep(.1)
        else: raise AssertionError('SDK REST server did not start')
        passed('real SDK /api/actions accepts default Accept header: 200')
        api=OTBR(URL,session)
        initial_id=await api.get_border_agent_id()
        assert len(initial_id)==16
        assert api._key_format is KeyFormat.CAMEL_CASE
        assert len(await api.get_extended_address())==8
        assert isinstance(await api.get_coprocessor_version(),str)
        passed('client auto-detects camelCase and reads ID/address/RCP version')
        await api.set_enabled(False)
        await api.factory_reset()
        reset_id=await api.get_border_agent_id()
        assert len(reset_id)==16
        assert await api.get_active_dataset() is None
        assert await api.get_active_dataset_tlvs() is None
        assert await api.get_pending_dataset_tlvs() is None
        passed('HA disable/reset/immediate ID read and absent JSON/TLV datasets')
        await api.create_active_dataset(ActiveDataSet(channel=15,network_name='sdk-api-test',pan_id=0x1234))
        dataset=await api.get_active_dataset()
        assert dataset.network_name=='sdk-api-test' and dataset.channel==15 and dataset.pan_id==0x1234
        assert dataset.active_timestamp and dataset.security_policy
        assert dataset.psk_c and dataset.extended_pan_id and dataset.network_key
        passed('partial camelCase active dataset creation generates complete nested dataset')
        await api.set_enabled(True)
        tlvs=await api.get_active_dataset_tlvs()
        assert tlvs
        passed('HA create/enable/read-TLV sequence')
        await api.set_enabled(False)
        await api.set_active_dataset_tlvs(tlvs)
        assert await api.get_active_dataset_tlvs()==tlvs
        assert dataclasses.asdict(await api.get_active_dataset())==dataclasses.asdict(dataset)
        passed('active TLV replacement and equivalent JSON round trip while disabled')
        await api.set_enabled(True)
        pending_active=dataclasses.replace(dataset,channel=16)
        pending_active.active_timestamp=dataclasses.replace(dataset.active_timestamp,seconds=dataset.active_timestamp.seconds+1)
        await api.create_pending_dataset(PendingDataSet(active_dataset=pending_active,delay=600000))
        pending=await api.get_pending_dataset_tlvs()
        assert pending
        async with session.get(URL+'/node/dataset/pending') as response:
            assert response.status==200
            body=await response.json()
        parsed=PendingDataSet.from_json(body)
        assert parsed.active_dataset.channel==16 and parsed.delay>0
        passed('nested camelCase pending dataset write and JSON/TLV reads')
        await api.set_enabled(False)
        await api.factory_reset()
        assert len(await api.get_border_agent_id())==16
        assert await api.get_active_dataset_tlvs() is None
        assert await api.get_pending_dataset_tlvs() is None
        assert not any(r['method']=='DELETE' and '/dataset/' in r['path'] for r in results['requests'])
        passed('reset clears active/pending datasets with no legacy DELETE calls')
        results['status']='passed'
if __name__=='__main__':
    (ROOT/'state').mkdir(exist_ok=True)
    env=dict(os.environ,LD_LIBRARY_PATH=str(ROOT/'runtime-libs'))
    command=[str(ROOT/'otbr-agent'),'--vendor-name','SDK API Test','--model-name','Isolated simulation','-I','wpan0','-B','lo','-d','6','-v','-s','--data-path',str(ROOT/'state'),'--auto-attach=0','spinel+hdlc+forkpty://'+str(ROOT/'ot-rcp')+'?forkpty-arg=1']
    results['server_command']=command
    with (ROOT/'server.log').open('w') as log:
        process=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=env,cwd=ROOT)
        try: asyncio.run(main())
        except Exception:
            results['status']='failed'; results['error']=traceback.format_exc(); print(results['error'],flush=True)
        finally:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
            results['server_exit']=process.returncode
            (ROOT/'results.json').write_text(json.dumps(results,indent=2))
    raise SystemExit(0 if results.get('status')=='passed' else 1)

