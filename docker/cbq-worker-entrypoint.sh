#!/usr/bin/env bash
# =============================================================================
# cbq-worker-entrypoint.sh — graceful-shutdown wrapper for the cbq worker
# =============================================================================
#
# Purpose (Phase 10.D):
#   When Docker sends SIGTERM to the worker container — every `docker compose
#   up -d` during a deploy, every host reboot, every rolling restart — give
#   the cbq worker up to 30 seconds to finish whatever job it's currently
#   executing before hard-killing the process.
#
# Without this wrapper, `box cbq:work` is PID 1 of the container and
# Docker's default 10-second stop-grace timeout SIGKILLs the JVM mid-job on
# every deploy. The `cbq_jobs` row stays `reserved_at=<stale>` and cbq's
# stale-reservation sweep eventually reclaims + retries the job (our jobs
# are `--tries=3` idempotent), but the job that was 90% done gets redone
# from scratch. This wrapper closes that gap for the common case.
#
# How it works:
#   1. Start `box cbq:work --tries=3` as a BACKGROUND child process and
#      record its PID.
#   2. Trap SIGTERM/SIGINT/SIGQUIT in this wrapper.
#   3. On signal: forward SIGTERM to the child, then poll up to 30s for
#      the child to exit cleanly.
#   4. If the child hasn't exited after 30s, SIGKILL it so Docker's own
#      kill-timeout doesn't fire first.
#   5. Exit with the child's status (or 137 if we SIGKILLed it).
#
# Caveat on cbq's SIGTERM behavior:
#   cbq v5 does not currently install a "finish current job then exit"
#   signal handler in its CLI worker loop — SIGTERM to `box cbq:work`
#   just terminates the JVM abruptly. This wrapper gives cbq a chance
#   to honor the signal if a future version adds handling (no code
#   change on our side), while keeping the hard 30s cap so a hung
#   worker can't block the deploy indefinitely.
#
# Compose config required alongside this script:
#
#   services:
#     worker:
#       command: [ "/cbq-worker-entrypoint.sh" ]
#       stop_grace_period: 35s    # ≥ the 30s drain cap below
#
# See also: PLAN.md Phase 10.D, DEPLOY-CICD-PLAN.md §rollback playbook.
# =============================================================================

set -euo pipefail

# Drain budget — Docker's `stop_grace_period: 35s` should be ≥ this.
: "${CBQ_DRAIN_SECONDS:=30}"

log() {
    echo "[cbq-worker] $(date -u +%H:%M:%S)  $*"
}

log "Starting cbq worker (drain budget: ${CBQ_DRAIN_SECONDS}s)"

cd "${APP_DIR:-/app}"

# Launch cbq:work in the background so the trap in this shell can fire.
box cbq:work --tries=3 &
WORKER_PID=$!

log "cbq worker started with PID ${WORKER_PID}"

drain_and_exit() {
    local sig=$1
    log "Received ${sig} — forwarding SIGTERM to cbq (PID ${WORKER_PID})"

    if ! kill -TERM "${WORKER_PID}" 2>/dev/null; then
        # Child already gone — nothing to drain.
        log "cbq already exited before SIGTERM could be delivered"
        exit 0
    fi

    local waited=0
    while [ "${waited}" -lt "${CBQ_DRAIN_SECONDS}" ]; do
        if ! kill -0 "${WORKER_PID}" 2>/dev/null; then
            log "cbq exited cleanly after ${waited}s"
            # Collect the child's exit status so this wrapper's own
            # exit code reflects the worker's.
            wait "${WORKER_PID}" 2>/dev/null || true
            exit 0
        fi
        sleep 1
        waited=$(( waited + 1 ))
    done

    log "cbq still running after ${CBQ_DRAIN_SECONDS}s drain cap — SIGKILL"
    kill -KILL "${WORKER_PID}" 2>/dev/null || true
    # 137 = 128 + SIGKILL; matches what Docker would report for a
    # forcibly-killed process, so log aggregators can key off it.
    exit 137
}

trap 'drain_and_exit SIGTERM' SIGTERM
trap 'drain_and_exit SIGINT'  SIGINT
trap 'drain_and_exit SIGQUIT' SIGQUIT

# Block on the child. If it exits on its own (crash, clean shutdown via
# some internal signal, etc.), we exit with its status.
wait "${WORKER_PID}"
EXIT_CODE=$?
log "cbq worker exited on its own with status ${EXIT_CODE}"
exit "${EXIT_CODE}"
