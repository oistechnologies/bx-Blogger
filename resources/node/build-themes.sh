#!/bin/sh
# =============================================================================
# build-themes.sh — run `vite build` only if at least one theme has a src/ dir
#
# Phase 0 ships with no themes under app/themes/. Running Vite against an
# empty `rollupOptions.input` errors out. This wrapper detects that case and
# exits 0 cleanly so the Dockerfile asset-builder stage (and `npm run build`
# on the host) succeed at Phase 0 and pick up themes automatically from
# Phase 3 onward.
#
# Always ensures ./public/themes/ exists (even as an empty directory) so the
# Dockerfile's runtime stage can COPY --from=assets /build/public/themes
# without errors.
# =============================================================================

set -e

THEMES_DIR="./app/themes"
OUT_DIR="./public/themes"

# Ensure the output dir exists so downstream COPY --from=assets always works,
# whether we build anything or not.
mkdir -p "$OUT_DIR"

if [ ! -d "$THEMES_DIR" ]; then
    echo "[build-themes] $THEMES_DIR does not exist — skipping Vite build."
    exit 0
fi

# Ignore dotfiles (.gitkeep) when checking for themes
if [ -z "$(ls -A "$THEMES_DIR" 2>/dev/null | grep -v '^\.')" ]; then
    echo "[build-themes] $THEMES_DIR has no themes — skipping Vite build (Phase 0 state)."
    exit 0
fi

HAS_SRC=0
for dir in "$THEMES_DIR"/*/; do
    [ -d "${dir}src" ] && HAS_SRC=1 && break
done

if [ "$HAS_SRC" -eq 0 ]; then
    echo "[build-themes] No theme under $THEMES_DIR has a src/ directory — skipping."
    exit 0
fi

echo "[build-themes] Theme(s) found — invoking Vite..."
exec npx vite build
