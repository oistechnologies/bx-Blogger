# Running Multiple bx-Blogger Sites on One Docker Host

**Audience:** operators who already have one bx-Blogger site running on a Docker host and want to add a second (or third, or tenth) distinct site alongside it — different domain, separate database, separate media, separate admin account — without tearing the first one down.

**Outcome:** each site is an independent Docker Compose stack in its own working directory, attaching to the shared reverse-proxy network (e.g., NGINX Proxy Manager's). Containers, volumes, and databases never collide because every name is prefixed with the site's `COMPOSE_PROJECT_NAME`. NPM (or your reverse proxy of choice) routes each public domain to the matching site's `app` container by name.

**Time:** ~10 minutes per additional site once you've done one end-to-end.

---

## 1. The pattern at a glance

```text
/opt/bx-blogger-sites/
├── site1/                                    ← one directory per site
│   ├── .git/                                     (each a full clone)
│   ├── .env                                      ← COMPOSE_PROJECT_NAME=blog-site1
│   ├── docker-compose.prod.yml
│   └── ... (repo contents)
├── site2/
│   ├── .git/
│   ├── .env                                      ← COMPOSE_PROJECT_NAME=blog-site2
│   ├── docker-compose.prod.yml
│   └── ... (repo contents)
└── site3/
    └── ...

Docker containers (on the shared proxy network):
  blog-site1-app     ← NPM proxy host: blog.example-one.com
  blog-site1-worker
  blog-site1-mysql
  blog-site2-app     ← NPM proxy host: blog.example-two.com
  blog-site2-worker
  blog-site2-mysql
  blog-site3-app     ← NPM proxy host: blog.example-three.com
  ...
  proxymanager       ← shared across all three
```

**Three decisions per site**, the rest is identical to a single-site deploy:

1. A unique directory path on the host.
2. A unique `COMPOSE_PROJECT_NAME` in that site's `.env`.
3. A unique public domain pointed at the NPM host's public IP.

Everything else — backups, upgrades, env values — follows the single-site playbook in [../DEPLOY.md](../../DEPLOY.md).

---

## 2. What the `COMPOSE_PROJECT_NAME` variable does for us

`docker-compose.prod.yml` is written so every `container_name` and `volume name:` templates on `${COMPOSE_PROJECT_NAME:-bx-blogger}`:

```yaml
services:
  app:
    container_name: ${COMPOSE_PROJECT_NAME:-bx-blogger}-app
  mysql:
    container_name: ${COMPOSE_PROJECT_NAME:-bx-blogger}-mysql
  worker:
    container_name: ${COMPOSE_PROJECT_NAME:-bx-blogger}-worker

volumes:
  mysql-data:
    name: ${COMPOSE_PROJECT_NAME:-bx-blogger}-mysql-prod
  backup-data:
    name: ${COMPOSE_PROJECT_NAME:-bx-blogger}-backups-prod
```

The default resolves to `bx-blogger` — so a single-site deploy that never sets the variable keeps running with the familiar `bx-blogger-app`, `bx-blogger-mysql-prod`, etc. Setting the variable in a second site's `.env` flips every name over uniformly.

```bash
# Verify what names your compose file would create, BEFORE starting:
docker compose -f docker-compose.prod.yml config | grep -E "container_name|name:"
```

---

## 3. Step-by-step — adding a second site

Assume site 1 (`blog-site1`) is already up and healthy, domain `blog.example-one.com` serving via NPM. Now we're adding `blog-site2` for `blog.example-two.com`.

### 3.1 Clone into a new directory

```bash
mkdir -p /opt/bx-blogger-sites/site2
cd /opt/bx-blogger-sites/site2
git clone https://github.com/oistechnologies/bx-Blogger.git .
```

Keep each site in its own directory. Do NOT try to share one checkout across two stacks — `docker compose` uses the current working directory for the project-default name fallback, and the two stacks' `.env` files are different.

### 3.2 Create `.env` with a unique project name

Copy the example and set `COMPOSE_PROJECT_NAME` on the very first line:

```bash
cp .env.example .env
```

Then edit `.env`:

```dotenv
# MUST be unique across every bx-Blogger stack on this host.
# Lowercase, hyphens ok, no spaces. Used as the prefix for every
# container + volume name in this stack.
COMPOSE_PROJECT_NAME=blog-site2

# Same proxy network every site attaches to
PROXY_NETWORK=docker-vm-net

# Site-specific values — different credentials per site!
DB_DATABASE=bx_blogger_site2
DB_USERNAME=site2_user
DB_PASSWORD=<a-different-strong-password>
DB_ROOT_PASSWORD=<a-different-strong-root-password>

ADMIN_EMAIL=admin@example-two.com
ADMIN_PASSWORD=<another-distinct-password>

# ... rest per .env.example
```

Credentials checklist for multi-site:

- `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_ROOT_PASSWORD` — all must differ from site 1.
- `ADMIN_EMAIL`, `ADMIN_PASSWORD` — the initial admin for site 2; different from site 1's admin.
- `MAIL_FROM_ADDRESS` — the From line for site 2's outgoing mail.
- `S3_BUCKET_MEDIA` + `S3_BUCKET_OG` (if using S3) — per-site buckets, never shared.
- `APP_URL` — site 2's public URL, used by scheduled jobs.

A `.env` template for site 2 that _only_ shows what changes from site 1:

```dotenv
COMPOSE_PROJECT_NAME=blog-site2
DB_DATABASE=bx_blogger_site2
DB_USERNAME=site2_user
DB_PASSWORD=…
DB_ROOT_PASSWORD=…
ADMIN_EMAIL=admin@example-two.com
ADMIN_PASSWORD=…
APP_URL=https://blog.example-two.com
MAIL_FROM_ADDRESS=no-reply@example-two.com
S3_BUCKET_MEDIA=bxblog-site2-media
S3_BUCKET_OG=bxblog-site2-og
```

Everything else (`PROXY_NETWORK`, `SMTP_*`, `S3_ENDPOINT`, `TRUSTED_PROXIES`, etc.) stays the same across sites.

### 3.3 Bring the stack up

```bash
docker compose -f docker-compose.prod.yml up -d
```

Verify unique naming:

```bash
docker ps --format 'table {{.Names}}\t{{.Networks}}'
```

You should see both:

```text
NAMES                NETWORKS
blog-site2-app       bx-blogger,docker-vm-net
blog-site2-worker    bx-blogger
blog-site2-mysql     bx-blogger
blog-site1-app       bx-blogger,docker-vm-net
blog-site1-worker    bx-blogger
blog-site1-mysql     bx-blogger
proxymanager         docker-vm-net
```

Each site has its own private `bx-blogger` network (they're separate networks despite the identical name — compose scopes them to the project). Both `app` containers additionally attach to `docker-vm-net`, where NPM lives.

### 3.4 Run migrations

```bash
docker compose -f docker-compose.prod.yml exec app box migrate up
```

Migrations run against that site's own MySQL (`blog-site2-mysql`). Each site has its own schema, seeded independently.

### 3.5 Add a proxy host in NPM

In the NPM dashboard (follow [NGINX-PROXY-MANAGER.md](NGINX-PROXY-MANAGER.md) for the full field-by-field walkthrough), create a second proxy host:

| Field | Site 1 (existing) | Site 2 (new) |
| --- | --- | --- |
| Domain Names | `blog.example-one.com` | `blog.example-two.com` |
| Forward Hostname / IP | `blog-site1-app` | `blog-site2-app` |
| Forward Port | `8080` | `8080` |
| Everything else | identical | identical |

NPM's internal DNS resolves both container names over the shared `docker-vm-net`; TLS + websockets + header forwarding all work the same as single-site.

### 3.6 Verify

```bash
# Each site's health endpoint answers from its own app container:
curl https://blog.example-one.com/__health
curl https://blog.example-two.com/__health

# First admin login for site 2:
open https://blog.example-two.com/admin
# → log in with the ADMIN_EMAIL / ADMIN_PASSWORD from site 2's .env
```

---

## 4. Upgrade + maintenance

Each site is managed independently. Pull, rebuild, and migrate per site:

```bash
cd /opt/bx-blogger-sites/site2
git pull
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml exec app box migrate up
```

Nothing in site 2's upgrade touches site 1. Schedule rolling upgrades across sites (one at a time) if you want a stagger-roll pattern for confidence.

Backups are per-site — each `worker` container writes its own `mysqldump` into the stack's own `*-backups-prod` volume. Off-host sync (if `BACKUP_S3_BUCKET` is set) goes to that site's dedicated bucket (`bxblog-site2-backups`, etc.) so one site's restore can never overwrite another site's data.

---

## 5. Caveats + things to watch

### 5.1 `.env` as the source of truth

Every per-site difference lives in that site's `.env`. Never commit `.env` (it's gitignored for a reason). If you manage a fleet of sites with a config tool like Ansible, template the `.env` per host.

### 5.2 Resource sizing

Each stack runs its own MySQL + worker. Rough per-site baseline on idle:

| Service | RAM idle | RAM peak |
| --- | --- | --- |
| app | 400 MB | 600 MB |
| worker | 350 MB | 550 MB |
| mysql | 400 MB | 600 MB |
| **Per-site total** | **~1.2 GB** | **~1.8 GB** |

Budget host RAM accordingly — six sites is ~7 GB idle, ~11 GB peak. Running 10+ sites on one host? Consider:

- Sharing one MySQL server across sites (separate databases). Requires deleting the `mysql` block from each site's compose and pointing `DB_HOST` at the shared instance. More moving parts; only worth it at higher density.
- Moving to a bigger host, or splitting sites across hosts.

### 5.3 Per-site BoxLang server home

Each stack has its own isolated CommandBox server home inside its `app` container. Fwreinit, compile cache, log files — all stack-local. No cross-site JVM state.

### 5.4 Dev mode and multi-instance

The pattern above applies to `docker-compose.prod.yml`. The dev `docker-compose.yml` is designed for single-developer single-checkout use; running two dev stacks in parallel works but requires the same `COMPOSE_PROJECT_NAME` discipline in separate terminal sessions (`COMPOSE_PROJECT_NAME=bxblog-dev2 docker compose up -d`). Most operators won't need this.

### 5.5 Don't share volume names across hosts

Each named volume is local to the Docker daemon. If you migrate a site to a different host, export via `mysqldump` and `docker cp`-based media backup — don't try to rsync named-volume directories directly (Docker's internal format isn't a guaranteed stable on-disk contract).

---

## 6. Removing a site

```bash
cd /opt/bx-blogger-sites/site2
docker compose -f docker-compose.prod.yml down --volumes    # ← REMOVES THE DATABASE AND UPLOADS
cd ..
rm -rf site2
```

Also: remove the NPM proxy host for that site's domain, and drop DNS if the domain is retiring.

`--volumes` is destructive. Omit it to keep the MySQL data volume around for a later restore.

---

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `network docker-vm-net not found` on site 2 `up -d` | `PROXY_NETWORK` in site 2's `.env` doesn't match an existing external network on the host | `docker network ls` — make sure the NPM network exists and the name matches exactly (case-sensitive) |
| Site 2 container names still say `bx-blogger-app` after override | `COMPOSE_PROJECT_NAME` in `.env` not picked up — you're in the wrong directory, or `.env` is missing from the same dir as the compose file | Run `docker compose -f docker-compose.prod.yml config | grep container_name` in that directory — what prints is what you'll get |
| NPM proxy host for site 2 returns 502 | NPM isn't reachable to `blog-site2-app` on the proxy network | `docker network inspect docker-vm-net | grep blog-site2-app` — should list the container with its IP |
| Site 2's scheduled jobs hitting site 1's URLs | `APP_URL` in site 2's `.env` not updated | Fix `APP_URL=https://blog.example-two.com`, restart site 2's worker |
| Can't tell which site a rogue container belongs to | Labels + names both carry the project prefix | `docker inspect <container> --format '{{.Config.Labels}}'` — look for `com.docker.compose.project` |

---

## 8. See also

- [../DEPLOY.md](../../DEPLOY.md) — single-site deploy guide (the path every site starts from).
- [NGINX-PROXY-MANAGER.md](NGINX-PROXY-MANAGER.md) — NPM proxy-host setup (applied per site here).
- [S3-BACKUP-SETUP.md](S3-BACKUP-SETUP.md) — per-site bucket strategy for off-host backups.
- [S3-COMPATIBLE-PROVIDERS.md](S3-COMPATIBLE-PROVIDERS.md) — S3 provider env-var values (each site picks its own bucket; providers can be shared).
