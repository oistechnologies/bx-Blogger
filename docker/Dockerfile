# =============================================================================
# bx-Blogger Dockerfile (flat layout)
#
# Based on the cbtemplate-flat pattern:
#   https://github.com/coldbox-templates/flat/blob/development/docker/Dockerfile
#
# Key differences from the old mvc-layout Dockerfile:
#   - Single COPY of the whole project (flat layout = single tree)
#   - Uses ortussolutions/commandbox base (cfengine:boxlang@1 in server.json
#     tells CommandBox to install BoxLang — no need for the boxlang-tagged variant)
#   - Uses Ortus image's built-in warmup-server.sh + run.sh (our entrypoint
#     just wraps it to add migrations)
#   - No multi-stage — Vite theme compilation re-introduced in Phase 3
#     (Phase 0 ships no themes)
# =============================================================================

FROM ortussolutions/commandbox

LABEL maintainer="Michael Rigsby"
LABEL repository="https://github.com/mrigsby/bx-Blogger"

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

# Copy the full project — .dockerignore filters out .git, DEV-NOTES, .env, etc.
COPY ./ ${APP_DIR}/

# Install ColdBox + modules from box.json. Dev image includes devDependencies
# (testbox, cbdebugger, etc.) so `docker compose exec app box run-script test`
# works. Production image should rebuild with `box install --production`.
RUN cd ${APP_DIR} && box install

# Ortus image ships a warmup script that starts the server once during build,
# compiles classes into the server home, and shuts down. Subsequent container
# starts are fast (<2s instead of 60s+).
RUN ${BUILD_DIR}/util/warmup-server.sh

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
