# S3-Compatible Provider Reference

The bx-Blogger object-storage layer is endpoint-agnostic. Any S3-compatible provider works via the standard `S3_*` env-variable block. This doc lists the values for each supported provider, along with provider-specific quirks worth knowing before you pick one.

**For full setup walkthroughs,** see the provider-specific runbooks:

- AWS S3 (recommended default for prod): [S3-BACKUP-SETUP.md](S3-BACKUP-SETUP.md)
- Self-hosted MinIO in prod: [MINIO-SELF-HOSTED.md](MINIO-SELF-HOSTED.md)

This doc is the quick-reference for operators who already know what they're doing and just need the connection string.

---

## Common env-variable shape

Every provider uses the same seven variables. Only the values change.

```dotenv
S3_ENDPOINT=<provider-specific>
S3_REGION=<provider-specific>
S3_BUCKET_MEDIA=bx-blogger-media-<env>
S3_BUCKET_OG=bx-blogger-og-<env>
S3_ACCESS_KEY=<from provider console>
S3_SECRET_KEY=<from provider console>
S3_USE_PATH_STYLE=<true|false, provider-specific>
S3_PUBLIC_URL=<how <img src> renders, usually a CDN or custom domain>
S3_FORCE_HTTPS=<true|false>
```

---

## AWS S3 (default prod — see S3-BACKUP-SETUP.md)

```dotenv
S3_ENDPOINT=https://s3.us-east-1.amazonaws.com
S3_REGION=us-east-1
S3_USE_PATH_STYLE=false
S3_PUBLIC_URL=https://<cloudfront-distribution-id>.cloudfront.net   # or CNAME
S3_FORCE_HTTPS=true
```

**Quirks:**

- Pick a region close to your app's Docker host to minimize latency.
- CloudFront setup (per the AWS runbook) keeps the bucket fully private and serves via Origin Access Control. Without CloudFront, set `S3_PUBLIC_URL=https://<bucket>.s3.<region>.amazonaws.com` — but note the bucket must then allow public-read, which is less secure.
- Egress pricing is AWS's classic footgun. Budget ~$0.09/GB for US/EU outbound. Layer CloudFront for lower egress + edge caching.

---

## MinIO — dev compose container (default dev)

```dotenv
S3_ENDPOINT=http://minio:9000                        # service name in compose network
S3_REGION=us-east-1                                  # MinIO ignores value but SDK requires one
S3_ACCESS_KEY=minio                                  # = MINIO_ROOT_USER in compose
S3_SECRET_KEY=minio12345                             # = MINIO_ROOT_PASSWORD in compose
S3_USE_PATH_STYLE=true
S3_PUBLIC_URL=http://localhost:9000
S3_FORCE_HTTPS=false
```

**Quirks:**

- Dev root credentials are weak on purpose — they only live inside the compose network, never public.
- Buckets must exist before first use — `GenerateThumbnailsJob` will create the app-side structure but not the buckets themselves. Seed script `resources/database/seed-minio-buckets.sh` runs `mc mb` on first `docker compose up` via `docker-entrypoint.sh` (Phase 0 acceptance gate).

---

## MinIO — self-hosted in prod (see MINIO-SELF-HOSTED.md)

```dotenv
S3_ENDPOINT=http://minio:9000                        # service-to-service inside prod compose
S3_REGION=us-east-1
S3_USE_PATH_STYLE=true
S3_PUBLIC_URL=https://media.blog.example.com         # NGINX vhost
S3_FORCE_HTTPS=true
S3_ACCESS_KEY=<scoped-app-user-key from mc>
S3_SECRET_KEY=<scoped-app-user-secret from mc>
```

**Quirks:**

- Admin console port (9001) must **never** be publicly reachable (R35). Compose file ships with no `ports:` mapping; NGINX blocks `/minio/*` paths.
- App user must be a scoped user, not root. See runbook §3c.

---

## Cloudflare R2

R2 is Cloudflare's S3-compatible offering. Notable for **zero egress fees** — often the cost winner for high-traffic sites.

```dotenv
S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
S3_REGION=auto                                       # R2 uses "auto" — required value
S3_USE_PATH_STYLE=false
S3_PUBLIC_URL=https://media.blog.example.com         # R2 custom domain + CDN, configured in Cloudflare dashboard
S3_FORCE_HTTPS=true
```

**Quirks:**

- R2 has no regions in the AWS sense — `auto` is literally the required value.
- API tokens from Cloudflare dashboard: "R2 > Manage R2 API Tokens" → generate a token scoped to the specific bucket(s) and "Object Read & Write" permission.
- R2 does not support all S3 API features: **presigned POST** is not supported (presigned GET/PUT are). If a Phase 11 feature requires presigned POST (e.g., direct-browser multipart upload), R2 is not a fit for that feature.
- R2 custom domains are set up in the Cloudflare dashboard (R2 bucket > Settings > Custom Domains). The `S3_PUBLIC_URL` points at the custom domain; internal app traffic still uses the `.r2.cloudflarestorage.com` endpoint.
- Free tier includes 10 GB storage and 10M class-A + 1M class-B operations per month — covers most small-to-medium blogs entirely.

---

## DigitalOcean Spaces

DO's S3-compatible offering. Bundled with DO's managed compute if you're already on their platform.

