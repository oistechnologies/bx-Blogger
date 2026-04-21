#!/usr/bin/env bash
# =============================================================================
# docker-entrypoint.sh — container startup script
#
# Order of operations:
#   1. Wait for MySQL to accept connections (up to 60s)
#   2. Re-run `box install --production` to catch any box.json changes from
#      a bind-mounted dev environment (idempotent — skips already-installed
#      modules)
#   3. Run pending database migrations (skipped at Phase 0 — no migrations
#      directory yet)
#   4. Start the BoxLang MiniServer on :8080
# =============================================================================

set -euo pipefail

echo "[bx-blogger] Entrypoint starting at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[bx-blogger] Environment: ${ENVIRONMENT:-unknown}"
echo "[bx-blogger] BoxLang debug: ${BOXLANG_DEBUG:-false}"

# ---------------------------------------------------------------------------
# 1. Wait for MySQL
# ---------------------------------------------------------------------------
if [ -n "${DB_HOST:-}" ] && [ -n "${DB_PORT:-}" ]; then
    echo "[bx-blogger] Waiting for MySQL at ${DB_HOST}:${DB_PORT} (up to 60s)..."
    ./resources/docker/wait-for-it.sh "${DB_HOST}:${DB_PORT}" --timeout=60 --strict
else
    echo "[bx-blogger] WARN: DB_HOST/DB_PORT not set — skipping database wait"
fi

# ---------------------------------------------------------------------------
# 2. box install (idempotent — safe to run every startup)
# ---------------------------------------------------------------------------
echo "[bx-blogger] Running box install --production (idempotent)..."
box install --production --verbose

# ---------------------------------------------------------------------------
# 3. Database migrations
# ---------------------------------------------------------------------------
MIGRATIONS_DIR="./resources/database/migrations"

if [ -d "$MIGRATIONS_DIR" ] && [ -n "$(ls -A "$MIGRATIONS_DIR" 2>/dev/null)" ]; then
    echo "[bx-blogger] Running database migrations..."
    box migrate up --force
else
    echo "[bx-blogger] No migrations present at $MIGRATIONS_DIR — skipping (Phase 0 state)"
fi

# ---------------------------------------------------------------------------
# 4. Start MiniServer
# ---------------------------------------------------------------------------
echo "[bx-blogger] Starting BoxLang MiniServer on :8080..."
exec box server start --rc --console
