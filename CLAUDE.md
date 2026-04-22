# bx-Blogger — Development Instructions

> Instructions for developers (human or AI-assisted) working on bx-Blogger. This file is loaded automatically by Claude Code at the start of every session. Read it before running any commands.

## Development workflow rule (non-negotiable)

**All development commands run inside Docker containers. Never invoke `box`, `commandbox`, `testbox run`, `box migrate up`, or `box install` directly on the host.**

Production is a self-hosted Docker server running the Ortus CommandBox image. Dev mirrors that exactly. Host-level invocations break two guarantees:

1. **Dev-prod parity.** "Works on my laptop" is not a valid test surface; only "works in the container" counts.
2. **Service visibility.** The app talks to `mysql:3306`, `minio:9000`, `mailhog:1025` — compose-internal hostnames that don't resolve from the host.

### Correct

```bash
docker compose up -d                                             # boot the stack
docker compose exec app box install                              # install dependencies
docker compose exec app box migrate up                           # run DB migrations
docker compose exec app box testbox run                          # unit + integration tests
docker compose exec app box recipe ./resources/database/seed.boxr  # seed demo data (once it ships)
docker compose exec app box cbq:work --tries=3                   # run the job worker
docker compose exec app box cbplaywright:run                     # E2E tests
docker compose logs -f app                                       # follow app logs
docker compose exec app bash                                     # interactive shell in the container
docker compose down                                              # stop the stack
```

### Incorrect — do not do this

```bash
box install           # host-level CommandBox — wrong module versions, can't reach compose services
testbox run           # host-level — can't reach MySQL
migrate up            # host-level — can't reach MySQL
box server start      # host-level — not representative of production
```

## Project layout — flat

bx-Blogger uses the **flat ColdBox application layout** (based on [coldbox-templates/flat](https://github.com/coldbox-templates/flat)). Everything lives at the project root — there is no `app/` subdirectory, no `public/` vs `app/` split, no `lib/` indirection. This simplifies Docker paths dramatically and avoids the BoxLang-mapping issues that come with the mvc layout inside containers.

```text
bx-Blogger/
├── Application.bx              # web-root bootstrap (ColdBox Bootstrap loader)
├── index.bxm                   # front-controller placeholder
├── box.json                    # ForgeBox manifest
├── server.json                 # CommandBox server config (minimal)
├── robots.txt                  # crawler policy
├── favicon.ico                 # (added when branding lands)
├── config/                     # Coldbox.bx, CacheBox.bx, WireBox.bx, Router.bx, Scheduler.bx
├── handlers/                   # ColdBox event handlers (e.g., Main.bx)
├── models/                     # services, entities, value objects (Phase 1+)
├── views/                      # .bxm templates per handler/action
├── layouts/                    # page layouts wrapping views
├── includes/helpers/           # app-wide UDFs (ApplicationHelper.bxm)
├── modules_app/                # app-owned HMVC modules (admin, frontend — Phase 2+)
├── themes/                     # theme packs (Phase 3+)
├── tests/                      # TestBox specs, runner.bxm, Application.bx
├── docker/                     # Dockerfile + docker-entrypoint.sh
├── docker-compose.yml          # dev stack (root-level for easy `docker compose up`)
├── docker-compose.prod.yml     # prod stack (standalone)
├── .github/workflows/          # CI workflows
└── DEV-NOTES/                  # PLAN.md + runbooks (gitignored — never ships)
```

Dependencies installed by `box install` land at the root as well:

- `coldbox/` — ColdBox framework
- `testbox/` — TestBox
- `modules/` — third-party ForgeBox modules (gitignored; restored via `box install`)

## Base image

Runtime container: **`ortussolutions/commandbox`** (the base CommandBox image).

- Docker Hub: <https://hub.docker.com/r/ortussolutions/commandbox/>
- GitHub (Dockerfile sources): <https://github.com/Ortus-Solutions/docker-commandbox>

The `cfengine: "boxlang@1"` entry in `server.json` tells CommandBox to install BoxLang on first server start — we do not need the `:boxlang`-tagged image variant. `server.json`'s `onServerInitialInstall` then installs `bx-compat-cfml` and `bx-esapi` into the server home on first boot.

## Compose services

| Service | Purpose | Host port |
| --- | --- | --- |
| `app` | BoxLang application (ColdBox 8 + MiniServer) | `8080` |
| `worker` | cbq background job worker (profile-gated until Phase 6) | — |
| `mysql` | MySQL 8.4 database | `3306` |
| `minio` | S3-compatible object storage (dev-prod parity; MinIO in dev, configurable in prod per OPS docs) | `9000` / `9001` (dev only) |
| `mailhog` | SMTP capture + inbox UI (all outbound email goes here in dev; never leaves the machine) | `1025` SMTP / `8025` UI |

## Mail routing

- **Development:** every outbound email routes to MailHog. View the inbox at <http://localhost:8025>. No real email ever leaves a dev environment.
- **Production:** operator sets real SMTP values in `.env` (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_ENCRYPTION`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`) and the MailHog service is removed in `docker-compose.prod.yml`. Cbmailservices uses whatever values `.env` carries — switching mail provider is config-only, never code.

## Quick URLs (dev)

- Public site: <http://localhost:8080>
- Admin: <http://localhost:8080/admin> (ships Phase 2)
- Health: <http://localhost:8080/__health>
- MailHog inbox: <http://localhost:8025>
- MinIO console: <http://localhost:9001>

## Module discipline

**Install modules only when we are ready to wire them up and test them.** Some ForgeBox modules error at boot or at module activation if their config is missing or incomplete. Our rule:

1. Never add a module to `box.json` until the phase that needs it is actively building.
2. After `box install {module}`, immediately boot the stack and verify the app still renders `/__health` → 200.
3. Only then commit the box.json change.

This prevents the "install 27 modules up front, spend hours debugging which one is misconfigured" trap. Deferred modules for reference: `cbsecurity`, `cbq`, `cbmailservices`, `bcrypt`, `bx-markdown`, `bx-image`, `bx-ai` (re-added in their respective feature phases).

## Where the plan lives

- **Public:** `README.md` — outward-facing overview.
- **Private:** `DEV-NOTES/PLAN.md` — full architecture, phase breakdown, interception points, risk register, verification log. `DEV-NOTES/` is gitignored by design; it never ships with the repo.

If you're working on a feature and need design context, read `DEV-NOTES/PLAN.md`.
