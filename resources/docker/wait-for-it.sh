#!/usr/bin/env bash
# =============================================================================
# wait-for-it.sh — waits for a TCP host:port to accept connections
#
# Minimal implementation using Bash's /dev/tcp feature. No external deps
# (no nc, no curl, no netcat — just Bash).
#
# Inspired by vishnubob/wait-for-it; MIT-licensed equivalent suitable for
# vendoring directly into a project.
#
# Usage:
#   ./wait-for-it.sh host:port [--timeout=SECONDS] [--strict]
#
#   --timeout=N   Seconds to wait before giving up (default 15)
#   --strict      Exit non-zero on timeout (default: exit 0)
# =============================================================================

set -euo pipefail

TIMEOUT=15
STRICT=0
HOST=""
PORT=""

usage() {
    echo "Usage: $0 host:port [--timeout=SECONDS] [--strict]" >&2
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --timeout=*) TIMEOUT="${arg#*=}" ;;
        --strict)    STRICT=1 ;;
        -h|--help)   usage ;;
        *:*)
            HOST="${arg%%:*}"
            PORT="${arg##*:}"
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage
            ;;
    esac
done

[ -z "$HOST" ] && usage
[ -z "$PORT" ] && usage

echo "[wait-for-it] Waiting up to ${TIMEOUT}s for ${HOST}:${PORT}..."

start_ts=$(date +%s)
while true; do
    # Bash's /dev/tcp opens a TCP connection; the subshell isolates redirection
    if (exec 3<>"/dev/tcp/${HOST}/${PORT}") 2>/dev/null; then
        exec 3<&- 3>&- 2>/dev/null || true
        elapsed=$(( $(date +%s) - start_ts ))
        echo "[wait-for-it] ${HOST}:${PORT} is available after ${elapsed}s"
        exit 0
    fi

    now_ts=$(date +%s)
    if [ $((now_ts - start_ts)) -ge "$TIMEOUT" ]; then
        echo "[wait-for-it] Timeout after ${TIMEOUT}s waiting for ${HOST}:${PORT}" >&2
        [ "$STRICT" -eq 1 ] && exit 1
        exit 0
    fi

    sleep 1
done
