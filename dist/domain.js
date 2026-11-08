export const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH'];
export const STATUSES = ['TODO', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];
export const terminal = task => ['COMPLETED', 'CANCELLED'].includes(task.status);
export const overdue = (task, now = new Date()) => !task.deletedAt && !terminal(task) && !!task.dueAt && new Date(task.dueAt) < now;
export const sameDay = (a, b) => new Date(a).toDateString() === new Date(b).toDateString();
const upcomingAt = (task, now) => [task.scheduledStartAt, task.dueAt]
  .filter(value => value && new Date(value) > now && !sameDay(value, now)).sort()[0] || null;
const instant = (value, label) => {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(+date)) throw new Error(`${label} không hợp lệ.`);
  return date.toISOString();
};
export function validateTask(input) {
  const title = String(input.title || '').trim();
  if (!title) throw new Error('Hãy đặt tên cho công việc.');
  if (title.length > 240) throw new Error('Tên công việc tối đa 240 ký tự.');
  if (!PRIORITIES.includes(input.priority)) throw new Error('Mức ưu tiên không hợp lệ.');
  if (!STATUSES.includes(input.status)) throw new Error('Trạng thái không hợp lệ.');
  const description = String(input.description || '').trim();
  if (description.length > 10000) throw new Error('Mô tả tối đa 10.000 ký tự.');
  const scheduledStartAt = instant(input.scheduledStartAt, 'Giờ bắt đầu');
  const scheduledEndAt = instant(input.scheduledEndAt, 'Giờ kết thúc');
  const dueAt = instant(input.dueAt, 'Hạn hoàn thành');
  if (scheduledStartAt && scheduledEndAt && scheduledStartAt > scheduledEndAt) {
    throw new Error('Giờ kết thúc phải sau hoặc bằng giờ bắt đầu.');
  }
  return { title, description, priority: input.priority, status: input.status,
    categoryId: input.categoryId || null, dueAt, scheduledStartAt, scheduledEndAt };
}
export function visibleTasks(tasks, { view = 'today', category = '', search = '', priority = '', status = '', sort = 'smart', now = new Date() } = {}) {
  const needle = search.toLocaleLowerCase('vi').normalize('NFC');
  let items = tasks.filter(task => {
    if (view === 'trash') return !!task.deletedAt;
    if (task.deletedAt) return false;
    if (view === 'all') return true;
    if (view === 'completed') return task.status === 'COMPLETED';
    if (view === 'overdue') return overdue(task, now);
    if (view === 'high') return !terminal(task) && task.priority === 'HIGH';
    if (terminal(task)) return false;
    if (view === 'today') return overdue(task, now) || (task.dueAt && sameDay(task.dueAt, now)) || (task.scheduledStartAt && sameDay(task.scheduledStartAt, now));
    if (view === 'inbox') return !task.categoryId;
    if (view === 'upcoming') return !!upcomingAt(task, now);
    return true;
  });
  items = items.filter(task => (!category || task.categoryId === category) && (!priority || task.priority === priority) && (!status || task.status === status) && `${task.title} ${task.description}`.toLocaleLowerCase('vi').normalize('NFC').includes(needle));
  const rank = { HIGH: 0, MEDIUM: 1, LOW: 2 };
  return items.sort((a, b) => {
    if (sort === 'newest') return b.createdAt.localeCompare(a.createdAt);
    if (sort === 'priority') return rank[a.priority] - rank[b.priority] || a.title.localeCompare(b.title, 'vi');
    const late = Number(overdue(b, now)) - Number(overdue(a, now));
    const date = task => view === 'upcoming' ? upcomingAt(task, now) : task.dueAt || task.scheduledStartAt;
    return late || (date(a) || '9999').localeCompare(date(b) || '9999') || rank[a.priority] - rank[b.priority];
  });
}
export function stats(tasks, now = new Date()) {
  const active = tasks.filter(t => !t.deletedAt && t.status !== 'CANCELLED');
  const plannedToday = active.filter(t => (t.dueAt && sameDay(t.dueAt, now)) || (t.scheduledStartAt && sameDay(t.scheduledStartAt, now)));
  const completedToday = active.filter(t => t.status === 'COMPLETED' && t.completedAt && sameDay(t.completedAt, now));
  const openToday = plannedToday.filter(t => !terminal(t));
  return { today: openToday.length, completed: completedToday.length,
    overdue: active.filter(t => overdue(t, now)).length,
    high: active.filter(t => !terminal(t) && t.priority === 'HIGH').length,
    percent: completedToday.length + openToday.length ? Math.round(100 * completedToday.length / (completedToday.length + openToday.length)) : 0 };
}
