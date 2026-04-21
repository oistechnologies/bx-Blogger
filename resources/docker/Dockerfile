# =============================================================================
# bx-Blogger Dockerfile (multi-stage)
#
# Stage 1 — assets (node:lts-alpine):
#   Compiles theme SCSS + JS via Vite.
#   Phase 0 ships no themes; the wrapper script produces no output and exits 0.
#
# Stage 2 — runtime (ortussolutions/commandbox:boxlang):
#   Official Ortus BoxLang image.
#     https://hub.docker.com/r/ortussolutions/commandbox/
#     https://github.com/Ortus-Solutions/docker-commandbox
#   Runs `box install --production` at build (layer-cached), pulls compiled
#   theme assets from stage 1, hands off to docker-entrypoint.sh.
# =============================================================================

# ----------------------------------------------------------------------
# Stage 1 — theme asset builder
# ----------------------------------------------------------------------
FROM node:lts-alpine AS assets

WORKDIR /build

# Install node deps first for layer caching
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund

# Then sources
COPY vite.config.js ./
COPY resources/node ./resources/node
COPY app/themes ./app/themes

# Build themes (no-op at Phase 0 — no themes present yet)
RUN sh ./resources/node/build-themes.sh

# ----------------------------------------------------------------------
# Stage 2 — BoxLang runtime
# ----------------------------------------------------------------------
FROM ortussolutions/commandbox:boxlang

WORKDIR /app

# Manifest + server config first so `box install` layer caches across
# non-dependency code changes.
COPY box.json server.json ./

# Install production dependencies from ForgeBox. The `--verbose` output
# is useful for Phase 0 troubleshooting and for CI log inspection.
RUN box install --production --verbose

# Application code + static assets
COPY app         ./app/
COPY public      ./public/
COPY resources   ./resources/
COPY runtime     ./runtime/
COPY tests       ./tests/

# Compiled theme assets from stage 1 (Phase 0: empty; Phase 3+: populated)
COPY --from=assets /build/public/themes ./public/themes/

# Entrypoint scripts must be executable
RUN chmod +x ./resources/docker/docker-entrypoint.sh \
             ./resources/docker/wait-for-it.sh

EXPOSE 8080

ENTRYPOINT [ "./resources/docker/docker-entrypoint.sh" ]
