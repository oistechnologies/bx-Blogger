# bx-Blogger — Development Instructions

> Instructions for developers (human or AI-assisted) working on bx-Blogger. This file is loaded automatically by Claude Code at the start of every session. Read it before running any commands.

## Development workflow rule (non-negotiable)

**All development commands run inside Docker containers. Never invoke `box`, `commandbox`, `testbox run`, `box migrate up`, or `box install` directly on the host.**

Production is a self-hosted Docker server running `ortussolutions/commandbox:boxlang`. Dev mirrors that exactly. Host-level invocations break two guarantees:

1. **Dev-prod parity.** "Works on my laptop" is not a valid test surface; only "works in the container" counts.
2. **Service visibility.** The app talks to `mysql:3306`, `minio:9000`, `mailhog:1025` — compose-internal hostnames that don't resolve from the host.

### Correct

```bash
docker compose up -d                                                 # boot the stack
docker compose exec app box install                                  # install dependencies
docker compose exec app box migrate up                               # run DB migrations
docker compose exec app testbox run                                  # unit + integration tests
docker compose exec app box recipe ./resources/database/seed.boxr    # seed demo data
docker compose exec app box cbq:work --tries=3                       # run the job worker
docker compose exec app box cbplaywright:run                         # E2E tests
docker compose logs -f app                                           # follow app logs
docker compose exec app bash                                         # interactive shell in the container
docker compose down                                                  # stop the stack
```

### Incorrect — do not do this

```bash
box install           # host-level CommandBox — wrong module versions, can't reach compose services
testbox run           # host-level — can't reach MySQL
migrate up            # host-level — can't reach MySQL
box server start      # host-level — not representative of production
```

## Base image

Runtime container: **`ortussolutions/commandbox:boxlang`** (official Ortus Solutions BoxLang image).

- Docker Hub: <https://hub.docker.com/r/ortussolutions/commandbox/>
- GitHub (Dockerfile sources): <https://github.com/Ortus-Solutions/docker-commandbox>
- RHEL variant available: `ortussolutions/commandbox:boxlang-rhel`

Build stages: `node:lts-alpine` (theme asset compilation via Vite) → `ortussolutions/commandbox:boxlang` (runtime).

## Compose services

| Service | Purpose | Host port |
|---|---|---|
| `app` | BoxLang application (ColdBox 8 + MiniServer) | `8080` |
| `worker` | cbq background job worker | — |
| `mysql` | MySQL 8.4 database | `3306` |
| `minio` | S3-compatible object storage (dev-prod parity for media, mirrors real AWS S3 in production) | `9000` / `9001` |
| `mailhog` | SMTP capture + inbox UI (all outbound email goes here in dev; never leaves the machine) | `1025` SMTP / `8025` UI |

## Mail routing

- **Development:** every outbound email routes to MailHog. View the inbox at <http://localhost:8025>. No real email ever leaves a dev environment.
- **Production:** operator sets real SMTP values in `.env` (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_ENCRYPTION`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`) and the MailHog service is removed in `docker-compose.prod.yml`. Cbmailservices uses whatever values `.env` carries — switching mail provider is config-only, never code.

## Quick URLs (dev)

- Public site: <http://localhost:8080>
- Admin: <http://localhost:8080/admin>
- MailHog inbox: <http://localhost:8025>
- MinIO console: <http://localhost:9001>

## Where the plan lives

- **Public:** `README.md` — outward-facing overview.
- **Private:** `DEV-NOTES/PLAN.md` — full architecture, phase breakdown, interception points, risk register, verification log. `DEV-NOTES/` is gitignored by design; it never ships with the repo.

If you're working on a feature and need design context, read `DEV-NOTES/PLAN.md` §17 for the full Docker / dev-env detail. Everything outside that file is either public-facing or scaffold.
