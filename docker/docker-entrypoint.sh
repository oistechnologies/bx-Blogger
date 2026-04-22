#!/usr/bin/env bash
# =============================================================================
# docker-entrypoint.sh — minimal wrapper around the Ortus image's run.sh
#
# Run ORDER:
#   1. Run database migrations (if migrations dir exists — skipped Phase 0)
#   2. Hand off to Ortus's ${BUILD_DIR}/run.sh which starts the server in
#      Docker-friendly foreground mode
#
# docker compose's `depends_on: mysql: condition: service_healthy` handles
# the MySQL-wait step, so we no longer need wait-for-it.sh in the entrypoint.
# =============================================================================

set -euo pipefail

echo "[bx-blogger] Entrypoint starting at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "[bx-blogger] Environment: ${ENVIRONMENT:-unknown}"

cd "${APP_DIR}"

# ---------------------------------------------------------------------------
# Database migrations (skipped when no migrations/ dir — Phase 0 state)
# ---------------------------------------------------------------------------
MIGRATIONS_DIR="${APP_DIR}/resources/database/migrations"

if [ -d "$MIGRATIONS_DIR" ] && [ -n "$(ls -A "$MIGRATIONS_DIR" 2>/dev/null)" ]; then
    echo "[bx-blogger] Running database migrations..."
    box migrate up --force
else
    echo "[bx-blogger] No migrations present at $MIGRATIONS_DIR — skipping"
fi

# ---------------------------------------------------------------------------
# Hand off to Ortus's run.sh (Docker-friendly foreground server start)
# ---------------------------------------------------------------------------
echo "[bx-blogger] Starting server via Ortus run.sh..."
exec "${BUILD_DIR}/run.sh"
