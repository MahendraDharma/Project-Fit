#!/usr/bin/env python3
"""Usage: fetch_report.py OS-XXXXXX   -> writes OS-XXXXXX.zip in the current directory.
Env: REPORT_ADMIN_TOKEN (required), REPORT_URL (default https://reports.openstrap.site),
     REPORT_PRIVATE_KEY (default ~/.openstrap-research/report-keys/report_private_key.pem)."""
import os, re, sys, urllib.error, urllib.request
from cryptography.hazmat.primitives import serialization
from osr1 import decrypt


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, msg, headers, fp)  # never forward the admin token


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"OS-[0-9A-Z]{6}", sys.argv[1]):
        print(__doc__); return 2
    rid = sys.argv[1]
    base = os.environ.get("REPORT_URL", "https://reports.openstrap.site").rstrip("/")
    token = os.environ.get("REPORT_ADMIN_TOKEN")
    if not token:
        print("set REPORT_ADMIN_TOKEN"); return 2
    key_path = os.path.expanduser(os.environ.get("REPORT_PRIVATE_KEY", "~/.openstrap-research/report-keys/report_private_key.pem"))
    with open(key_path, "rb") as f:
        priv = serialization.load_pem_private_key(f.read(), None)
    req = urllib.request.Request(f"{base}/v1/admin/reports/{rid}/blob", headers={"Authorization": f"Bearer {token}", "User-Agent": "openstrap-report-tools/1"})
    with urllib.request.build_opener(_NoRedirect).open(req, timeout=60) as r:
        blob = r.read()
    out = f"{rid}.zip"
    with open(out, "wb") as f:
        f.write(decrypt(blob, priv))
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
