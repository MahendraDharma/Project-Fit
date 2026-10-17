CREATE TABLE reports (
  id TEXT PRIMARY KEY,
  install_id TEXT NOT NULL,
  created_at TEXT NOT NULL,          -- ISO8601 UTC
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  meta TEXT NOT NULL,                -- plaintext meta JSON as validated
  blob_key TEXT,                     -- NULL once the blob has expired/been deleted
  blob_bytes INTEGER NOT NULL DEFAULT 0,  -- 0 once the blob is gone, so SUM() is the live total
  has_db INTEGER NOT NULL DEFAULT 0,
  delete_token_hash TEXT NOT NULL,   -- hex SHA-256; the token itself is never stored
  github_issue_url TEXT
);
-- rate limit = COUNT(*) per install per UTC day; no separate counter table
CREATE INDEX idx_reports_install_day ON reports (install_id, created_at);
CREATE INDEX idx_reports_created ON reports (created_at);
