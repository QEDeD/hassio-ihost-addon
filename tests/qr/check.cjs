'use strict';
// Usage: node tests/qr/check.cjs FRONTEND_DIR QRCODE_JS
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const frontend = path.resolve(process.argv[2]);
const encoder = require(path.resolve(process.argv[3]));
const source = fs.readFileSync(path.join(frontend, 'res/js/app.js'), 'utf8');
const start = source.indexOf('        function DialogController(');
const end = source.indexOf('        $scope.showConfirm', start);
assert(start > 0 && end > start);
const controller = source.slice(start, end);
assert(!controller.includes('qrserver'));
assert(!controller.includes('console.'));
function setup(qrcode, eui64, pskd) {
  const scope = {}, dialogs = [], alerts = [], requests = [];
  const md = { show: value => dialogs.push(value) };
  const context = { qrcode, event: undefined, document: { querySelector: () => null }, angular: { element: x => x } };
  vm.createContext(context);
  vm.runInContext(controller, context);
  context.DialogController(scope, md, {
    get: url => {
      requests.push(url);
      return { then: cb => cb({ data: { result: 'successful', eui64 } }) };
    }
  }, null, { getIndex: () => 0 });
  scope.thread.pskd = pskd;
  scope.showQRAlert = (ev, message) => alerts.push(message);
  return { scope, dialogs, alerts, requests };
}
for (const [eui, pskd] of [
  ['0000000000000000', 'ABC123'],
  ['0000aBcD0000Ef01', '123456789ABCDEFGHJKLMNPRSTUVWXY1'],
  ['{{constructor.constructor("globalThis.pwned=1")()}}', '\"><img src=x onerror=globalThis.pwned=1>'],
]) {
  const calls = [];
  const state = setup((version, level) => {
    assert.equal(version, 0); assert.equal(level, 'L');
    return { addData: (data, mode) => calls.push([data, mode]), make() {}, createDataURL: (cell, margin) => {
      assert.equal(cell, 6); assert.equal(margin, cell * 4); return 'data:image/gif;base64,R0lGODlh';
    } };
  }, eui, pskd);
  state.scope.qrcode();
  assert.deepEqual(calls, [['v=1&&eui=' + eui + '&&cc=' + pskd, 'Byte']]);
  assert.deepEqual(state.requests, ['get_qrcode']);
  assert.equal(state.alerts.length, 0);
  const dialog = state.dialogs[0];
  assert(dialog.template.includes('ng-src="{{qrImage}}"'));
  assert(!dialog.template.includes(eui));
  assert(!dialog.template.includes(pskd));
  const dialogScope = {};
  dialog.controller(dialogScope, {}, dialog.locals.qrImage);
  assert.equal(dialogScope.qrImage, dialog.locals.qrImage);
}
for (const failing of [undefined, () => { throw Error('private data'); }, () => ({ addData() { throw Error('private data'); } })]) {
  const state = setup(failing, '0000000000000000', 'ABC123');
  state.scope.qrcode();
  assert.deepEqual(state.alerts, ['sorry, can not generate the QR code.']);
  assert.equal(state.dialogs.length, 0);
  assert.deepEqual(state.requests, ['get_qrcode']);
}
const state = setup(encoder, '0000aBcD0000Ef01', 'ABC123');
state.scope.qrcode();
const first = state.dialogs[0];
assert(first.locals.qrImage.startsWith('data:image/gif;base64,'));
state.scope.thread.pskd = '123456789ABCDEFGHJKLMNPRSTUVWXY1';
state.scope.qrcode();
assert.notEqual(first.locals.qrImage, state.dialogs[1].locals.qrImage);
assert.notEqual(first.locals, state.dialogs[1].locals);
assert.equal(first.template, state.dialogs[1].template);
console.log('QR controller checks passed (payload, local raster, isolation, constant template, encoder failures).');
