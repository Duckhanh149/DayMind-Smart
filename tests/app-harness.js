import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { JSDOM } from 'jsdom';
import { IDBDatabase, IDBFactory } from 'fake-indexeddb';
import { openStore, saveSnapshot, loadSnapshot } from '../dist/storage.js';
import { TaskRepository } from '../dist/database.js';

const require = createRequire(import.meta.url);
const SQL = await require('../dist/vendor/sql-wasm.js')({
  wasmBinary: await readFile(new URL('../dist/vendor/sql-wasm.wasm', import.meta.url)),
});
const html = await readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
let sequence = 0;
export async function waitFor(predicate) {
  for (let n = 0; n < 150; n++) {
    if (await predicate()) return;
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  throw new Error('UI did not reach expected state.');
}
export async function mountApp(t, tasks = [], { denyStorage = false } = {}) {
  const factory = new IDBFactory();
  const seed = new TaskRepository(new SQL.Database());
  for (const task of tasks) seed.save({ title: 'Công việc', priority: 'MEDIUM', status: 'TODO', ...task });
  const initialStore = await openStore(factory);
  await saveSnapshot(initialStore, seed.db.export(), 0);
  initialStore.close(); seed.db.close();

  const dom = new JSDOM(html, { url: 'https://daymind.test/', pretendToBeVisual: true });
  const { window } = dom;
  const intervals = [];
  const errors = [];
  const timers = new Set();
  const originals = {
    setInterval: globalThis.setInterval, setTimeout: globalThis.setTimeout,
    transaction: IDBDatabase.prototype.transaction, consoleError: console.error,
  };
  let rejectWrites = false;
  let rejectReads = false;
  let rejectBroadcast = false;
  let pauseRead = false;
  let releaseRead = null;
  IDBDatabase.prototype.transaction = function (...args) {
    if (denyStorage || (rejectWrites && args[1] === 'readwrite') || (rejectReads && args[1] === 'readonly')) {
      throw new window.DOMException('Không đủ dung lượng lưu dữ liệu.', 'QuotaExceededError');
    }
    const tx = originals.transaction.apply(this, args);
    if (pauseRead && args[1] === 'readonly') {
      pauseRead = false;
      Object.defineProperty(tx, 'oncomplete', { set(callback) {
        tx.addEventListener('complete', event => { releaseRead = () => callback.call(tx, event); });
      } });
    }
    return tx;
  };
  Object.assign(globalThis, {
    window, document: window.document, location: window.location, history: window.history,
    localStorage: window.localStorage, FormData: window.FormData, indexedDB: factory,
    BroadcastChannel: class { postMessage() { if (rejectBroadcast) throw new Error('Channel is closed'); } addEventListener() {} },
    setInterval: callback => { intervals.push(callback); return intervals.length; },
    setTimeout: (callback, delay, ...args) => {
      const id = originals.setTimeout(callback, delay, ...args); timers.add(id); return id;
    },
  });
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: window.navigator });
  console.error = error => errors.push(error);
  window.initSqlJs = async () => SQL;
  window.HTMLDialogElement.prototype.showModal = function () { this.setAttribute('open', ''); };
  window.HTMLDialogElement.prototype.close = function () {
    this.removeAttribute('open'); this.dispatchEvent(new window.Event('close'));
  };
  t.after(() => {
    for (const timer of timers) clearTimeout(timer);
    Object.assign(globalThis, { setInterval: originals.setInterval, setTimeout: originals.setTimeout });
    IDBDatabase.prototype.transaction = originals.transaction;
    console.error = originals.consoleError;
    dom.window.close();
  });
  await import(`../dist/app.js?regression=${++sequence}`);
  const $ = selector => window.document.querySelector(selector);
  await waitFor(() => denyStorage ? !!$('#retry-load') : $('#save-status').textContent === 'Đã lưu trên thiết bị');
  const api = {
    $, window, errors, factory,
    click: selector => { assert.ok($(selector), selector); $(selector).click(); },
    submit: selector => $(selector).dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true })),
    tick: () => intervals.forEach(callback => callback()),
    failWrites: value => { rejectWrites = value; },
    failReads: value => { rejectReads = value; },
    failBroadcast: value => { rejectBroadcast = value; },
    pauseNextRead: () => { pauseRead = true; releaseRead = null; },
    readPaused: () => !!releaseRead,
    resumeRead: () => { assert.ok(releaseRead); releaseRead(); releaseRead = null; },
    readRepo: async () => {
      const store = await openStore(factory); const snapshot = await loadSnapshot(store); store.close();
      return new TaskRepository(new SQL.Database(snapshot.bytes));
    },
  };
  return api;
}
