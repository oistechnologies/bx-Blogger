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
# Dev mode installs devDependencies too (testbox, cfformat, cbdebugger,
# route-visualizer) so `docker compose exec app box run-script test` works.
# Prod Dockerfile variant should override with --production.
echo "[bx-blogger] Running box install (idempotent)..."
box install --verbose

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
# --console keeps the process in foreground (required for PID 1 / container lifetime).
# --rc was dropped — server.json's top-level "rc": true expresses the same intent
# and the flag was redundant (and possibly conflicting) in our config.
exec box server start --console
