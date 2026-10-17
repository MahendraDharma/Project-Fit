-- O(1) admission counters so a submission never scans retained rows (D1 free tier: 5M rows read/day).
--   k='bytes'          live blob bytes (same quantity as SUM(reports.blob_bytes))
--   k='day:YYYY-MM-DD' reports accepted that UTC day (scrubbed rows still count, as before)
CREATE TABLE stats (k TEXT PRIMARY KEY, v INTEGER NOT NULL) WITHOUT ROWID;
INSERT INTO stats (k, v) SELECT 'bytes', COALESCE(SUM(blob_bytes), 0) FROM reports;
INSERT INTO stats (k, v)
  SELECT 'day:' || substr(created_at, 1, 10), COUNT(*) FROM reports
  WHERE created_at >= strftime('%Y-%m-%dT00:00:00.000Z', 'now', '-1 day')
  GROUP BY substr(created_at, 1, 10);
