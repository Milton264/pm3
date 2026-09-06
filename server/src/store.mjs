import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { id } from './domain.mjs';

export class Store {
  constructor(path) {
    if (path !== ':memory:') mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS records(kind TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL, created INTEGER NOT NULL, PRIMARY KEY(kind,id));
      CREATE TABLE IF NOT EXISTS media(id TEXT PRIMARY KEY, mime TEXT NOT NULL, bytes BLOB NOT NULL, created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS sessions(hash TEXT PRIMARY KEY, expires INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS rate_limits(key TEXT PRIMARY KEY, count INTEGER NOT NULL, resets INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS requests(key TEXT PRIMARY KEY, response TEXT, created INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
      PRAGMA user_version=1;`);
    // A generation interrupted by a server restart can be safely retried.
    this.db.exec('DELETE FROM requests WHERE response IS NULL');
  }
  all(kind) { return this.db.prepare('SELECT data FROM records WHERE kind=? ORDER BY created ASC, rowid ASC').all(kind).map(r => JSON.parse(r.data)); }
  get(kind, key) { const r = this.db.prepare('SELECT data FROM records WHERE kind=? AND id=?').get(kind, key); return r ? JSON.parse(r.data) : null; }
  put(kind, record) { this.db.prepare('INSERT INTO records VALUES(?,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET data=excluded.data').run(kind, record.id, JSON.stringify(record), record.created ?? Date.now()); return record; }
  delete(kind, key) { this.db.prepare('DELETE FROM records WHERE kind=? AND id=?').run(kind, key); }
  setting(key, fallback) { const row = this.db.prepare('SELECT value FROM settings WHERE key=?').get(key); return row ? JSON.parse(row.value) : fallback; }
  set(key, value) { this.db.prepare('INSERT OR REPLACE INTO settings VALUES(?,?)').run(key, JSON.stringify(value)); }
  addMedia(image) { const key = id(); this.db.prepare('INSERT INTO media VALUES(?,?,?,?)').run(key, image.mime, image.bytes, Date.now()); return key; }
  media(key) { return this.db.prepare('SELECT * FROM media WHERE id=?').get(key); }
  deleteMedia(key) { if (key) this.db.prepare('DELETE FROM media WHERE id=?').run(key); }
  transaction(fn) { this.db.exec('BEGIN IMMEDIATE'); try { const value = fn(); this.db.exec('COMMIT'); return value; } catch (error) { this.db.exec('ROLLBACK'); throw error; } }
  limit(key, max, window) {
    const now = Date.now();
    this.db.prepare('DELETE FROM rate_limits WHERE resets<?').run(now);
    this.db.prepare('INSERT INTO rate_limits VALUES(?,1,?) ON CONFLICT(key) DO UPDATE SET count=count+1').run(key, now + window);
    return this.db.prepare('SELECT count FROM rate_limits WHERE key=?').get(key).count <= max;
  }
  close() { this.db.close(); }
}
