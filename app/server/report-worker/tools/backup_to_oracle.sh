#!/usr/bin/env bash
# Nightly: mirror report METADATA (never blobs) from the admin API into a local SQLite file.
# The file is a snapshot of what the Worker lists right now: each run replaces it in one
# transaction, so a report the user deleted or that passed 90 days disappears here too.
# Config in /etc/openstrap-report-backup.env: REPORT_ADMIN_TOKEN=..., optional REPORT_URL, BACKUP_DB.
set -euo pipefail
export REPORT_URL="${REPORT_URL:-https://reports.openstrap.site}"
export BACKUP_DB="${BACKUP_DB:-/var/lib/openstrap-reports/meta.sqlite}"
: "${REPORT_ADMIN_TOKEN:?set REPORT_ADMIN_TOKEN}"
mkdir -p "$(dirname "$BACKUP_DB")"
python3 - <<'PY'
import json, os, sqlite3, urllib.error, urllib.parse, urllib.request
url, db, tok = os.environ["REPORT_URL"], os.environ["BACKUP_DB"], os.environ["REPORT_ADMIN_TOKEN"]
class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, msg, headers, fp)  # never forward the admin token
opener = urllib.request.build_opener(_NoRedirect)
rows, since, after = [], "1970-01-01T00:00:00Z", ""
while True:  # cursor = (created_at, id): rows sharing a timestamp are never skipped
    q = urllib.parse.urlencode({"since": since, "after_id": after})
    req = urllib.request.Request(f"{url}/v1/admin/reports?{q}", headers={"Authorization": f"Bearer {tok}", "User-Agent": "openstrap-report-tools/1"})
    page = json.load(opener.open(req, timeout=60))["reports"]
    rows += page
    if len(page) < 1000:
        break
    since, after = page[-1]["created_at"], page[-1]["id"]
c = sqlite3.connect(db)
with c:  # one transaction: replace the snapshot, then drop anything past the 90-day policy
    c.execute("""CREATE TABLE IF NOT EXISTS reports (id TEXT PRIMARY KEY, install_id, created_at, category, title,
      description, meta, blob_bytes, has_db, github_issue_url, blob_expired INTEGER)""")
    c.execute("DELETE FROM reports")
    c.executemany("""INSERT INTO reports (id,install_id,created_at,category,title,description,meta,blob_bytes,has_db,github_issue_url,blob_expired)
      VALUES (:id,:install_id,:created_at,:category,:title,:description,:meta,:blob_bytes,:has_db,:github_issue_url,:blob_expired)""",
      [{**r, "blob_expired": int(r.get("blob_key") is None)} for r in rows])
    c.execute("DELETE FROM reports WHERE created_at < strftime('%Y-%m-%dT%H:%M:%fZ','now','-90 days')")
print(f"backed up {len(rows)} reports")
PY
