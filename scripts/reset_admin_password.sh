#!/usr/bin/env bash
# reset_admin_password.sh — Reset the admin account to factory default credentials.
#
# Resets admin password to "changeme" and invalidates all active admin sessions.
# Works for standalone installs (/opt/codan-hf), Docker containers, and dev environments.
#
# Usage:
#   sudo /opt/codan-hf/bin/reset_admin_password.sh          # standalone install
#   docker exec <container> reset_admin_password.sh          # Docker
#   ./scripts/reset_admin_password.sh                        # dev (from repo root)
#   CODAN_AUTH_DB=/path/to/auth.db ./scripts/reset_admin_password.sh

set -euo pipefail

DEFAULT_PASS="changeme"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Locate auth.db
# ---------------------------------------------------------------------------
if [[ -n "${CODAN_AUTH_DB:-}" ]]; then
    DB_PATH="$CODAN_AUTH_DB"
elif [[ -f "/opt/codan-hf/backend/auth.db" ]]; then
    DB_PATH="/opt/codan-hf/backend/auth.db"
elif [[ -f "/app/web_backend/auth.db" ]]; then
    # Docker container default path
    DB_PATH="/app/web_backend/auth.db"
elif [[ -f "$SCRIPT_DIR/../web_backend/auth.db" ]]; then
    # Dev: script lives in scripts/, db is in web_backend/
    DB_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/web_backend/auth.db"
else
    echo "ERROR: auth.db not found." >&2
    echo "       Set CODAN_AUTH_DB to the full path of your auth.db file." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Locate Python with argon2-cffi
# ---------------------------------------------------------------------------
if [[ -x "/opt/codan-hf/venv/bin/python3" ]]; then
    PYTHON="/opt/codan-hf/venv/bin/python3"
elif [[ -x "$SCRIPT_DIR/../web_backend/.venv/bin/python3" ]]; then
    PYTHON="$(cd "$SCRIPT_DIR/.." && pwd)/web_backend/.venv/bin/python3"
elif command -v python3 &>/dev/null; then
    PYTHON="python3"
else
    echo "ERROR: python3 not found on PATH." >&2
    exit 1
fi

if [[ ! -f "$DB_PATH" ]]; then
    echo "ERROR: Database not found: $DB_PATH" >&2
    exit 1
fi

echo "Resetting admin password in: $DB_PATH"

"$PYTHON" - "$DB_PATH" "$DEFAULT_PASS" <<'PYEOF'
import sys
import sqlite3
from datetime import datetime, timezone

try:
    from argon2 import PasswordHasher
except ImportError:
    print("ERROR: argon2-cffi is not installed for this Python interpreter.", file=sys.stderr)
    print("       Install with: pip install argon2-cffi", file=sys.stderr)
    sys.exit(1)

db_path = sys.argv[1]
password = sys.argv[2]

ph = PasswordHasher()
new_hash = ph.hash(password)
now = datetime.now(timezone.utc).isoformat()

conn = sqlite3.connect(db_path)
try:
    try:
        row = conn.execute("SELECT id FROM users WHERE username = 'admin'").fetchone()
    except sqlite3.OperationalError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        print("       The database may be empty or corrupt. Check CODAN_AUTH_DB.", file=sys.stderr)
        sys.exit(1)

    if row is not None:
        user_id = row[0]
        conn.execute(
            "UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?",
            (new_hash, now, user_id),
        )
        conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
    else:
        # Admin row missing (blank or migrated db) — recreate it.
        conn.execute(
            "INSERT INTO users (username, password_hash, role, notification_email, created_at, updated_at) "
            "VALUES ('admin', ?, 'admin', '', ?, ?)",
            (new_hash, now, now),
        )

    conn.commit()
    print(f"Admin password reset to: {password}")
    print("All active admin sessions have been invalidated.")
    print("Log in and change the password immediately.")
finally:
    conn.close()
PYEOF