```dotenv
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com      # or sfo3, ams3, sgp1, fra1, syd1
S3_REGION=nyc3                                       # use the same region code
S3_USE_PATH_STYLE=false
S3_PUBLIC_URL=https://<space-name>.<region>.cdn.digitaloceanspaces.com   # Spaces CDN enabled
S3_FORCE_HTTPS=true
```

**Quirks:**

- Minimum $5/month per Space (250 GB storage + 1 TB egress included). Under that, it's still $5. Over that, $0.02/GB storage / $0.01/GB egress.
- Spaces has an opt-in CDN (free) — toggle in DO dashboard. If CDN is enabled, `S3_PUBLIC_URL` becomes `<space>.<region>.cdn.digitaloceanspaces.com`. If not, it's `<space>.<region>.digitaloceanspaces.com`.
- Spaces API tokens are generated in DO dashboard > API > Spaces Keys. Unlike AWS IAM, Spaces tokens are not scopeable to individual Spaces — a leaked token has access to everything your DO account owns. Mitigation: a dedicated DO sub-account per project.

---

## Backblaze B2

Cheapest major provider by storage and egress. Popular for backups, increasingly for media too.

**Full setup runbook:** [BACKBLAZE-B2.md](BACKBLAZE-B2.md) — account setup, bucket creation, scoped application keys (media + backups split), optional Cloudflare CDN fronting, cost expectations, security checklist.

Quick-reference block:

```dotenv
S3_ENDPOINT=https://s3.us-west-002.backblazeb2.com   # region varies; check your bucket
S3_REGION=us-west-002
S3_USE_PATH_STYLE=false
S3_PUBLIC_URL=https://f002.backblazeb2.com/file/<bucket-name>   # native B2 URL; OR a Cloudflare-fronted custom domain
S3_FORCE_HTTPS=true
```

**Quirks:**

- Pricing: $0.006/GB-month storage, $0.01/GB egress (first 3× stored egress/month is free — very generous).
- The S3-compatible API is relatively new (2020+) and not 100% featureful — most things work, edge cases differ. Test your feature set against B2 before committing.
- Bandwidth alliance: B2 + Cloudflare = zero egress to the internet through Cloudflare CDN. Common high-traffic pattern.
- Application keys are generated in B2 dashboard > App Keys. Scopeable to individual buckets (unlike DO Spaces). Use a scoped key.
- Default B2 URLs (`f002.backblazeb2.com/file/...`) work but look ugly. For prod, layer Cloudflare or a custom CNAME + B2's "download-auth" if private.

---

## Wasabi

Very cheap, simple pricing. No tiers, no regions-as-currency.

```dotenv
S3_ENDPOINT=https://s3.us-east-1.wasabisys.com       # region-specific; us-east-1, us-west-1, eu-central-1, ap-northeast-1, etc.
S3_REGION=us-east-1
S3_USE_PATH_STYLE=false
S3_PUBLIC_URL=https://s3.us-east-1.wasabisys.com/<bucket>  # or CDN in front
S3_FORCE_HTTPS=true
```

**Quirks:**

- Pricing: $6.99/TB-month — flat, no egress fees, no API-request fees. Includes 1 TB egress/month; over that, still no charge until you hit 1× your stored data/month in egress, then same-as-storage pricing.
- **90-day minimum retention.** Files deleted or overwritten within 90 days of upload are still billed until the 90-day mark passes. If your CMS churns images heavily (delete + re-upload patterns), this can surprise you.
- No native CDN. Cloudflare / BunnyCDN are the standard frontends.
- IAM-style scoped keys available in Wasabi dashboard. Use them.

---

## Choosing between them — rough matrix

| Provider | Best for | Worst for | Typical monthly cost for 100GB blog |
|---|---|---|---|
| AWS S3 + CloudFront | Managed simplicity, integration w/ other AWS | Egress-heavy sites on a budget | $3–5 storage + CloudFront traffic ($0.085/GB) |
| MinIO self-hosted | Self-hosted everything, air-gapped, zero cloud bill | No in-house ops capacity | $0 (plus hosting) |
| Cloudflare R2 | High-egress blogs, Cloudflare-native | Presigned-POST-dependent flows (Phase 11) | $1.50 storage + $0 egress |
| DigitalOcean Spaces | Already on DO stack, integrated CDN | Large-scale (hard scope limits) | $5 flat |
| Backblaze B2 | Cost-sensitive, use w/ Cloudflare CDN | API-corner-case-sensitive workflows | $0.60 storage + $1 egress (free w/ CF) |
| Wasabi | Archival / low-churn | High-churn image workflows (90-day min) | $0.70 flat |

---

## Changing providers after launch

No code changes needed. Two-step migration:

1. **Mirror data** from old provider to new, using `mc` (which speaks every S3-compatible provider):

   ```bash
   mc alias set old-provider https://old.example.com $OLD_KEY $OLD_SECRET
   mc alias set new-provider https://new.example.com $NEW_KEY $NEW_SECRET
   mc mirror --overwrite old-provider/bx-blogger-media-prod new-provider/bx-blogger-media-prod
   ```

2. **Swap `.env` values** and restart:

   ```bash
   # Update S3_* block in prod .env with new provider's values
   docker compose restart app worker
   ```

Downtime is only the app restart (~10 seconds with healthcheck). Test against a staging bucket first — confirm image URLs still render, signed URL generation works, and the first upload/delete round-trip succeeds before cutting over.

For large datasets, `mc mirror --watch` keeps both in sync during the transition so the cutover is near-zero-delta.
