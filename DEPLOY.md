# Deploying bx-Blogger

Step-by-step guide for operators setting up a single bx-Blogger site on a Docker host, behind a reverse proxy. If you're running multiple sites on the same host, follow this guide for the first site, then see [docs/operators/MULTI-INSTANCE.md](docs/operators/MULTI-INSTANCE.md) for each additional one.

**Target setup:**

- A Docker host (bare metal, VPS, cloud VM — anything with `docker` + `docker compose` v2+)
- A reverse proxy for TLS termination ([NGINX Proxy Manager](https://nginxproxymanager.com) recommended; Caddy, Traefik, or hand-rolled NGINX also fine)
- A domain name with DNS pointed at the Docker host's public IP
- An email address for Let's Encrypt cert issuance

**Time:** ~15 minutes once DNS has propagated.

---

## 1. Prerequisites

### Docker

Docker Engine 20.10+ and Docker Compose v2+ installed on the host:

```bash
docker --version                  # 20.10 or later
docker compose version            # v2.0 or later
```

If missing, follow [Docker's install guide](https://docs.docker.com/engine/install/) for your distro.

### Reverse proxy

This guide assumes **NGINX Proxy Manager (NPM)**. See [docs/operators/NGINX-PROXY-MANAGER.md](docs/operators/NGINX-PROXY-MANAGER.md) for the NPM-specific walkthrough. For Caddy / Traefik / bare NGINX, the app container still accepts HTTP on port 8080 and expects the standard `X-Forwarded-*` headers — adapt the NPM runbook to your proxy's config syntax.

You need your proxy's Docker network name. Inspect with:

```bash
docker network ls
```

### Domain + DNS

Point an `A` record at the host's public IP:

```dns
blog.example.com.   300   IN   A   203.0.113.42
```

Propagation takes 5–60 minutes depending on TTL. Let's Encrypt issuance will fail until DNS resolves — wait for `dig blog.example.com` to return the right IP before continuing.

---

## 2. Clone the repository

```bash
sudo mkdir -p /opt/bx-blogger
sudo chown $USER:$USER /opt/bx-blogger
cd /opt/bx-blogger
git clone https://github.com/mrigsby/bx-Blogger.git .
```

Pick any directory — `/opt/bx-blogger` is a convention. Keep it somewhere with enough room to grow (media uploads, database, backups all live in Docker-managed volumes by default — ~10 GB is a comfortable start).

---

## 3. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env`. The values below are the ones you **must** change before first boot; everything else in `.env.example` has sensible defaults.

### Required — identity + security

```dotenv
# Unique secret for this install. Generate once, keep secret.
# openssl rand -base64 32
APP_KEY=PASTE_OUTPUT_OF_openssl_rand_HERE

# Public URL of your blog. Used for absolute links in email (password
# reset, email verify, notifications). No trailing slash.
APP_URL=https://blog.example.com
```

### Required — database credentials

```dotenv
# These are the credentials the app uses to talk to MySQL. Change
# BOTH passwords — leaving the defaults makes the database trivially
# accessible to any process inside the Docker network.
DB_PASSWORD=a-long-random-password
DB_ROOT_PASSWORD=a-different-long-random-password
```

Generate two strong passwords:

```bash
openssl rand -base64 24    # for DB_PASSWORD
openssl rand -base64 24    # for DB_ROOT_PASSWORD
```

### Required — reverse proxy wiring

```dotenv
# Name of the Docker network your reverse proxy is attached to.
# Find it with `docker network ls`. Typical defaults: npm_default,
# proxy, docker-vm-net, nginxproxymanager_default.
PROXY_NETWORK=npm_default

# CIDR(s) you trust to send `X-Forwarded-For` headers. The default
# covers localhost + the common Docker bridge range (172.16.0.0/12).
# If your proxy sits on a custom network, add that network's CIDR.
# Comma-separated.
TRUSTED_PROXIES=127.0.0.1/32,172.16.0.0/12
```

### Required — first admin account

```dotenv
# On first boot, bx-Blogger creates a super_admin user with these
# credentials IF the users table is empty. Change the password BEFORE
# you `docker compose up` — the default is a known-bad placeholder.
ADMIN_EMAIL=you@example.com
ADMIN_PASSWORD=ChangeMe-Before-You-Deploy-4242!
```

### Required — outbound email

```dotenv
# Point at any SMTP provider — Mailgun, SendGrid, Amazon SES, Postmark,
# self-hosted Postfix, Gmail-for-Workspace with app password, etc.
SMTP_HOST=smtp.example-mail-provider.com
SMTP_PORT=587
SMTP_USERNAME=your-smtp-user
SMTP_PASSWORD=your-smtp-password
SMTP_ENCRYPTION=tls
MAIL_FROM_ADDRESS=no-reply@example.com
MAIL_FROM_NAME=Blog Example
```

### Optional — notification email destination

```dotenv
# Where admin-alert notifications (failed jobs, daily digest) go.
# Typically your own email. Leave blank to disable the email channel
# (in-app bell notifications still work).
BX_NOTIFICATION_EMAIL=ops@example.com
```

### Optional — timezone

```dotenv
# IANA tz name. Applied to OS clock (every container), JVM, MySQL,
# and ColdBox scheduler firing. Defaults to America/New_York.
APP_TIMEZONE=America/New_York
```

### Optional — S3-compatible object storage

By default, media uploads and generated OG images are stored on a Docker volume. For production deployments with multiple app instances or off-host-backup redundancy, point at S3 or any S3-compatible backend. See:

- [docs/operators/S3-COMPATIBLE-PROVIDERS.md](docs/operators/S3-COMPATIBLE-PROVIDERS.md) — the env-var block per provider (AWS S3, Cloudflare R2, Backblaze B2, Wasabi, DigitalOcean Spaces, self-hosted MinIO)
- [docs/operators/S3-BACKUP-SETUP.md](docs/operators/S3-BACKUP-SETUP.md) — AWS S3 runbook with bucket + IAM + CloudFront
- [docs/operators/BACKBLAZE-B2.md](docs/operators/BACKBLAZE-B2.md) — Backblaze B2 runbook with bucket + scoped keys + optional Cloudflare fronting
- [docs/operators/MINIO-SELF-HOSTED.md](docs/operators/MINIO-SELF-HOSTED.md) — self-host a MinIO instance in the prod stack

You can skip all of this on first deploy and turn it on later without data loss — the relevant env vars flip the backend without migration.

---

## 4. Start the stack

```bash
docker compose -f docker-compose.prod.yml up -d
```

Three containers come up — `bx-blogger-app`, `bx-blogger-worker`, `bx-blogger-mysql`. The app runs migrations automatically on first boot, creates the initial super_admin from the `ADMIN_*` env vars, and seeds a sample "Welcome to bx-Blogger" post.

Watch the boot logs:

```bash
docker compose -f docker-compose.prod.yml logs -f app
```

Give it ~30 seconds. You're looking for:

```text
+++ ColdBox is ready to serve requests
```

Once that appears, the app is live on the container network (not yet reachable from the internet — that's step 5).

### Verify internal health

From the host:

```bash
docker compose -f docker-compose.prod.yml exec app curl -sS http://localhost:8080/__health
```

Expected:

```json
{"status":"ok","version":"0.1.0","phase":"8","timestamp":"…"}
```

If `/__health` doesn't answer, something's wrong — check logs first:

```bash
docker compose -f docker-compose.prod.yml logs app --tail=100
```

---

## 5. Wire up the reverse proxy

Follow [docs/operators/NGINX-PROXY-MANAGER.md](docs/operators/NGINX-PROXY-MANAGER.md) for NPM. The short version:

1. Confirm NPM and the bx-Blogger `app` container share the network named in `PROXY_NETWORK`:

   ```bash
   docker network inspect $PROXY_NETWORK | grep -E "bx-blogger-app|proxymanager|nginx"
   ```

2. In NPM's dashboard, add a Proxy Host:
   - **Domain:** `blog.example.com`
   - **Forward Hostname / IP:** `bx-blogger-app`
   - **Forward Port:** `8080`
   - **Block Common Exploits:** on
   - **Websockets Support:** **on** (required for the admin's live UI)
3. SSL tab:
   - Request a new Let's Encrypt certificate
   - **Force SSL:** on
   - **HTTP/2 Support:** on
4. Advanced tab — paste the `X-Forwarded-*` header block from the NPM runbook so the app sees real client IPs.
5. Save. NPM requests the cert, reloads nginx, and starts routing. ~15 seconds.

For Caddy, Traefik, or bare NGINX, proxy `https://blog.example.com` → `http://bx-blogger-app:8080` over the same Docker network, set the `X-Forwarded-*` headers, and enable websockets.

---

## 6. Verify end-to-end

```bash
# HTTP should 301 to HTTPS
curl -I http://blog.example.com/__health

# HTTPS should return the health JSON
curl https://blog.example.com/__health
```

Browse to `https://blog.example.com/admin` and log in with the `ADMIN_EMAIL` + `ADMIN_PASSWORD` from `.env`. **Change the password immediately** via My Account → Password.

Smoke-test checklist:

- [ ] `/__health` returns 200 + valid JSON
- [ ] `/` renders the public site (Welcome post visible)
- [ ] `/feed.xml` returns valid RSS
- [ ] `/sitemap.xml` returns valid XML
- [ ] `/robots.txt` returns the expected plain-text directives
- [ ] `/admin` login works
- [ ] After login, the admin dashboard loads without errors
- [ ] A new post can be created, previewed, and published
- [ ] The published post is reachable at `/blog/your-slug`

---

## 7. Upgrading

When a new bx-Blogger release lands:

```bash
cd /opt/bx-blogger
git pull
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml exec app box migrate up
```

Migrations are forward-only and idempotent — re-running `migrate up` on an already-current database is a no-op. Downtime during an upgrade is typically <30 seconds (the restart time of the `app` container).

For a zero-downtime upgrade across two instances behind a load balancer, see the rolling-restart pattern in [docs/operators/MULTI-INSTANCE.md](docs/operators/MULTI-INSTANCE.md).

---

## 8. Backup + restore

### Database

`BackupDatabaseJob` runs nightly inside the `worker` container — `mysqldump --single-transaction --quick --triggers --routines` into the `backup-data` volume, 14-day rotation. You can trigger an on-demand backup:

```bash
docker compose -f docker-compose.prod.yml exec worker box task run BackupDatabaseJob
```

Dumps land in the `bx-blogger-backups-prod` Docker volume. Inspect:

```bash
docker run --rm -v bx-blogger-backups-prod:/b alpine ls -lh /b
```

For off-host sync (strongly recommended for real deployments), set `BACKUP_S3_BUCKET` in `.env` and the job uploads each night's dump to your S3 bucket as well. Full runbook: [docs/operators/S3-BACKUP-SETUP.md](docs/operators/S3-BACKUP-SETUP.md).

### Restore from a SQL dump

```bash
# Copy a dump into the mysql container
docker cp ./backup-20261023.sql bx-blogger-mysql:/tmp/
docker compose -f docker-compose.prod.yml exec mysql \
    sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" < /tmp/backup-20261023.sql'
```

Then `fwreinit` the app so any cached queries re-run against the restored rows:

```bash
docker compose -f docker-compose.prod.yml exec app curl -sS 'http://localhost:8080?fwreinit=1' -o /dev/null
```

### Media

Media files live on a Docker volume (`bx-blogger-media-prod`) by default. Include volume backups in your host-level backup strategy, or flip media to S3 storage via `.env` for automatic off-host redundancy.

---

## 9. Multi-site on one host

If you want to run a second bx-Blogger site on the same Docker host, see [docs/operators/MULTI-INSTANCE.md](docs/operators/MULTI-INSTANCE.md). The short version: clone into a second directory, set `COMPOSE_PROJECT_NAME=<unique-name>` in that site's `.env`, and every container + volume auto-prefixes with that project name — no collisions with this first site.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `network npm_default not found` on `docker compose up` | `PROXY_NETWORK` doesn't match any existing Docker network | Run `docker network ls`; use the exact name your reverse proxy's compose stack attached to |
| `502 Bad Gateway` from the reverse proxy | Proxy and bx-Blogger `app` containers aren't on the same network | `docker network inspect $PROXY_NETWORK` — confirm both containers listed |
| Admin login fails with correct credentials | `ADMIN_EMAIL` + `ADMIN_PASSWORD` changed in `.env` AFTER first boot | The first-boot seed only runs when `users` is empty. Use `docker compose exec app box testbox run` → `PasswordService.hash("your-new-password")`, then `UPDATE users SET password_hash='…' WHERE email='…'` |
| Public site shows IP = Docker internal (172.x.x.x) in audit log | Reverse proxy not forwarding `X-Forwarded-For`, OR proxy's IP not in `TRUSTED_PROXIES` | Add the relevant headers to proxy config (see NPM runbook §3.5 Advanced tab). Add the proxy's network CIDR to `TRUSTED_PROXIES` in `.env` |
| Websockets-powered admin UI doesn't react to clicks | Reverse proxy not forwarding websocket upgrade | Enable "Websockets Support" on the proxy host (NPM: Details tab → toggle on) |
| Let's Encrypt cert fails to issue | DNS not yet pointing at the host, or port 80 blocked | `dig blog.example.com` should resolve to the host IP. Check host firewall allows 80 + 443 inbound |
| `APP_KEY not set` error at boot | You skipped step 3's `APP_KEY` generation | `openssl rand -base64 32`, paste into `.env`, restart |

For deeper troubleshooting, check the app logs:

```bash
docker compose -f docker-compose.prod.yml logs app --tail=200
docker compose -f docker-compose.prod.yml logs worker --tail=200
```

---

## 11. Next steps

- **[README.md](README.md)** — what bx-Blogger is and what it does
- **[docs/operators/](docs/operators/)** — the full operator runbook set
- File an issue at <https://github.com/mrigsby/bx-Blogger/issues> if you hit something this guide didn't cover
