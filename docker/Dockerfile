# =============================================================================
# bx-Blogger Dockerfile (flat layout)
#
# Two-stage build:
#
#   1. theme-builder  — node:20-alpine. Installs the npm deps declared
#      in package.json (vite, sass, bootstrap, glob) and runs
#      `npm run build` (→ build-themes.mjs) to produce
#      themes/{slug}/assets/{css,js}/ for every registered theme.
#      `themes/*/assets/` is gitignored, so this stage is the only
#      place compiled CSS/JS gets produced for the published image.
#
#   2. runtime        — ortussolutions/commandbox. The actual app
#      image: copies the source, overlays built theme assets from
#      stage 1, installs box.json deps, warms up the server home.
#
# Based on the cbtemplate-flat pattern:
#   https://github.com/coldbox-templates/flat/blob/development/docker/Dockerfile
#
# cfengine:boxlang@1 in server.json tells CommandBox to install BoxLang
# on first server start, so we don't need the :boxlang image variant.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1 — theme-builder
# -----------------------------------------------------------------------------
# Always build theme assets on the native arch of the build host
# (`$BUILDPLATFORM`), regardless of the image's target arch. The output is
# pure CSS + JS — arch-independent — so there's no reason to pay QEMU
# emulation cost on cross-arch buildx legs. This also dodges a known bug
# where `npm ci` hangs indefinitely on linux/arm64 under QEMU due to
# Node's `getrandom()` + sass native-binding post-install scripts.
FROM --platform=$BUILDPLATFORM node:20-alpine AS theme-builder

WORKDIR /build

# Install deps first so Docker caches the npm layer across builds
# that only touch theme source (the expected common case). A change
# to package.json / package-lock.json busts this cache; theme-only
# edits skip straight to the build step.
COPY package.json package-lock.json ./
RUN npm ci

# Build driver + theme sources. Everything `build-themes.mjs` needs.
COPY vite.config.js build-themes.mjs ./
COPY themes ./themes

# Produces themes/{slug}/assets/{css,js}/ for every discovered theme.
RUN npm run build


# -----------------------------------------------------------------------------
# Stage 2 — runtime
# -----------------------------------------------------------------------------
FROM ortussolutions/commandbox

# Auto-populated by buildx for multi-platform builds. We use them below to
# detect cross-arch builds (BUILDPLATFORM != TARGETPLATFORM, i.e. QEMU
# emulation) and skip the warmup step that's prohibitively slow under it.
ARG BUILDPLATFORM
ARG TARGETPLATFORM

LABEL maintainer="Michael Rigsby"
LABEL repository="https://github.com/oistechnologies/bx-Blogger"

# Healthcheck endpoint the Ortus image uses to verify the server is live.
# ${PORT} is provided by the base image (default 8080).
ENV HEALTHCHECK_URI="http://127.0.0.1:${PORT}/__health"

# Image + DB CLI tools for the Phase 6 job suite:
#   - `webp` — cwebp CLI for WebpConvertJob (6.F). Java ImageIO doesn't
#     ship a WebP writer and bundling a third-party Java WebP JAR adds
#     maintenance overhead; libwebp's CLI is Google-maintained.
#   - `default-mysql-client` — `mysqldump` for BackupDatabaseJob (6.G).
#     Same logic: shelling out to the vendor client is cheaper than
#     pulling in a JDBC-driven dump library and produces identical
#     output to what an operator would get running the command by hand.
#   - `gzip` — already in the base image, but listed here for clarity
#     since BackupDatabaseJob pipes through it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends webp default-mysql-client gzip \
    && rm -rf /var/lib/apt/lists/*

# Copy the full project — .dockerignore filters out .git, DEV-NOTES, .env,
# node_modules, themes/*/assets, etc.
COPY ./ ${APP_DIR}/

# Overlay compiled theme assets from stage 1. The builder's `themes/`
# is a superset of the source (same files + built `assets/` per theme),
# so this replaces the themes/ dir wholesale — safe and idempotent.
COPY --from=theme-builder /build/themes ${APP_DIR}/themes

# Install ColdBox + modules from box.json. Dev image includes devDependencies
# (testbox, cbdebugger, etc.) so `docker compose exec app box run-script test`
# works. Production image should rebuild with `box install --production`.
RUN cd ${APP_DIR} && box install

# Ortus image ships a warmup script that starts the server once during build,
# compiles classes into the server home, and shuts down. Subsequent container
# starts are fast (<2s instead of 60s+).
#
# Skip the warmup on cross-arch buildx legs (BUILDPLATFORM != TARGETPLATFORM,
# meaning we're running under QEMU emulation). Booting BoxLang under emulation
# took the GHA arm64 leg over the 20m job timeout. Native builds — amd64 prod
# images on the GHA runner, arm64 images built on Apple Silicon — still warm
# up. Arm64 images pulled to a Mac will cold-start once (~60s) on first run
# but every subsequent start is fast; that's an acceptable trade.
RUN if [ "${BUILDPLATFORM}" = "${TARGETPLATFORM}" ] || [ -z "${TARGETPLATFORM}" ]; then \
        ${BUILD_DIR}/util/warmup-server.sh; \
    else \
        echo "Skipping warmup-server.sh — cross-arch build (BUILDPLATFORM=${BUILDPLATFORM}, TARGETPLATFORM=${TARGETPLATFORM})"; \
    fi

# Our entrypoint wraps Ortus's run.sh to add database-migration handling.
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Phase 10.D — cbq worker entrypoint with SIGTERM drain + 30s grace.
# Only the prod `worker` service in docker-compose.prod.yml uses this
# (overrides CMD with `/cbq-worker-entrypoint.sh`); the app container
# still boots via docker-entrypoint.sh above. See the script header for
# the rationale + compose settings required alongside it.
COPY docker/cbq-worker-entrypoint.sh /cbq-worker-entrypoint.sh
RUN chmod +x /cbq-worker-entrypoint.sh

CMD [ "/docker-entrypoint.sh" ]
