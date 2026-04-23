# Operator Runbook — Self-Hosted MinIO in Production

**Audience:** operators who want to run bx-Blogger's object storage backend as a self-hosted MinIO container in their prod Docker stack, instead of paying for AWS S3 (or any other managed provider).

**Outcome:** a single-instance MinIO service running alongside the app, NGINX-proxied at a public subdomain, backed by a persistent Docker volume, with a scoped app user (not root), admin port locked down, and a nightly backup strategy.

**Time:** ~45 minutes the first time.

**When to pick this over AWS S3:** self-hosted-everything philosophy, tight cost control (no AWS bill), data-residency or air-gap requirements, or operators already running MinIO elsewhere and preferring consistency. Trade: no managed edge CDN (layer Cloudflare or BunnyCDN in front if you need one), you own the uptime, and the backup story is yours to build.

---

## 0. Prerequisites

- A self-hosted Docker server (the same host running the bx-Blogger app + MySQL).
- A public DNS record pointing at that host (e.g., `media.blog.example.com`).
- TLS certificates for that subdomain — typically Let's Encrypt via certbot or acme.sh, or your existing cert management.
- A password manager (1Password, Bitwarden, Vault) — MinIO admin and app-user credentials should never live in plain files.
- The MinIO CLI client `mc` installed locally (Mac: `brew install minio/stable/mc`; Linux: download from <https://dl.min.io/client/mc/release/linux-amd64/mc>). Used for first-boot setup.

---

## 1. Compose service definition

Add to `docker-compose.prod.yml` (replaces the `minio: !reset null` line the default prod override ships with):

```yaml
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER:     ${MINIO_ROOT_USER}         # from prod secrets manager
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}     # from prod secrets manager
      MINIO_BROWSER_REDIRECT_URL: https://minio-console.blog.example.com  # only if you expose console via auth'd path; usually omit
    volumes:
      - minio-data:/data
    # NO ports: block — service is not reachable from outside the compose network.
    # S3 API port 9000 is reached via NGINX proxy (next step).
    # Admin console port 9001 is never publicly reachable (R35).
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    restart: unless-stopped

volumes:
  minio-data:
    name: bx-blogger-minio-prod
```

**Set `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` in prod `.env`** (values pulled from your secrets manager — never checked in):

```dotenv
MINIO_ROOT_USER=<long-random-string>
MINIO_ROOT_PASSWORD=<long-random-password>
```

The root user has full control over every bucket, every policy, and every setting in MinIO. It is analogous to AWS root. We only use it for the one-time bucket + app-user setup in §3, then never again.

---

## 2. NGINX vhost — public S3 API endpoint

The app talks to MinIO via the internal compose network (`http://minio:9000`). Public clients (browsers loading images) reach it through NGINX at `https://media.blog.example.com`.

Create `resources/docker/nginx/conf.d/media.conf`:

```nginx
server {
    listen 443 ssl http2;
    server_name media.blog.example.com;

    ssl_certificate     /etc/nginx/tls/media.blog.example.com.crt;
    ssl_certificate_key /etc/nginx/tls/media.blog.example.com.key;

    # HSTS (if you're confident in your TLS setup)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Allow large uploads — must match MEDIA_MAX_UPLOAD_MB in app config
    client_max_body_size 1000m;

    # MinIO S3 API proxy
    location / {
        proxy_pass         http://minio:9000;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # MinIO-specific tuning
        proxy_connect_timeout 300s;
        proxy_http_version    1.1;
        proxy_set_header      Connection "";
        chunked_transfer_encoding off;
    }

    # HARD BLOCK: admin console paths must never be proxied.
    # MinIO's console lives at /minio/* — 444 drops the connection without response.
    location /minio/      { return 444; }
    location /minio/ui/   { return 444; }
    location /login       { return 444; }
    location /api/v1/     { return 444; }

    # Bonus: block any request with query strings typical of the admin API
    if ($args ~* "(action=admin|api=admin)") { return 444; }
}

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name media.blog.example.com;
    return 301 https://$host$request_uri;
}
```

**Verify after `docker compose up -d`:**

```bash
# Should return 200 (MinIO health endpoint, public)
curl -I https://media.blog.example.com/minio/health/live
# Wait — this curls an admin-blocked path. Use the bucket-listing check instead:
curl -I https://media.blog.example.com/          # 403 or similar from MinIO (normal; no bucket named in URL)

# Should return 444 (connection dropped) — admin paths must be blocked
curl -I https://media.blog.example.com/minio/login
```

---

## 3. First-boot setup — create app user + buckets via `mc`

Do this **once** after the stack is up. Every step uses the MinIO CLI `mc` from your local machine (or a trusted admin jumpbox).

**Step 3a — configure `mc` alias pointing at your MinIO:**

```bash
mc alias set bxblog-prod https://media.blog.example.com "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
```

Verify:

```bash
mc admin info bxblog-prod
# Should show 1 online drive, version, uptime.
```

**Step 3b — create the buckets:**

```bash
mc mb bxblog-prod/bx-blogger-media-prod
mc mb bxblog-prod/bx-blogger-og-prod
mc mb bxblog-prod/bx-blogger-backups-prod        # optional: DB backup sync target
```

Set versioning on the primary media bucket (protects against accidental overwrites):

```bash
mc version enable bxblog-prod/bx-blogger-media-prod
```

**Step 3c — create a scoped app user (NOT root):**

```bash
# Generate a strong key pair — store these in your secrets manager
APP_ACCESS_KEY=$(openssl rand -hex 20)
APP_SECRET_KEY=$(openssl rand -base64 40)

mc admin user add bxblog-prod "$APP_ACCESS_KEY" "$APP_SECRET_KEY"
```

**Step 3d — create and attach a least-privilege policy for the app user:**

Save as `minio-app-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "MediaAndOgFullAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": [
        "arn:aws:s3:::bx-blogger-media-prod",
        "arn:aws:s3:::bx-blogger-media-prod/*",
        "arn:aws:s3:::bx-blogger-og-prod",
        "arn:aws:s3:::bx-blogger-og-prod/*"
      ]
    },
    {
      "Sid": "BackupBucketWriteOnly",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::bx-blogger-backups-prod",
        "arn:aws:s3:::bx-blogger-backups-prod/*"
      ]
    }
  ]
}
```

Attach it:

```bash
mc admin policy create bxblog-prod bx-blogger-app-policy minio-app-policy.json
mc admin policy attach bxblog-prod bx-blogger-app-policy --user "$APP_ACCESS_KEY"
```

The app user can now read/write/list the media + OG buckets and append-only to the backup bucket. It **cannot** create new buckets, change policies, or access any other bucket. Blast radius of a credential leak is scoped.

---

## 4. Wire the app

In prod `.env`:

```dotenv
# Object storage — self-hosted MinIO, reached through NGINX
S3_ENDPOINT=http://minio:9000                        # service-to-service inside compose
S3_REGION=us-east-1                                  # MinIO ignores but SDKs require a valid string
S3_BUCKET_MEDIA=bx-blogger-media-prod
S3_BUCKET_OG=bx-blogger-og-prod
S3_ACCESS_KEY=<APP_ACCESS_KEY from §3c>
S3_SECRET_KEY=<APP_SECRET_KEY from §3c>
S3_USE_PATH_STYLE=true                               # MinIO uses path-style
S3_PUBLIC_URL=https://media.blog.example.com         # how <img src> URLs are rendered (NGINX vhost)
S3_FORCE_HTTPS=true                                  # because S3_PUBLIC_URL is https

# Optional: off-host DB backup sync to this same MinIO
BACKUP_S3_BUCKET=bx-blogger-backups-prod
BACKUP_S3_ENDPOINT=                                  # empty = defaults to S3_ENDPOINT
```

Restart the app + worker: `docker compose restart app worker`. Upload a test image via the admin. It should land in `bx-blogger-media-prod` and render at `https://media.blog.example.com/bx-blogger-media-prod/…`.

---

## 5. Backup strategy

MinIO's own data lives in the `bx-blogger-minio-prod` named volume. Backup options:

**Option A — `mc mirror` to a second location** (simplest, recommended):

```bash
# Cron on the Docker host, nightly at 03:00
0 3 * * * mc mirror --overwrite bxblog-prod/bx-blogger-media-prod /mnt/backup-disk/minio-media-prod/
0 3 * * * mc mirror --overwrite bxblog-prod/bx-blogger-og-prod /mnt/backup-disk/minio-og-prod/
```

A separate physical disk is strongly recommended so a disk failure doesn't lose both live and backup.

**Option B — `mc mirror` to an off-host object store** (belt + suspenders):

```bash
# Mirror to Backblaze B2 or Cloudflare R2 nightly
mc alias set b2-backup https://s3.us-west-002.backblazeb2.com $B2_KEY_ID $B2_APPLICATION_KEY
mc mirror --overwrite bxblog-prod/bx-blogger-media-prod b2-backup/bx-blogger-backup-media/
```

Both off-host providers have very low storage costs ($0.005–$0.006/GB-month) and zero egress for restores.

**Option C — host-level volume snapshot** (ZFS, LVM, or VM snapshots): orthogonal to A/B, not a replacement. Operators who already have snapshot infrastructure use it in addition to `mc mirror`.

---

## 6. Upgrades

MinIO publishes frequent releases. The single-instance deployment upgrades with a two-command dance:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml pull minio
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d minio
```

Read the MinIO release notes before every upgrade — occasional breaking changes in admin API or config format. Pinning to a specific version (e.g., `minio/minio:RELEASE.2026-04-15T00-00-00Z`) instead of `latest` is recommended for prod to avoid surprise upgrades on restart.

---

## 7. Security checklist (tick before declaring setup complete)

- [ ] MinIO admin port (9001) has **no `ports:` mapping to the host** in `docker-compose.prod.yml`.
- [ ] NGINX vhost blocks `/minio/*` and related admin paths with `return 444`.
- [ ] `curl -I https://media.blog.example.com/minio/login` returns 444 (connection dropped), **not** 200.
- [ ] App `.env` uses a scoped app user (§3c), **not** `MINIO_ROOT_USER`.
- [ ] App-user's policy is scoped to the project's buckets only (§3d), no `*` on `Resource`.
- [ ] `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` are in the secrets manager, not in a plain `.env` checked into git.
- [ ] Root credentials are stored offline (password manager + printed copy in a safe); not needed for day-to-day operations.
- [ ] TLS cert for `media.blog.example.com` is valid, auto-renewing, and not using a self-signed cert in prod.
- [ ] `client_max_body_size` in NGINX matches the app's `MEDIA_MAX_UPLOAD_MB` setting (default 1000m).
- [ ] Nightly `mc mirror` cron is installed and tested (force one run, verify files land on the backup disk/bucket).
- [ ] MinIO image is pinned to a specific `RELEASE.YYYY-MM-DDTHH-MM-SSZ` tag in prod (not `latest`).
- [ ] `minio-data` volume has a known name (`bx-blogger-minio-prod`) — operators can `docker volume inspect` it for host-path and size.

---

## 8. Switching TO or FROM AWS S3 later

The app is endpoint-agnostic. Swapping AWS ↔ MinIO-in-prod is:

1. Data-migrate with `mc mirror` (from source alias to destination alias — works both directions).
2. Update the `.env` `S3_*` block (new endpoint, new region, new keys).
3. `docker compose restart app worker` — app now reads from the new backend.

No code changes, no downtime beyond the restart. Test the migration against a staging environment first; validate CloudFront URL patterns change if you're moving *to* AWS (dev `S3_PUBLIC_URL` differs from CloudFront distribution URL).

---

## 9. Known limitations vs. AWS S3 + CloudFront

- **No edge CDN by default.** All image requests terminate at your single NGINX. For small-to-medium traffic, this is fine. For high traffic, layer Cloudflare (free tier works great) or BunnyCDN in front of NGINX — point the CDN at `media.blog.example.com`, set `S3_PUBLIC_URL` to the CDN CNAME, done.
- **No CloudTrail-equivalent audit logging by default.** MinIO can emit audit events to a webhook or a Kafka topic (configured via `mc admin config set`) — set this up if you need compliance-grade audit. The app's own `audit_log` captures all media CRUD, so app-level is covered regardless.
- **No object-lock compliance mode by default.** MinIO supports it; enable per-bucket with `mc retention set`. Not needed for a standard blog.
- **Single-host risk.** Hardware failure on the Docker host = media offline. Mitigation: off-host backup via §5 Option B. For no-downtime resilience, distributed MinIO (4+ hosts, erasure-coded) is the upgrade path — out of scope for this runbook.

---

## 10. When you're done

Commit this file's reference from prod `.env`/`docker-compose.prod.yml` changes back to the repo (but **not** the credentials, obviously). Add a note to `DEV-NOTES/PLAN.md` §26 when this runbook is first exercised against a real production deployment, so we know the steps have been validated end-to-end.
