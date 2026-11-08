import { TaskRepository } from './database.js';
import { visibleTasks, stats, overdue, sameDay, terminal } from './domain.js';
import { openStore, loadSnapshot, saveSnapshot, RevisionConflict } from './storage.js';

const paths = {
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.4 1.4m11.2 11.2L19 19M5 19l1.4-1.4M17.6 6.4L19 5"/>',
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  inbox: '<path d="M4 4h16l2 11v5H2v-5L4 4Zm-2 11h6l2 3h4l2-3h6"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 11h18m-13 4h2m4 0h2"/>',
  'check-circle': '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 6-6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/>',
  leaf: '<path d="M20 3C10 1 2 7 5 15c3 7 14 3 15-12ZM4 21 15 9m-7 8-1-5m5 1h4"/>',
  settings: '<path d="m10 3-1 3-3 1-2 3 2 3-1 3 3 2 3-1 3 2 3-2v-3l2-3-2-3-3-1-1-4h-3Z"/><circle cx="12" cy="12" r="3"/>',
  shield: '<path d="m12 2 8 3v6c0 5-5 8-8 10-3-2-8-5-8-10V5l8-3Z"/><path d="m8.5 11.5 2.5 2.5 5-5"/>',
  trash: '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7"/>',
  moon: '<path d="M21 13A9 9 0 0 1 11 3a9 9 0 1 0 10 10Z"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  flag: '<path d="M5 21V3l7 2 7-2v10l-7 2-7-2"/>',
  'arrow-right': '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  sort: '<path d="M8 4v16m-4-4 4 4 4-4M15 5h6m-6 5h4m-4 5h2"/>',
  sparkles: '<path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3Zm8-2v4m-2-2h4"/>',
  lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4m-4 5v2"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  x: '<path d="m6 6 12 12M6 18 18 6"/>',
  more: '<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
  refresh: '<path d="M20 7V3m0 4h-4M4 17v4m0-4h4M19.5 7a8 8 0 0 0-14.5 1M4.5 17a8 8 0 0 0 14.5-1"/>',
};
export const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.grid}</svg>`;
const $ = selector => document.querySelector(selector);
const e = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const labelPriority = { HIGH: 'Cao', MEDIUM: 'Vừa', LOW: 'Thấp' };
const viewLabels = { today: 'Hôm nay', all: 'Tất cả công việc', inbox: 'Hộp thư', upcoming: 'Sắp tới', completed: 'Đã hoàn thành', trash: 'Thùng rác', overdue: 'Công việc quá hạn', high: 'Ưu tiên cao' };
let SQL, repo, store, revision = 0, editingId = null, editingRevision = null, toastTimer, ready = false, queue = Promise.resolve();
let taskSession = 0, categorySession = 0, navigationRevision = 0;
const state = { view: 'today', category: '', search: '', priority: '', status: '', sort: 'smart' };
const channel = typeof BroadcastChannel !== 'undefined' ? new BroadcastChannel('daymind-changes') : null;
function hydrateIcons(root = document) { root.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); el.removeAttribute('data-icon'); }); }
function toast(message, error = false) {
  clearTimeout(toastTimer); const el = $('#toast'); el.textContent = message; el.classList.toggle('error', error); el.hidden = false;
  toastTimer = setTimeout(() => { el.hidden = true; }, error ? 8000 : 4000);
}
function timeText(value) { return new Intl.DateTimeFormat('vi-VN', { hour: '2-digit', minute: '2-digit' }).format(new Date(value)); }
function dateText(value) {
  const d = new Date(value); const now = new Date();
  if (sameDay(d, now)) return `Hôm nay, ${timeText(d)}`;
  const tomorrow = new Date(now); tomorrow.setDate(tomorrow.getDate() + 1);
  if (sameDay(d, tomorrow)) return `Ngày mai, ${timeText(d)}`;
  return `${new Intl.DateTimeFormat('vi-VN', { day: '2-digit', month: '2-digit', year: d.getFullYear() !== now.getFullYear() ? 'numeric' : undefined }).format(d)}, ${timeText(d)}`;
}
function dateInput(value) {
  if (!value) return '';
  const d = new Date(value); return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}T${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}
function updateDate() {
  const now = new Date();
  $('#day-label').textContent = new Intl.DateTimeFormat('vi-VN', { weekday: 'long', day: 'numeric', month: 'long' }).format(now).toLocaleUpperCase('vi');
  $('#topbar-date').textContent = new Intl.DateTimeFormat('vi-VN', { day: '2-digit', month: 'long', year: 'numeric' }).format(now);
  const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
  $('#timezone-label').textContent = timezone.replaceAll('_',' ');
  $('#form-time-note').textContent = `Múi giờ: ${timezone}. Hạn hoàn thành không tự bật thông báo trong phiên bản này.`;
}
function closeSidebar() { $('#sidebar').classList.remove('open'); $('#sidebar-backdrop').hidden = true; $('#menu-button').setAttribute('aria-expanded','false'); }
function navigate(view, category = '') {
  navigationRevision++;
  state.view = viewLabels[view] ? view : 'today'; state.category = category; state.priority = ''; state.status = ''; state.search = '';
  $('#search-input').value = ''; $('#search-wrap').hidden = true;
  closeSidebar(); if (ready) render();
  history.replaceState(null, '', `#${state.view}`);
}
async function reload() {
  const snapshot = await loadSnapshot(store);
  if (snapshot && snapshot.revision !== revision) {
    const db = new SQL.Database(snapshot.bytes); const next = new TaskRepository(db);
    repo?.db.close(); repo = next; revision = snapshot.revision;
  }
}
function mutate(action, message) {
  const operation = queue.then(async () => {
    if (!ready) throw new Error('Dữ liệu chưa sẵn sàng. Hãy thử lại sau.');
    let before, result;
    $('#save-status').textContent = 'Đang lưu…';
    try {
      await reload();
      before = repo.db.export();
      result = repo.transaction(() => action(repo));
      revision = await saveSnapshot(store, repo.db.export(), revision);
    } catch (error) {
      if (before) { repo.db.close(); repo = new TaskRepository(new SQL.Database(before)); }
      $('#save-status').textContent = 'Chưa lưu thay đổi';
      $('#save-status').closest('.local-status').classList.add('save-error');
      if (error instanceof RevisionConflict) await reload();
      render(); throw error;
    }
    $('#save-status').textContent = 'Đã lưu trên thiết bị';
    $('#save-status').closest('.local-status').classList.remove('save-error');
    // Durable storage already committed: a closed cross-tab channel must not roll it back.
    try { channel?.postMessage({ revision }); } catch { /* Refresh on visibility remains available. */ }
    render(); if (message) toast(message);
    return result;
  });
  queue = operation.catch(() => {});
  return operation;
}
function report(error) { console.error(error); toast(error.message || 'Không thể hoàn tất. Vui lòng thử lại.', true); }
function render() {
  const focused = document.activeElement;
  const focusedRow = focused?.closest('#task-list [data-task]');
  const focusedCategory = focused?.closest('#category-nav [data-category]');
  const focusedAction = focused?.dataset.action;
  const tasks = repo.list(); const categories = repo.categories(); const now = new Date(); const metrics = stats(tasks, now);
  $('#stat-today-value').textContent = metrics.today; $('#stat-done-value').textContent = metrics.completed;
  $('#stat-overdue-value').textContent = metrics.overdue; $('#stat-high-value').textContent = metrics.high;
  for (const view of ['today','all','inbox']) $('#count-'+view).textContent = visibleTasks(tasks, { view, now }).length;
  $('#progress-value').innerHTML = `${metrics.percent}<span>%</span>`;
  $('#ring-fill').style.strokeDashoffset = String(320.443 * (1 - metrics.percent / 100));
  $('#progress-ring').setAttribute('aria-label', `${metrics.percent}% hoàn thành. ${metrics.completed} việc đã xong, ${metrics.today} việc cần làm hôm nay.`);
  $('#progress-fraction').textContent = metrics.completed + metrics.today ? `${metrics.completed} đã xong · ${metrics.today} việc hôm nay` : 'Chưa có công việc hôm nay';
  $('#progress-title').textContent = metrics.percent === 100 ? 'Bạn đã làm rất tốt.' : metrics.percent > 0 ? 'Bạn đang tiến về phía trước.' : 'Một bước nhỏ là đủ.';
  $('#progress-description').textContent = metrics.percent === 100 ? 'Dành một chút thời gian cho chính mình.' : 'Ngày của bạn, nhịp độ của bạn. Bắt đầu với một điều quan trọng.';
  document.querySelectorAll('[data-view]').forEach(button => {
    const active = button.dataset.view === state.view && !state.category;
    button.classList.toggle('active', active); if (active) button.setAttribute('aria-current','page'); else button.removeAttribute('aria-current');
  });
  $('#category-nav').innerHTML = categories.map(c => `<button class="category-item ${state.category === c.id ? 'selected' : ''}" data-category="${e(c.id)}"><span class="category-dot" style="--category-color:${e(c.color)}"></span>${e(c.name)}<span class="category-count">${tasks.filter(t=>!t.deletedAt&&!terminal(t)&&t.categoryId===c.id).length}</span></button>`).join('');
  const selectedCategory = $('#form-category').value;
  $('#form-category').innerHTML = '<option value="">Hộp thư · Chưa phân loại</option>' + categories.map(c=>`<option value="${e(c.id)}">${e(c.name)}</option>`).join('');
  $('#form-category').value = selectedCategory;
  const title = state.category ? categories.find(c=>c.id===state.category)?.name || 'Danh mục' : viewLabels[state.view];
  $('#breadcrumb-title').textContent = title;
  $('#page-title').innerHTML = state.view === 'today' && !state.category ? 'Một ngày có chủ đích<span>.</span>' : `${e(title)}<span>.</span>`;
  const subtitles = { all: 'Mọi điều bạn muốn làm, trong một không gian gọn gàng.', inbox: 'Một nơi để ghi lại. Sắp xếp khi bạn sẵn sàng.', upcoming: 'Nhìn về phía trước, chuẩn bị từng bước.', completed: 'Những điều đã làm được, dù lớn hay nhỏ.', trash: 'Công việc đã xóa vẫn ở đây. Bạn có thể khôi phục bất cứ lúc nào.', overdue: 'Không cần vội. Chọn một việc để tiếp tục.', high: 'Dành sự chú ý cho những điều quan trọng nhất.' };
  $('#page-subtitle').textContent = subtitles[state.view] || 'Dành tâm trí cho điều quan trọng. DayMind giữ phần còn lại.';
  $('#task-list-heading').innerHTML = `${e(state.view==='today' ? 'Kế hoạch hôm nay' : title)} <span id="list-count"></span>`;
  $('#list-caption').textContent = state.view === 'trash' ? 'Xóa mềm giúp bạn có thể đổi ý.' : 'Một danh sách vừa đủ, một tâm trí nhẹ hơn.';
  const items = visibleTasks(tasks, { ...state, now }); $('#list-count').textContent = items.length;
  document.querySelectorAll('[data-filter]').forEach(b => b.classList.toggle('selected', b.dataset.filter === (state.priority || state.status || 'all')));
  $('#active-category').hidden = !state.category;
  if (state.category) $('#active-category').innerHTML = `${e(title)}<button id="clear-category">Bỏ lọc</button>`;
  $('#quick-add').hidden = state.view === 'trash' || state.view === 'completed';
  $('#add-task').disabled = false;
  let html = ''; let currentGroup = null;
  for (const task of items) {
    let group = state.view === 'trash' ? 'CÓ THỂ KHÔI PHỤC' : terminal(task) ? (task.status === 'COMPLETED' ? 'ĐÃ HOÀN THÀNH' : 'ĐÃ HỦY') : overdue(task, now) ? 'CẦN CHÚ Ý · QUÁ HẠN' : task.dueAt && sameDay(task.dueAt, now) ? 'HÔM NAY' : task.dueAt ? 'ĐÃ LÊN HẠN' : 'CHƯA CÓ THỜI HẠN';
    if (group !== currentGroup) { html += `<div class="task-group-label ${overdue(task,now)?'late':''}">${icon(overdue(task,now)?'clock':'calendar')}${e(group)}</div>`; currentGroup = group; }
    const category = categories.find(c=>c.id===task.categoryId);
    const date = task.dueAt ? `<span class="meta-date ${overdue(task,now)?'late':''}">${icon('calendar')}${e(dateText(task.dueAt))}</span>` : `<span class="meta-date">${icon('inbox')}Không thời hạn</span>`;
    const status = task.status === 'IN_PROGRESS' ? '<span class="status-badge">Đang làm</span>' : task.status === 'CANCELLED' ? '<span class="status-badge">Đã hủy</span>' : '';
    html += `<article class="task-row ${task.status==='COMPLETED'?'done':''}" data-task="${e(task.id)}">
      ${task.deletedAt ? icon('trash') : `<button class="task-check ${task.priority==='HIGH'?'high':''} ${task.status==='COMPLETED'?'checked':''}" data-action="toggle" aria-label="${task.status==='COMPLETED'?'Mở lại':'Hoàn thành'}: ${e(task.title)}">${task.status==='COMPLETED'?icon('check'):''}</button>`}
      <div class="task-body"><button class="task-title" data-action="${task.deletedAt?'restore':'edit'}">${e(task.title)}</button>${task.description ? `<p class="task-description">${e(task.description)}</p>` : ''}<div class="task-meta">${category?`<span class="meta-category"><span class="category-dot" style="--category-color:${e(category.color)}"></span>${e(category.name)}</span>`:''}${date}${status}${task.scheduledStartAt?`<span class="meta-date">${icon('clock')}Bắt đầu ${e(dateText(task.scheduledStartAt))}</span>`:''}</div></div>
      ${task.deletedAt ? '<button class="restore-button" data-action="restore">Khôi phục</button>' : `<span class="priority-badge ${e(task.priority)}">${icon('flag')}${labelPriority[task.priority]}</span><button class="icon-button row-menu" data-action="edit" aria-label="Sửa ${e(task.title)}">${icon('more')}</button>`}</article>`;
  }
  if (!items.length) {
    const filtered = state.search || state.priority || state.status || state.category;
    const emptyMessages = { today: ['Một ngày đang rộng mở.', 'Thêm việc bạn muốn làm hôm nay, hoặc ghi nhanh một ý tưởng vào Hộp thư.'], all: ['Mọi điều bắt đầu từ một việc nhỏ.', 'Thêm công việc đầu tiên để tạo khoảng trống cho tâm trí.'], inbox: ['Tâm trí bạn đang thật gọn.', 'Ghi lại việc chưa cần phân loại ở đây. Không bắt buộc phải có thời hạn.'], upcoming: ['Chưa có việc nào ở phía trước.', 'Những công việc có lịch bắt đầu hoặc hạn hoàn thành từ ngày mai sẽ xuất hiện ở đây.'], completed: ['Những bước tiến đang chờ bạn.', 'Hoàn thành một công việc để ghi lại nỗ lực của bạn.'], trash: ['Thùng rác đang trống.', 'Những công việc đã xóa sẽ ở đây để bạn có thể khôi phục.'], overdue: ['Mọi thứ đang đúng nhịp.', 'Bạn không có công việc quá hạn. Hãy tiếp tục theo nhịp độ của mình.'], high: ['Không có gì cần vội.', 'Công việc có ưu tiên cao sẽ xuất hiện ở đây.'] };
    const message = filtered ? ['Chưa tìm thấy công việc phù hợp.', 'Thử từ khóa khác hoặc bỏ bộ lọc để thấy nhiều hơn.'] : emptyMessages[state.view] || emptyMessages.all;
    html = `<div class="empty-state"><div class="empty-art">${icon(filtered?'search':state.view==='completed'?'check-circle':'leaf')}</div><h3>${message[0]}</h3><p>${message[1]}</p>${filtered?'<button class="text-button" id="reset-filter">Bỏ bộ lọc</button>':state.view==='trash'||state.view==='completed'||state.view==='overdue'?'':`<button class="text-button" id="empty-add">${icon('plus')}Thêm công việc đầu tiên</button>`}</div>`;
  }
  $('#task-list').innerHTML = html; updateDate();
  if (focused && !focused.isConnected) {
    if (focusedRow) {
      const row = [...document.querySelectorAll('#task-list [data-task]')].find(el => el.dataset.task === focusedRow.dataset.task);
      const action = [...(row?.querySelectorAll('[data-action]') || [])].find(el => el.dataset.action === focusedAction);
      (action || $('#task-list [data-action]') || $('#task-list-heading')).focus({ preventScroll: true });
    } else if (focusedCategory) {
      [...document.querySelectorAll('#category-nav [data-category]')].find(el => el.dataset.category === focusedCategory.dataset.category)?.focus({ preventScroll: true });
    }
  }
}
function showTask(id = null) {
  if (!ready) return toast('Không thể mở công việc khi dữ liệu chưa sẵn sàng.', true);
  const form = $('#task-form'); form.reset(); editingId = id; editingRevision = null; taskSession++;
  $('#save-task').disabled = false; $('#delete-task').disabled = false;
  $('#form-error').hidden = true; $('#form-warning').hidden = true; $('#advanced-fields').open = false;
  $('#delete-task').hidden = !id; $('#task-dialog-title').textContent = id ? 'Chi tiết công việc' : 'Công việc mới';
  if (id) {
    const task = repo.list().find(t=>t.id===id&&!t.deletedAt);
    if (!task) return toast('Công việc không còn tồn tại.',true);
    editingRevision = task.revision;
    for (const name of ['title','description','priority','status','categoryId']) form.elements[name].value = task[name] || '';
    for (const name of ['dueAt','scheduledStartAt','scheduledEndAt']) form.elements[name].value = dateInput(task[name]);
    $('#advanced-fields').open = !!(task.scheduledStartAt || task.scheduledEndAt);
  } else {
    form.elements.categoryId.value = state.category || '';
    if (state.view === 'high' || state.priority === 'HIGH') form.elements.priority.value = 'HIGH';
  }
  warnTime(); $('#task-dialog').showModal(); $('#form-title').focus();
}
function warnTime() {
  const form = $('#task-form'); const due = form.elements.dueAt.value; const end = form.elements.scheduledEndAt.value;
  const warnings = [];
  if (due && new Date(due) < new Date()) warnings.push('Hạn đã qua. Công việc sẽ hiển thị quá hạn; không có thông báo dồn.');
  if (due && end && new Date(end) > new Date(due)) warnings.push('Lịch kết thúc sau hạn hoàn thành. Bạn vẫn có thể lưu nếu đây là chủ ý của bạn.');
  $('#form-warning').textContent = warnings.join(' '); $('#form-warning').hidden = !warnings.length;
}
function installEvents() {
  $('#navigation').addEventListener('click',event=>{ const b=event.target.closest('[data-view]');if(b)navigate(b.dataset.view); });
  $('.sidebar-bottom').addEventListener('click',event=>{ const b=event.target.closest('[data-view]');if(b)navigate(b.dataset.view); });
  $('.brand').addEventListener('click',event=>{event.preventDefault();navigate('today');});
  $('#category-nav').addEventListener('click',event=>{ const b=event.target.closest('[data-category]');if(b)navigate('all',b.dataset.category); });
  $('#menu-button').onclick=()=>{const open=$('#sidebar').classList.toggle('open');$('#sidebar-backdrop').hidden=!open;$('#menu-button').setAttribute('aria-expanded',String(open));};
  $('#sidebar-backdrop').onclick=closeSidebar;
  $('#add-task').onclick=()=>showTask();
  $('#stat-today').onclick=()=>navigate('today');$('#stat-done').onclick=()=>navigate('completed');
  $('#stat-overdue').onclick=()=>navigate('overdue');$('#stat-high').onclick=()=>navigate('high');
  $('#focus-button').onclick=()=>navigate('high');$('#all-tasks-link').onclick=()=>navigate('all');
  $('#refresh-button').onclick=()=>{queue=queue.then(reload).then(()=>{if(ready)render();toast('Đã tải lại dữ liệu trên thiết bị.');}).catch(report);};
  $('#settings-button').onclick=()=>{closeSidebar();$('#settings-dialog').showModal();};
  document.querySelectorAll('.close-dialog').forEach(b=>b.addEventListener('click',()=>b.closest('dialog').close()));
  document.querySelectorAll('dialog').forEach(dialog=>dialog.addEventListener('click',event=>{if(event.target===dialog){const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();}}));
  const search = ()=>{ if(!ready)return; navigate('all');$('#search-wrap').hidden=false;$('#search-input').focus();};
  $('#search-trigger').onclick=search;
  $('#search-input').oninput=event=>{state.search=event.target.value;if(ready)render();};
  $('#clear-search').onclick=()=>{state.search='';$('#search-input').value='';$('#search-wrap').hidden=true;if(ready)render();};
  $('#sort-select').onchange=event=>{state.sort=event.target.value;if(ready)render();};
  $('.segmented').onclick=event=>{const b=event.target.closest('[data-filter]');if(!b)return;state.priority=b.dataset.filter==='HIGH'?'HIGH':'';state.status=b.dataset.filter==='IN_PROGRESS'?'IN_PROGRESS':'';if(ready)render();};
  $('#active-category').onclick=event=>{if(event.target.closest('#clear-category')){state.category='';render();}};
  $('#task-list').onclick=async event=>{
    if(event.target.closest('#empty-add'))return showTask();
    if(event.target.closest('#reset-filter'))return navigate(state.view);
    const button=event.target.closest('[data-action]');const row=event.target.closest('[data-task]');if(!button||!row)return;
    const id=row.dataset.task;
    if(button.dataset.action==='edit')return showTask(id);
    button.disabled=true;
    try{
      if(button.dataset.action==='restore')await mutate(r=>r.restore(id),'Đã khôi phục công việc.');
      if(button.dataset.action==='toggle'){
        const current=repo.list().find(t=>t.id===id);
        if(!current)throw new Error('Công việc không còn tồn tại.');
        await mutate(r=>r.save({...current,status:current.status==='COMPLETED'?'TODO':'COMPLETED',expectedRevision:current.revision},id),'Đã cập nhật công việc.');
      }
    }catch(error){report(error);button.disabled=false;}
  };
  $('#task-form').addEventListener('change',warnTime);
  $('#task-form').addEventListener('submit',async event=>{
    event.preventDefault(); const button=$('#save-task');if(button.disabled)return;const input=Object.fromEntries(new FormData(event.target));button.disabled=true;$('#form-error').hidden=true;
    const capturedId=editingId;const capturedRevision=editingRevision;const session=taskSession;const nav=navigationRevision;
    try{const id=await mutate(r=>r.save({...input,expectedRevision:capturedId?capturedRevision:undefined},capturedId),'Đã lưu công việc trên thiết bị.');
      if(session===taskSession&&$('#task-dialog').open){$('#task-dialog').close();
        const saved=repo.list().find(t=>t.id===id);if(nav===navigationRevision&&saved&&!visibleTasks([saved],state).length)navigate('all');}}
    catch(error){if(session===taskSession&&$('#task-dialog').open){$('#form-error').textContent=error.message;$('#form-error').hidden=false;}else report(error);}
    finally{if(session===taskSession)button.disabled=false;}
  });
  $('#delete-task').onclick=async()=>{if(!editingId)return;const id=editingId;const expected=editingRevision;const session=taskSession;
    $('#delete-task').disabled=true;$('#form-error').hidden=true;
    try{await mutate(r=>r.remove(id,expected),'Đã chuyển vào thùng rác. Có thể khôi phục bất cứ lúc nào.');if(session===taskSession)$('#task-dialog').close();}
    catch(error){if(session===taskSession&&$('#task-dialog').open){$('#form-error').textContent=error.message;$('#form-error').hidden=false;}else report(error);}
    finally{if(session===taskSession)$('#delete-task').disabled=false;}};
  $('#quick-add').addEventListener('submit',async event=>{
    event.preventDefault();const button=event.target.querySelector('button');if(button.disabled)return;const title=$('#quick-title').value;const categoryId=state.category;const nav=navigationRevision;button.disabled=true;
    try{await mutate(r=>r.save({title,priority:'MEDIUM',status:'TODO',categoryId}),'Đã ghi lại công việc. Không có hạn hoàn thành.');if($('#quick-title').value===title)$('#quick-title').value='';if(nav===navigationRevision&&!['all','inbox'].includes(state.view))navigate(categoryId?'all':'inbox',categoryId);}
    catch(error){report(error);}finally{button.disabled=false;}
  });
  $('#add-category').onclick=()=>{if(!ready)return;categorySession++;$('#category-form').reset();$('#category-form [type=submit]').disabled=false;$('#category-error').hidden=true;$('#category-dialog').showModal();};
  $('#category-form').onsubmit=async event=>{event.preventDefault();const b=event.target.querySelector('[type=submit]');if(b.disabled)return;const input=Object.fromEntries(new FormData(event.target));const session=categorySession;b.disabled=true;
    try{await mutate(r=>r.addCategory(input.name,input.color),'Đã thêm danh mục.');if(session===categorySession)$('#category-dialog').close();}
    catch(error){if(session===categorySession&&$('#category-dialog').open){$('#category-error').hidden=false;$('#category-error').textContent=error.message;}else report(error);}
    finally{if(session===categorySession)b.disabled=false;}};
  $('#theme-button').onclick=()=>{const dark=document.body.classList.toggle('dark');$('#theme-button').innerHTML=icon(dark?'sun':'moon');$('#theme-button').setAttribute('aria-label',dark?'Chuyển giao diện sáng':'Chuyển giao diện tối');try{localStorage.setItem('daymind-theme',dark?'dark':'light');}catch{}};
  $('#persist-button').onclick=async()=>{try{const granted=await navigator.storage?.persist?.();$('#persist-status').textContent=granted?'Trình duyệt đã cấp lưu trữ bền vững cho DayMind.':'Trình duyệt chưa cấp lưu trữ bền vững. Công việc vẫn lưu được, nhưng có thể bị dọn khi thiếu dung lượng.';}catch(error){report(error);}};
  $('#demo-button').onclick=async()=>{
    if(!ready)return toast('Dữ liệu chưa sẵn sàng.',true);const b=$('#demo-button');b.disabled=true;
    try{await mutate(r=>{
      const at=(day,hour)=>{const d=new Date();d.setDate(d.getDate()+day);d.setHours(hour,0,0,0);return d.toISOString();};
      const examples=[['Hoàn thiện kế hoạch cho tuần mới','work','HIGH',0,17,'Dành 20 phút để chọn ba mục tiêu quan trọng nhất.'],['Đọc 20 trang sách','learning','MEDIUM',0,21,'Một khoảng lặng nhỏ để học điều mới.'],['Gửi bản đề xuất dự án','work','HIGH',-1,16,'Rà soát lại nội dung trước khi gửi.'],['Đi bộ và hít thở một chút','personal','LOW',0,18,'Để tâm trí có khoảng trống.'],['Lên ý tưởng cho góc làm việc','personal','LOW',null,0,'Chưa cần thời hạn. Ghi lại để nhớ.'],['Chuẩn bị tài liệu buổi họp','work','MEDIUM',1,10,'Tổng hợp ghi chú và các câu hỏi cần trao đổi.']];
      for(const [title,categoryId,priority,day,hour,description] of examples)r.save({title,categoryId,priority,description,status:'TODO',dueAt:day===null?null:at(day,hour)});
      r.save({title:'Dành 10 phút sắp xếp bàn làm việc',categoryId:'personal',priority:'LOW',status:'COMPLETED',dueAt:at(0,9)});
    },'Đã thêm 7 công việc mẫu. Bạn có thể sửa hoặc xóa như bình thường.');$('#settings-dialog').close();navigate('today');}
    catch(error){report(error);}finally{b.disabled=false;}
  };
  document.addEventListener('keydown',event=>{
    const editing=event.target.matches('input,textarea,select,[contenteditable="true"]');
    if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'&&!document.querySelector('dialog[open]')){event.preventDefault();search();}
    if(!editing&&!event.metaKey&&!event.ctrlKey&&!event.altKey&&event.key.toLowerCase()==='n'&&!document.querySelector('dialog[open]')){event.preventDefault();showTask();}
    if(event.key==='Escape')closeSidebar();
  });
  channel?.addEventListener('message',()=>{queue=queue.then(async()=>{if(ready){await reload();render();}}).catch(report);});
  document.addEventListener('visibilitychange',()=>{if(!document.hidden&&ready){queue=queue.then(reload).then(render).catch(report);}});
  window.addEventListener('hashchange',()=>navigate(location.hash.slice(1)));
}
async function boot() {
  hydrateIcons();updateDate();installEvents();$('#add-task').disabled=true;
  try{if(localStorage.getItem('daymind-theme')==='dark'){$('#theme-button').click();}}catch{}
  try{
    SQL=await window.initSqlJs({locateFile:file=>new URL('./vendor/'+file,import.meta.url).href});
    store=await openStore();const snapshot=await loadSnapshot(store);revision=snapshot?.revision||0;
    repo=new TaskRepository(snapshot?new SQL.Database(snapshot.bytes):new SQL.Database());
    // The first schema and migrations must also survive a browser restart.
    try{revision=await saveSnapshot(store,repo.db.export(),revision);}catch(error){if(!(error instanceof RevisionConflict))throw error;await reload();}
    ready=true;$('#save-status').textContent='Đã lưu trên thiết bị';navigate(location.hash.slice(1)||'today');
    setInterval(()=>{if(ready&&!document.hidden)render();},60000);
  }catch(error){$('#save-status').textContent='Chưa thể lưu dữ liệu';$('#task-list').innerHTML=`<div class="error-state">${icon('shield')}<h3>Chưa thể mở dữ liệu trên thiết bị.</h3><p>${e(error.message)}</p><p>Hãy kiểm tra quyền lưu trữ của trình duyệt rồi tải lại trang.</p><button class="secondary-button" id="retry-load">Thử lại</button></div>`;$('#quick-add').hidden=true;$('#retry-load').onclick=()=>location.reload();report(error);}
}
boot();
