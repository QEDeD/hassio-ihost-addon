async (page) => {
// Run with Playwright CLI run-code on the isolated fixture described in README.
// No production service or real credential is used.
let stage='initial', onRequest, onConsole;
try {
const requests = [], messages = [], results = [];
onRequest=request => requests.push(request.url());
onConsole=message => messages.push(message.text());
page.on('request',onRequest);
page.on('console',onConsole);
await page.reload();
await page.getByRole('button', {name: 'Open Join', exact:true}).click();
await page.getByRole('button', {name: 'Credential Type', exact:true}).click();
await page.getByRole('option', {name:'PSKd',exact:true}).click();
const credentials = ['ABC123','123456789ABCDEFGHJKLMNPRSTUVWXY1'];
if(credentials[1].length!==32) throw Error('Invalid maximum-length fixture');
async function decodeVisible() {
    const qr = page.getByRole('img',{name:'Connect QR code',exact:true});
    await qr.waitFor({state:'visible'});
    await qr.evaluate(image => image.decode());
    const shot = await qr.screenshot({animations:'disabled'});
    return await page.evaluate(async base64 => {
        const image = new Image(); image.src='data:image/png;base64,'+base64;
        await image.decode();
        const canvas=document.createElement('canvas');
        canvas.width=image.width;canvas.height=image.height;
        const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0);
        const pixels=ctx.getImageData(0,0,canvas.width,canvas.height);
        const decoded=jsQR(pixels.data,pixels.width,pixels.height);
        return {payload:decoded && decoded.data,width:image.width,height:image.height};
    },shot.toString('base64'));
}
let previous;
for(const width of [1000,360]) {
    for(const credential of credentials) {
        stage=`viewport ${width}, credential length ${credential.length}`;
        await page.setViewportSize({width:1000,height:800});
        await page.getByRole('textbox',{name:'PSKd *',exact:true}).fill(credential);
        await page.getByRole('button',{name:'Get Connect QR Code',exact:true}).click();
        await page.setViewportSize({width,height:800});
        const decoded=await decodeVisible();
        if(decoded.payload!=='v=1&&eui=0000aBcD0000Ef01&&cc='+credential) throw Error('Rendered payload mismatch: '+JSON.stringify({viewport:width,credentialLength:credential.length,decoded}));
        const src=await page.getByRole('img',{name:'Connect QR code',exact:true}).getAttribute('src');
        if(!src.startsWith('data:image/gif;base64,')) throw Error('Nonlocal QR image');
        if(previous && previous.credential!==credential && previous.src===src) throw Error('Stale QR image');
        previous={credential,src};
        results.push({viewport:width,credentialLength:credential.length,rendered:[decoded.width,decoded.height],decoded:true});
        await page.getByRole('button',{name:'Close',exact:true}).click();
        await page.getByRole('img',{name:'Connect QR code',exact:true}).waitFor({state:'detached'});
    }
}
async function freshJoin() {
    await page.setViewportSize({width:1000,height:800});
    await page.reload();
    await page.getByRole('button',{name:'Open Join',exact:true}).click();
    await page.getByRole('button',{name:'Credential Type',exact:true}).click();
    await page.getByRole('option',{name:'PSKd',exact:true}).click();
    await page.getByRole('textbox',{name:'PSKd *',exact:true}).fill('ABC123');
}
for(const failure of ['missing','throwing']) {
    stage='encoder failure '+failure;
    await freshJoin();
    await page.evaluate(mode=>{window.qrcode=mode==='missing'?undefined:()=>{throw Error('SYNTHETIC_CREDENTIAL_MUST_NOT_BE_LOGGED');};},failure);
    await page.getByRole('button',{name:'Get Connect QR Code',exact:true}).click();
    await page.getByText('sorry, can not generate the QR code.',{exact:true}).waitFor();
    if(await page.locator('img[alt="Connect QR code"]').count()) throw Error('Failed encoder displayed a QR image');
}
stage='hostile input';
await freshJoin();
const hostile='\"><img src=x onerror=window.qrInjection=1>{{7*7}}';
await page.evaluate(value=>{const scope=angular.element(document.querySelector('input[name=pskd]')).scope();scope.thread.pskd=value;scope.qrcode();},hostile);
const hostileDecoded=await decodeVisible();
if(hostileDecoded.payload!=='v=1&&eui=0000aBcD0000Ef01&&cc='+hostile) throw Error('Hostile input changed payload');
if(await page.evaluate(()=>window.qrInjection!==undefined || document.querySelector('img[src=x]')!==null)) throw Error('Template injection');
await page.getByRole('button',{name:'Close',exact:true}).click();
        await page.getByRole('img',{name:'Connect QR code',exact:true}).waitFor({state:'detached'});
const external=requests.filter(url=>!url.startsWith('http://127.0.0.1:18764/'));
if(external.length) throw Error('External request attempted: '+external.join(','));
if(messages.some(text=>text.includes('SYNTHETIC_CREDENTIAL_MUST_NOT_BE_LOGGED') || credentials.some(value=>text.includes(value)) || text.includes(hostile))) throw Error('Credential logged');
return {results,encoderFailures:2,hostileInputRenderedAsData:true,externalRequestAttempts:external.length,localQrRequests:requests.filter(url=>url.endsWith('/get_qrcode')).length};
} catch(error) {throw Error(stage+': '+error.message);}
finally {if(onRequest) page.off('request',onRequest);if(onConsole) page.off('console',onConsole);}

}
