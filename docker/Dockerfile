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

CMD [ "/docker-entrypoint.sh" ]
