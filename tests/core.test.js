import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { TaskRepository, migrate, SCHEMA_VERSION } from '../dist/database.js';
import { validateTask, visibleTasks, overdue, stats } from '../dist/domain.js';
import { openStore, loadSnapshot, saveSnapshot, RevisionConflict } from '../dist/storage.js';
import { IDBFactory } from 'fake-indexeddb';
const require = createRequire(import.meta.url);
const initSQL = require('../dist/vendor/sql-wasm.js');
const SQL = await initSQL({ wasmBinary: await readFile(new URL('../dist/vendor/sql-wasm.wasm', import.meta.url)) });
const now = new Date('2026-11-08T03:00:00.000Z');
const input = (overrides = {}) => ({ title: 'Một công việc', description: '', priority: 'MEDIUM', status: 'TODO', ...overrides });
const fixture = () => new TaskRepository(new SQL.Database(), { clock: () => now });

test('validation: title is required; enums, length and dates are enforced', () => {
  for (const override of [{title:'  '},{title:'x'.repeat(241)},{priority:'urgent'},{status:'OVERDUE'},{dueAt:'invalid'},{description:'x'.repeat(10001)}]) assert.throws(()=>validateTask(input(override)));
  assert.equal(validateTask(input({title:'  Việc mới  '})).title,'Việc mới');
});
test('no deadline stays null; planning does not invent a deadline', () => {
  const task=validateTask(input({scheduledStartAt:'2026-11-09T08:00:00Z'}));
  assert.equal(task.dueAt,null);assert.equal(task.scheduledEndAt,null);
  assert.throws(()=>validateTask(input({scheduledStartAt:'2026-11-09T09:00:00Z',scheduledEndAt:'2026-11-09T08:00:00Z'})));
  assert.doesNotThrow(()=>validateTask(input({dueAt:'2026-11-09T08:00:00Z',scheduledEndAt:'2026-11-09T09:00:00Z'})));
});
test('SQLite CRUD, status transitions, revision and soft-delete/restore', () => {
  const r=fixture(); const id=r.save(input()); let t=r.list()[0];
  assert.equal(t.dueAt,null);assert.equal(t.revision,1);assert.equal(t.completedAt,null);
  r.save(input({title:'Đã sửa',priority:'HIGH',categoryId:'work'}),id);
  t=r.list()[0];assert.equal(t.title,'Đã sửa');assert.equal(t.revision,2);
  r.setStatus(id,'COMPLETED');t=r.list()[0];assert.equal(t.completedAt,now.toISOString());
  r.setStatus(id,'TODO');assert.equal(r.list()[0].completedAt,null);
  r.remove(id);assert.ok(r.list()[0].deletedAt);assert.equal(visibleTasks(r.list(),{view:'all'}).length,0);
  assert.equal(visibleTasks(r.list(),{view:'trash'}).length,1);
  r.restore(id);assert.equal(r.list()[0].deletedAt,null);r.db.close();
});
test('SQLite transaction rolls back all writes on a later validation failure', () => {
  const r=fixture();assert.throws(()=>r.transaction(()=>{r.save(input());r.save(input({title:' '}));}));
  assert.equal(r.list().length,0);r.db.close();
});
test('typed columns and foreign key prevent invalid category references, also after snapshot export', () => {
  const r=fixture();r.db.export();assert.throws(()=>r.transaction(()=>r.save(input({categoryId:'missing'}))));
  assert.equal(r.list().length,0);r.db.close();
});
test('SQLite snapshot can be reopened after restart without losing Unicode, dates or revisions', () => {
  const r=fixture();r.save(input({title:'Gặp chị Ánh 🌱',dueAt:'2026-11-09T09:30:00+07:00'}));
  const bytes=r.db.export();r.db.close();const next=new TaskRepository(new SQL.Database(bytes));
  assert.equal(next.list()[0].title,'Gặp chị Ánh 🌱');assert.equal(next.list()[0].dueAt,'2026-11-09T02:30:00.000Z');
  assert.equal(next.list()[0].revision,1);next.db.close();
});
test('schema v1→v2 preserves an existing task and can run repeatedly', () => {
  const db=new SQL.Database();db.run(`CREATE TABLE categories(id TEXT PRIMARY KEY,name TEXT,color TEXT);
    CREATE TABLE tasks(id TEXT PRIMARY KEY,title TEXT,description TEXT,priority TEXT,status TEXT,category_id TEXT,due_at TEXT,created_at TEXT,updated_at TEXT,completed_at TEXT,deleted_at TEXT);
    INSERT INTO tasks VALUES ('old','Giữ nguyên','', 'MEDIUM','TODO',null,null,'2026-11-01','2026-11-01',null,null);
    PRAGMA user_version=1;`);
  migrate(db);migrate(db);const r=new TaskRepository(db);assert.equal(r.list()[0].title,'Giữ nguyên');
  assert.equal(r.list()[0].revision,1);assert.equal(r.list()[0].scheduledStartAt,null);
  assert.equal(db.exec('PRAGMA user_version')[0].values[0][0],SCHEMA_VERSION);db.close();
});
test('future schema is rejected without silently overwriting it', () => {
  const db=new SQL.Database();db.run('PRAGMA user_version=99');assert.throws(()=>migrate(db));
  assert.equal(db.exec('PRAGMA user_version')[0].values[0][0],99);db.close();
});
test('stale edit revision is rejected, preserving newer text', () => {
  const r=fixture();const id=r.save(input());r.save(input({title:'Tab B'}),id);
  assert.throws(()=>r.save(input({title:'Tab A',expectedRevision:1}),id));
  assert.equal(r.list()[0].title,'Tab B');r.db.close();
});
test('category names are validated and duplicate/crafted colors rejected', () => {
  const r=fixture();assert.throws(()=>r.addCategory('công việc'));assert.throws(()=>r.addCategory(''));
  assert.throws(()=>r.addCategory('Test','red;display:none'));r.addCategory('Sức khỏe','#aabbcc');
  assert.equal(r.categories().length,4);r.db.close();
});
test('views/search/sort treat overdue as computed and hide tombstones', () => {
  const r=fixture();const late=r.save(input({title:'Nộp đề xuất',dueAt:'2026-11-07T13:00:00Z',priority:'HIGH'}));
  r.save(input({title:'Học tiếng Việt',categoryId:'learning',dueAt:'2026-11-10T03:00:00Z'}));r.save(input({title:'Không hạn'}));
  assert.equal(visibleTasks(r.list(),{view:'overdue',now})[0].id,late);
  assert.equal(visibleTasks(r.list(),{view:'upcoming',now}).length,1);
  assert.equal(visibleTasks(r.list(),{view:'inbox',now}).length,2);
  assert.equal(visibleTasks(r.list(),{view:'all',search:'TIẾNG',now}).length,1);
  assert.equal(visibleTasks(r.list(),{view:'all',category:'learning',now}).length,1);
  r.setStatus(late,'CANCELLED');assert.equal(overdue(r.list().find(t=>t.id===late),now),false);
  assert.equal(visibleTasks(r.list(),{view:'all',now}).length,3);r.db.close();
});
test('dashboard numbers are reproducible: completed today and remaining planned today; deleted/cancelled excluded', () => {
  const r=fixture();r.save(input({dueAt:'2026-11-08T12:00:00Z'}));r.save(input({status:'COMPLETED'}));
  r.save(input({status:'CANCELLED',dueAt:'2026-11-08T12:00:00Z'}));const id=r.save(input({dueAt:'2026-11-08T12:00:00Z'}));r.remove(id);
  const s=stats(r.list(),now);assert.equal(s.today,1);assert.equal(s.completed,1);assert.equal(s.percent,50);r.db.close();
});
test('IndexedDB persists a snapshot across database close/reopen', async () => {
  const factory=new IDBFactory();const a=await openStore(factory,'restart');const r=fixture();r.save(input());
  assert.equal(await loadSnapshot(a),null);assert.equal(await saveSnapshot(a,r.db.export(),0),1);a.close();
  const b=await openStore(factory,'restart');const snapshot=await loadSnapshot(b);assert.equal(snapshot.revision,1);
  const next=new TaskRepository(new SQL.Database(snapshot.bytes));assert.equal(next.list().length,1);next.db.close();r.db.close();b.close();
});
test('two tabs cannot silently overwrite the same IndexedDB revision', async () => {
  const factory=new IDBFactory();const a=await openStore(factory,'race');const b=await openStore(factory,'race');
  const outcomes=await Promise.allSettled([saveSnapshot(a,new Uint8Array([1]),0),saveSnapshot(b,new Uint8Array([2]),0)]);
  assert.equal(outcomes.filter(x=>x.status==='fulfilled').length,1);
  assert.ok(outcomes.find(x=>x.status==='rejected').reason instanceof RevisionConflict);
  assert.equal((await loadSnapshot(a)).revision,1);a.close();b.close();
});
