const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const crypto = require('node:crypto');
const path = require('node:path');
const source = name => fs.readFileSync(path.join(__dirname, name), 'utf8');
const manifest = JSON.parse(source('manifest.json'));
const id = crypto.createHash('sha256').update(Buffer.from(manifest.key, 'base64')).digest('hex').slice(0, 32).replace(/[0-9a-f]/g, digit => String.fromCharCode(97 + parseInt(digit, 16)));

test('minimal permissions and stable extension identity', () => {
  assert.equal(id, 'neailjbinkkijmckjofkijnifeopfaaa');
  assert.deepEqual(manifest.permissions, ['nativeMessaging']);
  for (const script of manifest.content_scripts) assert.deepEqual(script.matches, ['https://web.whatsapp.com/*']);
});

function background() {
  let handler;
  const calls = [];
  const chrome = { runtime: { id, getURL: name => `chrome-extension://${id}/${name}`, onMessage: { addListener: fn => handler = fn }, sendNativeMessage: async (host, data) => { calls.push({ host, data }); return { ok: true }; } } };
  vm.runInNewContext(source('background.js'), { chrome, URL, Map, Date });
  return { calls, send: (data, sender) => new Promise(resolve => handler(data, sender, resolve)) };
}
const sender = url => ({ id, url, frameId: 0, tab: { id: 1 } });
test('only top-level WhatsApp sender and own popup can send bounded data', async () => {
  const worker = background();
  const notice = { kind: 'message', title: 'Test', body: 'Hello' };
  for (const invalid of [sender('https://example.com'), sender('https://web.whatsapp.com.evil.test'), { ...sender('https://web.whatsapp.com/'), frameId: 1 }, { ...sender('https://web.whatsapp.com/'), id: 'other' }]) {
    assert.equal((await worker.send(notice, invalid)).ok, false);
  }
  assert.equal((await worker.send({ ...notice, body: 'x'.repeat(1001) }, sender('https://web.whatsapp.com/'))).ok, false);
  assert.equal(worker.calls.length, 0);
  assert.equal((await worker.send({ ...notice, command: 'ignored' }, sender('https://web.whatsapp.com/'))).ok, true);
  assert.deepEqual(JSON.parse(JSON.stringify(worker.calls[0].data)), notice);
  assert.equal((await worker.send(notice, sender('https://web.whatsapp.com/'))).ok, false);
  assert.equal((await worker.send({ ...notice, kind: 'call' }, sender('https://web.whatsapp.com/'))).ok, true);
});

test('notification hooks preserve constructor, permission and rejected notifications', async () => {
  const relayed = [];
  class Notification {
    static permission = 'granted';
    constructor(title) { if (title === 'fail') throw new Error('denied'); this.title = title; }
  }
  class ServiceWorkerRegistration {
    showNotification(title) { return title === 'fail' ? Promise.reject(new Error('denied')) : Promise.resolve(); }
  }
  const window = { Notification, ServiceWorkerRegistration, postMessage: data => relayed.push(data) };
  vm.runInNewContext(source('page.js'), { window, Proxy, Reflect, String });
  assert.equal(window.Notification.permission, 'granted');
  assert.equal(new window.Notification('hello', { body: 'test' }).title, 'hello');
  assert.throws(() => new window.Notification('fail'));
  await new ServiceWorkerRegistration().showNotification('service', { body: 'test' });
  await new ServiceWorkerRegistration().showNotification('fail').catch(() => {});
  assert.equal(relayed.length, 2);
  assert.equal(relayed[1].title, 'service');
});

function content() {
  const messages = [];
  const timers = [];
  let receive, scan;
  const window = { addEventListener: (name, callback) => receive = callback };
  const document = { title: '(2) WhatsApp', dialogs: [], querySelectorAll() { return this.dialogs; } };
  vm.runInNewContext(source('content.js'), { window, document, chrome: { runtime: { sendMessage: async data => messages.push(data) } }, Date, setInterval: fn => scan = fn, setTimeout: fn => timers.push(fn) });
  return { messages, timers, window, document, scan: () => scan(), receive: event => receive(event) };
}
test('unread baseline is silent, increases emit, decreases do not', () => {
  const page = content();
  page.scan();
  assert.equal(page.messages.length, 0);
  page.document.title = '(3) WhatsApp'; page.scan(); page.timers.splice(0).forEach(fn => fn());
  assert.equal(page.messages[0].kind, 'message');
  page.document.title = '(1) WhatsApp'; page.scan();
  assert.equal(page.messages.length, 1);
});
test('notification relay requires same window/origin and distinguishes call hints', () => {
  const page = content();
  const data = { channel: 'dynamic-island-whatsapp', title: 'WhatsApp', body: 'Incoming voice call' };
  page.receive({ source: {}, origin: 'https://web.whatsapp.com', data });
  page.receive({ source: page.window, origin: 'https://evil.test', data });
  assert.equal(page.messages.length, 0);
  page.receive({ source: page.window, origin: 'https://web.whatsapp.com', data });
  assert.equal(page.messages[0].kind, 'call');
});
test('call dialog requires visible answer and reject controls and emits once', () => {
  const page = content();
  const button = text => ({ getClientRects: () => [1], getAttribute: () => text });
  page.document.dialogs = [{ getClientRects: () => [1], querySelectorAll: () => [button('Answer'), button('Decline')] }];
  page.scan(); page.scan();
  assert.equal(page.messages.length, 1);
  assert.equal(page.messages[0].kind, 'call');
  page.document.dialogs = []; page.scan();
  assert.equal(page.messages.length, 1);
});
