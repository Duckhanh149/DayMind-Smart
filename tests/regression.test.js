import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mountApp, waitFor } from './app-harness.js';
import { visibleTasks } from '../dist/domain.js';

test('upcoming includes a future scheduled start even with no deadline; sorts by next relevant date', () => {
  const now = new Date('2026-11-08T09:00:00Z');
  const task = (id, extra) => ({ id, title: id, description: '', priority: 'MEDIUM', status: 'TODO', createdAt: now.toISOString(), ...extra });
  const tasks = [
    task('due-later', { dueAt: '2026-11-12T10:00:00Z' }),
    task('start-first', { scheduledStartAt: '2026-11-09T10:00:00Z' }),
    task('both', { scheduledStartAt: '2026-11-10T10:00:00Z', dueAt: '2026-11-15T10:00:00Z' }),
    task('unscheduled', {}), task('completed', { scheduledStartAt: '2026-11-09T11:00:00Z', status: 'COMPLETED' }),
    task('deleted', { scheduledStartAt: '2026-11-09T11:00:00Z', deletedAt: now.toISOString() }),
  ];
  assert.deepEqual(visibleTasks(tasks, { view: 'upcoming', now }).map(t => t.id), ['start-first', 'both', 'due-later']);
  assert.equal(tasks[1].dueAt, undefined);
});

test('upcoming uses local calendar-day boundaries at midnight rather than UTC date strings', () => {
  const now = new Date(2026, 10, 8, 23, 45);
  const task = (id, scheduledStartAt) => ({ id, title: id, description: '', priority: 'MEDIUM', status: 'TODO', scheduledStartAt });
  const tasks = [task('tonight', new Date(2026, 10, 8, 23, 59).toISOString()), task('tomorrow', new Date(2026, 10, 9, 0, 15).toISOString())];
  assert.deepEqual(visibleTasks(tasks, { view: 'upcoming', now }).map(task => task.id), ['tomorrow']);
});

test('global search clears category and priority filters and updates navigation hash', async t => {
  const app = await mountApp(t, [
    { title: 'Học ngoại ngữ', categoryId: 'learning', priority: 'LOW' },
    { title: 'Việc văn phòng', categoryId: 'work', priority: 'HIGH' },
  ]);
  app.click('[data-category=work]'); app.click('[data-filter=HIGH]'); app.click('#search-trigger');
  app.$('#search-input').value = 'ngoại ngữ';
  app.$('#search-input').dispatchEvent(new app.window.Event('input'));
  assert.match(app.$('#task-list').textContent, /Học ngoại ngữ/);
  assert.equal(app.$('#active-category').hidden, true);
  assert.equal(app.window.location.hash, '#all');
  assert.equal(app.$('[data-filter=all]').classList.contains('selected'), true);
});

test('failed persistence preserves draft and old durable data and does not claim it saved', async t => {
  const app = await mountApp(t, [{ title: 'Bản gốc' }]);
  app.click('[data-view=all]'); app.click('.task-title');
  app.$('#form-title').value = 'Bản chưa lưu'; app.failWrites(true); app.submit('#task-form');
  await waitFor(() => !app.$('#form-error').hidden);
  assert.match(app.$('#save-status').textContent, /Chưa lưu/);
  assert.equal(app.$('#form-title').value, 'Bản chưa lưu');
  assert.match(app.$('#task-list').textContent, /Bản gốc/);
  app.failWrites(false);
  let repo = await app.readRepo(); assert.equal(repo.list()[0].title, 'Bản gốc'); repo.db.close();
  app.submit('#task-form'); await waitFor(() => !app.$('#task-dialog').open);
  assert.equal(app.$('#save-status').textContent, 'Đã lưu trên thiết bị');
  repo = await app.readRepo(); assert.equal(repo.list()[0].title, 'Bản chưa lưu'); repo.db.close();
});

test('periodic refresh keeps keyboard focus on the task action', async t => {
  const app = await mountApp(t, [{ title: 'Đi bộ' }]); app.click('[data-view=all]');
  const rowId = app.$('.task-row').dataset.task;
  app.$('.task-title').focus(); app.tick();
  assert.equal(app.window.document.activeElement.closest('[data-task]')?.dataset.task, rowId);
  assert.equal(app.window.document.activeElement.dataset.action, 'edit');
});

test('saving an old form cannot close or clear a newly opened task draft', async t => {
  const app = await mountApp(t); app.click('#add-task'); app.$('#form-title').value = 'Việc thứ nhất';
  app.pauseNextRead(); app.submit('#task-form'); await waitFor(app.readPaused);
  app.click('#task-dialog .close-dialog'); app.click('#add-task'); app.$('#form-title').value = 'Bản nháp thứ hai';
  app.resumeRead(); await waitFor(async () => {
    const repo = await app.readRepo(); const saved = repo.list().some(task => task.title === 'Việc thứ nhất'); repo.db.close(); return saved;
  });
  assert.equal(app.$('#task-dialog').open, true); assert.equal(app.$('#form-title').value, 'Bản nháp thứ hai');
  assert.equal(app.$('#save-task').disabled, false);
});

