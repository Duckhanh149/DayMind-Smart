import { validateTask } from './domain.js';

export const SCHEMA_VERSION = 2;
export const DEFAULT_CATEGORIES = [
  { id: 'work', name: 'Công việc', color: '#b56a4c' },
  { id: 'personal', name: 'Cá nhân', color: '#6b8b72' },
  { id: 'learning', name: 'Học tập', color: '#8a7cb2' },
];
function rows(db, sql, params = []) {
  const statement = db.prepare(sql);
  try { statement.bind(params); const result = []; while (statement.step()) result.push(statement.getAsObject()); return result; }
  finally { statement.free(); }
}
export function migrate(db) {
  let version = db.exec('PRAGMA user_version')[0].values[0][0];
  if (version > SCHEMA_VERSION) throw new Error('Dữ liệu được tạo bằng phiên bản mới hơn. Hãy cập nhật DayMind.');
  db.run('PRAGMA foreign_keys = ON');
  db.run('BEGIN TRANSACTION');
  try {
    if (version < 1) {
      db.run(`CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT NOT NULL);
        CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL CHECK(length(trim(title)) > 0), description TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL CHECK(priority IN ('LOW','MEDIUM','HIGH')),
        status TEXT NOT NULL CHECK(status IN ('TODO','IN_PROGRESS','COMPLETED','CANCELLED')),
        category_id TEXT REFERENCES categories(id), due_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        completed_at TEXT, deleted_at TEXT);
        PRAGMA user_version = 1;`);
      for (const c of DEFAULT_CATEGORIES) db.run('INSERT INTO categories VALUES (?,?,?)', [c.id, c.name, c.color]);
      version = 1;
    }
    if (version < 2) db.run(`ALTER TABLE tasks ADD COLUMN scheduled_start_at TEXT;
      ALTER TABLE tasks ADD COLUMN scheduled_end_at TEXT;
      ALTER TABLE tasks ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
      CREATE INDEX tasks_due_idx ON tasks(due_at) WHERE deleted_at IS NULL;
      PRAGMA user_version = 2;`);
    db.run('COMMIT');
  } catch (error) { db.run('ROLLBACK'); throw error; }
}
const model = row => ({ id: row.id, title: row.title, description: row.description, priority: row.priority, status: row.status,
  categoryId: row.category_id, dueAt: row.due_at, createdAt: row.created_at, updatedAt: row.updated_at,
  completedAt: row.completed_at, deletedAt: row.deleted_at, scheduledStartAt: row.scheduled_start_at,
  scheduledEndAt: row.scheduled_end_at, revision: row.revision });

export class TaskRepository {
  constructor(db, { clock = () => new Date(), id = () => crypto.randomUUID() } = {}) {
    this.db = db; this.clock = clock; this.id = id; migrate(db);
  }
  list() { return rows(this.db, 'SELECT * FROM tasks').map(model); }
  categories() { return rows(this.db, 'SELECT * FROM categories ORDER BY rowid'); }
  transaction(action) {
    this.db.run('PRAGMA foreign_keys = ON');
    this.db.run('BEGIN TRANSACTION');
    try { const result = action(); this.db.run('COMMIT'); return result; }
    catch (error) { this.db.run('ROLLBACK'); throw error; }
  }
  save(input, existingId = null) {
    const task = validateTask(input);
    const now = this.clock().toISOString();
    if (existingId) {
      const old = this.list().find(t => t.id === existingId && !t.deletedAt);
      if (!old) throw new Error('Công việc không còn tồn tại.');
      if (input.expectedRevision !== undefined && input.expectedRevision !== old.revision) throw new Error('Công việc vừa được sửa ở tab khác. Hãy đóng và mở lại chi tiết để xem phiên bản mới nhất.');
      const completedAt = task.status === 'COMPLETED' ? (old.completedAt || now) : null;
      this.db.run(`UPDATE tasks SET title=?,description=?,priority=?,status=?,category_id=?,due_at=?,scheduled_start_at=?,scheduled_end_at=?,completed_at=?,updated_at=?,revision=revision+1 WHERE id=?`,
        [task.title, task.description, task.priority, task.status, task.categoryId, task.dueAt, task.scheduledStartAt, task.scheduledEndAt, completedAt, now, existingId]);
      return existingId;
    }
    const id = this.id();
    this.db.run(`INSERT INTO tasks (id,title,description,priority,status,category_id,due_at,scheduled_start_at,scheduled_end_at,created_at,updated_at,completed_at)
      VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`, [id, task.title, task.description, task.priority, task.status, task.categoryId, task.dueAt, task.scheduledStartAt, task.scheduledEndAt, now, now, task.status === 'COMPLETED' ? now : null]);
    return id;
  }
  setStatus(id, status) {
    const old = this.list().find(t => t.id === id && !t.deletedAt);
    if (!old) throw new Error('Công việc không còn tồn tại.');
    return this.save({ ...old, status }, id);
  }
  remove(id, expectedRevision) {
    const old = this.list().find(task => task.id === id && !task.deletedAt);
    if (!old) throw new Error('Công việc không còn tồn tại.');
    if (expectedRevision !== undefined && old.revision !== expectedRevision) {
      throw new Error('Công việc vừa được sửa ở tab khác. Hãy đóng và mở lại chi tiết trước khi xóa.');
    }
    const now = this.clock().toISOString();
    this.db.run('UPDATE tasks SET deleted_at=?, updated_at=?, revision=revision+1 WHERE id=? AND deleted_at IS NULL', [now, now, id]);
  }
  restore(id) { this.db.run('UPDATE tasks SET deleted_at=NULL, updated_at=?, revision=revision+1 WHERE id=?', [this.clock().toISOString(), id]); }
  addCategory(name, color = '#6b8b72') {
    name = name.trim();
    if (!name || name.length > 40) throw new Error('Tên danh mục cần từ 1 đến 40 ký tự.');
    if (!/^#[0-9a-fA-F]{6}$/.test(color)) throw new Error('Màu danh mục không hợp lệ.');
    if (this.categories().some(c => c.name.toLocaleLowerCase('vi') === name.toLocaleLowerCase('vi'))) throw new Error('Danh mục đã tồn tại.');
    const id = this.id(); this.db.run('INSERT INTO categories VALUES (?,?,?)', [id, name, color]); return id;
  }
}