test('an obsolete edit cannot delete text updated by another tab without reviewing it', async t => {
  const app = await mountApp(t, [{ title: 'Bản cũ' }]); app.click('[data-view=all]'); app.click('.task-title');
  const repo = await app.readRepo(); const old = repo.list()[0];
  repo.save({ ...old, title: 'Văn bản mới từ tab khác' }, old.id);
  const { openStore, loadSnapshot, saveSnapshot } = await import('../dist/storage.js');
  const store = await openStore(app.factory); const snapshot = await loadSnapshot(store);
  await saveSnapshot(store, repo.db.export(), snapshot.revision); store.close(); repo.db.close();
  app.click('#delete-task'); await waitFor(() => app.$('#save-status').textContent !== 'Đang lưu…');
  await waitFor(() => !app.$('#form-error').hidden);
  assert.match(app.$('#form-error').textContent, /vừa được sửa/);
  const durable = await app.readRepo(); assert.equal(durable.list()[0].deletedAt, null);
  assert.equal(durable.list()[0].title, 'Văn bản mới từ tab khác'); durable.db.close();
});

test('storage denial shows an error and keeps creation disabled', async t => {
  const app = await mountApp(t, [], { denyStorage: true });
  assert.match(app.$('#task-list').textContent, /Chưa thể mở dữ liệu/);
  assert.equal(app.$('#add-task').disabled, true);
  assert.equal(app.$('#quick-add').hidden, true);
  assert.notEqual(app.$('#save-status').textContent, 'Đã lưu trên thiết bị');
});

test('quick add preserves newly typed text while a previous save is pending', async t => {
  const app = await mountApp(t); app.$('#quick-title').value = 'Việc thứ nhất';
  app.pauseNextRead(); app.submit('#quick-add'); await waitFor(app.readPaused);
  app.$('#quick-title').value = 'Ý tưởng tiếp theo'; app.resumeRead();
  await waitFor(() => !app.$('#quick-add button').disabled);
  assert.equal(app.$('#quick-title').value, 'Ý tưởng tiếp theo');
  const repo = await app.readRepo(); assert.equal(repo.list().length, 1); assert.equal(repo.list()[0].title, 'Việc thứ nhất'); repo.db.close();
});

test('pending task save does not navigate away from a newer user-selected view', async t => {
  const app = await mountApp(t); app.$('#quick-title').value = 'Việc mới';
  app.pauseNextRead(); app.submit('#quick-add'); await waitFor(app.readPaused);
  app.click('[data-view=upcoming]'); app.resumeRead();
  await waitFor(() => !app.$('#quick-add button').disabled);
  assert.equal(app.window.location.hash, '#upcoming'); assert.equal(app.$('#breadcrumb-title').textContent, 'Sắp tới');
});

test('an old category save cannot close a newer category draft or leave its submit disabled', async t => {
  const app = await mountApp(t); app.click('#add-category'); app.$('#category-form').elements.name.value = 'Thể thao';
  app.pauseNextRead(); app.submit('#category-form'); await waitFor(app.readPaused);
  app.click('#category-dialog .close-dialog'); app.click('#add-category'); app.$('#category-form').elements.name.value = 'Âm nhạc';
  app.resumeRead(); await waitFor(() => app.$('#category-nav').textContent.includes('Thể thao'));
  assert.equal(app.$('#category-dialog').open, true); assert.equal(app.$('#category-form').elements.name.value, 'Âm nhạc');
  assert.equal(app.$('#category-form [type=submit]').disabled, false);
});

test('category keyboard focus survives a periodic refresh', async t => {
  const app = await mountApp(t); app.$('[data-category=learning]').focus(); app.tick();
  assert.equal(app.window.document.activeElement.dataset.category, 'learning');
});

test('cross-tab messaging failure cannot undo a successful durable save', async t => {
  const app = await mountApp(t); app.failBroadcast(true); app.$('#quick-title').value = 'Đã ghi bền vững'; app.submit('#quick-add');
  await waitFor(() => !app.$('#quick-add button').disabled);
  assert.equal(app.$('#save-status').textContent, 'Đã lưu trên thiết bị');
  assert.match(app.$('#task-list').textContent, /Đã ghi bền vững/);
  const repo = await app.readRepo(); assert.equal(repo.list()[0].title, 'Đã ghi bền vững'); repo.db.close();
  assert.equal(app.errors.length, 0);
});

test('storage read failure before mutation preserves the draft and reports unsaved status', async t => {
  const app = await mountApp(t, [{ title: 'Bản bền vững' }]); app.click('[data-view=all]'); app.click('.task-title');
  app.$('#form-title').value = 'Chưa thể lưu'; app.failReads(true); app.submit('#task-form');
  await waitFor(() => !app.$('#form-error').hidden); app.failReads(false);
  assert.match(app.$('#save-status').textContent, /Chưa lưu/); assert.equal(app.$('#form-title').value, 'Chưa thể lưu');
  assert.equal(app.$('#save-task').disabled, false);
  const repo = await app.readRepo(); assert.equal(repo.list()[0].title, 'Bản bền vững'); repo.db.close();
});

test('repeated submit while saving creates only one task', async t => {
  const app = await mountApp(t); app.$('#quick-title').value = 'Chỉ lưu một lần';
  app.pauseNextRead(); app.submit('#quick-add'); await waitFor(app.readPaused);
  app.submit('#quick-add'); app.resumeRead(); await waitFor(() => !app.$('#quick-add button').disabled);
  const repo = await app.readRepo(); assert.equal(repo.list().length, 1); repo.db.close();
});
