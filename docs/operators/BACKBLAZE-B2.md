# Operator Runbook — Backblaze B2 for bx-Blogger

**Audience:** operators who want Backblaze B2 as their S3-compatible storage backend for media uploads, generated OG images, and/or off-host database backups.

**Why B2:**

- **Cost.** $6/TB-month storage, $10/TB egress — roughly a fifth of AWS S3 for the same workload.
- **Bandwidth Alliance.** B2 + Cloudflare = zero egress charges when traffic flows through Cloudflare's CDN. Common pattern for media-heavy blogs.
- **Free monthly egress allowance.** First 3× stored-data egress each month is free (so a 50 GB bucket gets 150 GB free monthly egress). Most blogs sit well under this.
- **No egress lock-in.** Unlike AWS's egress-to-internet pricing, no surprise bills from a traffic spike.

**Tradeoffs:**

- B2's S3-compatible API is newer (2020+) than AWS's and doesn't cover every AWS-specific edge case. The features bx-Blogger uses (PUT, GET, DELETE, HEAD, list objects, presigned URLs) all work; exotic S3 features aren't tested here.
- B2's default public URLs are ugly (`f002.backblazeb2.com/file/bucket-name/…`). For a polished site, put Cloudflare (or any CDN) in front with a custom domain. Section 6 covers this.
- If you need sub-second list-1000-objects latency against a 10M-object bucket, AWS S3 + CloudFront is still the benchmark. B2 is fine for typical blog scale (thousands to low-millions of files).

**Time:** ~20 minutes end-to-end. Most of it is B2 dashboard clicks.

---

## 0. Prerequisites

- A Backblaze account. Sign up at <https://www.backblaze.com/sign-up/cloud-storage>. The account is free to create; buckets are free until you upload something. No credit card required to create the account, but required before buckets become usable past the 10 GB free tier.
- **Two-factor auth enabled** on your Backblaze account. Go to **My Settings** → **Security** → enable 2FA. Do this before creating anything else — a compromised B2 root account is full-take of every bucket you own.
- **Email verified** on the account (Backblaze sends a link to the signup email).
- A password manager for the application keys you'll generate in §3 — they're shown **exactly once**.

---

## 1. What you'll end up with

Three buckets + two scoped application keys, specific to this bx-Blogger install:

```text
Bucket                        Purpose                Visibility
--------------------------    -------------------    ----------
bxblog-media-prod             Post featured images,  public  (or private + CDN-signed)
                              inline body images,
                              uploaded files
bxblog-og-prod                Generated 1200×630     public  (social embeds need public URLs)
                              OG share cards
bxblog-backups-prod           Nightly DB dumps       private (never served to the public)
                              + media sync

Application keys
----------------
media-app-key                 scoped to media + og buckets,    read+write
backups-app-key               scoped to backups bucket only,   read+write
```

Two keys instead of one is intentional: if the media key leaks (e.g., in a client-side mis-config), the attacker can't reach the backups. If the backups key leaks on the worker container, the attacker can't overwrite live media.

You can collapse to a single key on low-stakes installs — simpler ops, higher blast radius on compromise. Everything below supports both layouts.

---

## 2. Create the buckets

In the Backblaze web console:

1. Sign in at <https://secure.backblaze.com/user_signin.htm>.
2. Left sidebar → **Buckets** → **Create a Bucket**.

For **each** of the three buckets, fill in:

| Field | `bxblog-media-prod` | `bxblog-og-prod` | `bxblog-backups-prod` |
| --- | --- | --- | --- |
| Bucket Unique Name | `bxblog-media-prod` | `bxblog-og-prod` | `bxblog-backups-prod` |
| Files in Bucket are | **Public** | **Public** | **Private** |
| Default Encryption | Disable (unless regulatory need) | Disable | **Enable — SSE-B2** |
| Object Lock | Disable | Disable | Optional — Enable for compliance |

Notes:

- Bucket names are **globally unique across all of B2**. If `bxblog-media-prod` is taken, suffix with your domain: `bxblog-media-prod-example-com`. Keep the three names parallel so the `.env` stays tidy.
- **Public** on the media + OG buckets means the files are readable by anyone who knows the URL (which is exactly what a public blog needs). It does NOT mean bucket-listing is public. Object names (UUID-based in bx-Blogger) can't be guessed.
- **SSE-B2 encryption** on the backups bucket protects the DB dumps at rest. It's free; there's no reason to skip it.
- **Object Lock** on backups is optional — enables WORM semantics (a compromised admin can't delete old backups). If your security posture requires tamper-evident backups, enable Governance or Compliance mode. Most operators skip this for year one.

After creation you'll see each bucket's **Bucket ID** and **Endpoint**. You need the endpoint URL — it looks like `s3.us-west-004.backblazeb2.com` and the region segment varies. Copy it from any one bucket's details page (all three share the same endpoint because they were created in the same region).

---

## 3. Create scoped application keys

Left sidebar → **Application Keys** → **Add a New Application Key**.

### 3.1 The media key

| Field | Value |
| --- | --- |
| Name of Key | `bxblog-media-app` |
| Allow access to Bucket(s) | Select `bxblog-media-prod` **and** `bxblog-og-prod` (Ctrl/Cmd-click for multi-select) |
| Type of Access | **Read and Write** |
| Allow List All Bucket Names | off |
| File name prefix | leave blank |
| Duration | leave blank (non-expiring) |

Click **Create New Key**.

**The next screen shows the `keyID` and `applicationKey` exactly once.** Copy both into your password manager immediately. If you close the page without saving them, you have to delete the key and make a new one.

- `keyID` maps to bx-Blogger's `S3_ACCESS_KEY`
- `applicationKey` maps to bx-Blogger's `S3_SECRET_KEY`

### 3.2 The backups key

Repeat the above with:

| Field | Value |
| --- | --- |
| Name of Key | `bxblog-backups-app` |
| Allow access to Bucket(s) | `bxblog-backups-prod` only |
| Type of Access | **Read and Write** |
| everything else | same as above |

These become `BACKUP_S3_ACCESS_KEY` and `BACKUP_S3_SECRET_KEY` in `.env`.

> **Never use your Backblaze account's master application key** in the app. Master keys have unrestricted access to every bucket on your account and can never be scoped down. Always use narrowly-scoped application keys per workload.

---

## 4. Copy values into bx-Blogger `.env`

Edit your production `.env` (see [../../DEPLOY.md](../../DEPLOY.md) for the full env-var walkthrough; this section covers only the S3 block):

```dotenv
# -----------------------------------------------------------------------------
# Object storage — Backblaze B2
# -----------------------------------------------------------------------------
# Endpoint from the bucket detail page. Region segment (s3.us-west-004…)
# may differ for your account — substitute exactly what B2 shows.
S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
S3_REGION=us-west-004

# Credentials from §3.1 (media + og key).
S3_ACCESS_KEY=<keyID from §3.1>
S3_SECRET_KEY=<applicationKey from §3.1>

# Bucket names from §2.
S3_BUCKET_MEDIA=bxblog-media-prod
S3_BUCKET_OG=bxblog-og-prod

# B2 supports virtual-hosted-style S3 URLs (bucket.s3.endpoint/key), so
# path-style is not required. Keep this off unless a B2 API change reverts.
S3_USE_PATH_STYLE=false

# Public URL prefix — what gets written into <img src="…"> and meta og:image
# tags. Use the native B2 URL here until you layer Cloudflare (step 6), then
# swap in the Cloudflare-fronted custom domain.
S3_PUBLIC_URL=https://f004.backblazeb2.com/file/bxblog-media-prod

S3_FORCE_HTTPS=true

# -----------------------------------------------------------------------------
# Off-host database backup — separate bucket + separate scoped key
# -----------------------------------------------------------------------------
BACKUP_S3_BUCKET=bxblog-backups-prod
BACKUP_S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
BACKUP_S3_REGION=us-west-004
BACKUP_S3_ACCESS_KEY=<keyID from §3.2>
BACKUP_S3_SECRET_KEY=<applicationKey from §3.2>
```

**Region notes:**

- The region segment (`us-west-004`, `us-east-005`, etc.) MUST match the bucket's actual region. You can't move a bucket between regions after creation — you'd create a new bucket and migrate with `mc mirror`.
- The `f004` prefix in `S3_PUBLIC_URL` is specific to region `us-west-004`. For `us-east-005` it would be `f005`, etc. Match your bucket's region.

**The `S3_PUBLIC_URL` value points at the bucket-name path** (`/file/bxblog-media-prod`) because that's how B2 exposes public objects. Everything the app stores (`uploads/abc.jpg`) gets appended: final URL is `https://f004.backblazeb2.com/file/bxblog-media-prod/uploads/abc.jpg`.

---

## 5. Verify

Restart the stack to pick up the new `.env`:

```bash
docker compose -f docker-compose.prod.yml up -d
```

Exercise each surface:

### 5.1 Media upload → B2

Log into `/admin` → **Media** → upload a small image. Tail the app logs while clicking upload:

```bash
docker compose -f docker-compose.prod.yml logs -f app | grep -iE "cbfs|s3|media"
```

In B2's web console → **Browse Files** → open `bxblog-media-prod` → you should see `uploads/{year}/{month}/{uuid}.{ext}` land within a second of the upload.

### 5.2 Public URL serves the image

Grab the media row's `url` from the admin library, or construct it: `${S3_PUBLIC_URL}/uploads/.../your-file.jpg`. Hit it with curl:

```bash
curl -I https://f004.backblazeb2.com/file/bxblog-media-prod/uploads/...
# Expected: 200 OK, Content-Type: image/jpeg
```

If 403 → the bucket's visibility is Private, not Public (re-check §2). If 404 → the file didn't land where you expect — check `S3_PUBLIC_URL` points at the same bucket you configured in `S3_BUCKET_MEDIA`.

### 5.3 Generated OG card lands in the OG bucket

Publish a post without a featured image. Visit its public URL — the server generates a 1200×630 card and caches it in the `og` bucket. Verify in the B2 console that `bxblog-og-prod` has a new object `{postId}-v{contentVersion}.png`.

### 5.4 Nightly backup reaches the backups bucket

Force a backup on-demand:

```bash
docker compose -f docker-compose.prod.yml exec worker box task run BackupDatabaseJob
```

Watch the worker logs for `BackupDatabaseJob: S3 upload complete`. Then in B2's console, `bxblog-backups-prod` should show `bxblog-YYYYMMDD-HHMMSS.sql.gz`.

If the backup fails with "Invalid AccessKeyId," your `BACKUP_S3_*` credentials are the media key (scoped to media + og buckets only). Re-check §3.2's scope.

---

## 6. Optional — Cloudflare in front for free egress + a nice domain

B2 + Cloudflare is the canonical high-traffic pattern. Cloudflare participates in B2's Bandwidth Alliance — traffic that flows B2 → Cloudflare → user costs zero in B2 egress. Plus Cloudflare lets you replace `f004.backblazeb2.com/file/bxblog-media-prod/…` with `media.yourdomain.com/…`.

Rough shape:

1. **Add a CNAME** in Cloudflare for `media.yourdomain.com` pointing to your bucket's B2 public hostname (`f004.backblazeb2.com`). Proxy the record (orange cloud ☁️ ON).
2. **Configure Cloudflare's Page Rule** or **Transform Rule** to rewrite the path: `/(.*)` → `/file/bxblog-media-prod/$1`. This strips the `/file/bucket-name/` segment that B2 requires, giving you clean URLs.
3. **Point `S3_PUBLIC_URL`** at the new hostname:
   ```dotenv
   S3_PUBLIC_URL=https://media.yourdomain.com
   ```
4. **Optional — restrict B2 to Cloudflare only.** In Cloudflare, enable "Authenticated Origin Pulls" and configure B2 to accept only those requests. Skips direct-to-B2 hits that would bypass your WAF.

For the full Cloudflare + B2 walkthrough, B2's own docs are the source of truth: <https://www.backblaze.com/docs/cloud-storage-integrate-b2-with-cloudflare>.

---

## 7. Cost expectations

Realistic numbers for a typical blog:

| Workload | Storage | Monthly egress | B2 cost (no CDN) | B2 + Cloudflare cost |
| --- | --- | --- | --- | --- |
| Small blog (10 GB, 50 GB traffic) | $0.06 | free (within 3× stored) | ~$0.06 | ~$0.06 |
| Medium blog (100 GB, 500 GB traffic) | $0.60 | $2 (after 300 GB free) | ~$2.60 | ~$0.60 |
| Large blog (1 TB, 5 TB traffic) | $6 | $20 (after 3 TB free) | ~$26 | ~$6 |

Add ~$0.004 per 10,000 class-B transactions (uploads/downloads/etc.) — rounding-error territory for a blog.

Backblaze bills monthly. You can set a spend alert in the B2 dashboard (**My Settings** → **Caps & Alerts**) to get an email at a threshold.

---

## 8. Switching to B2 from another provider (AWS, R2, etc.)

Zero-downtime migration. The `mc` tool (from MinIO — works as a client for any S3-compatible backend) handles it:

```bash
# Install mc if you don't have it already
brew install minio/stable/mc         # macOS
# Or download from https://min.io/download

# Configure both providers
mc alias set old-aws    https://s3.amazonaws.com         $OLD_AWS_KEY $OLD_AWS_SECRET
mc alias set new-b2     https://s3.us-west-004.backblazeb2.com $NEW_B2_KEY $NEW_B2_SECRET

# Mirror each bucket (takes minutes to hours depending on bucket size)
mc mirror --overwrite old-aws/bx-blogger-media-prod   new-b2/bxblog-media-prod
mc mirror --overwrite old-aws/bx-blogger-og-prod      new-b2/bxblog-og-prod

# Optionally mirror the backups bucket too if you want historical backups preserved
mc mirror --overwrite old-aws/bx-blogger-backups-prod new-b2/bxblog-backups-prod
```

Then swap the `S3_*` + `BACKUP_S3_*` values in `.env` per §4 and restart. The next request references the new backend; old objects still resolve at the new URLs. Run one more `mc mirror` right after the cutover to catch anything uploaded during the swap, then delete the old bucket at your leisure.

---

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Upload works but 403 on the public URL | Bucket is Private, not Public | Edit bucket in B2 console → change to Public (or front with Cloudflare + signed URLs) |
| `InvalidAccessKeyId` in app logs | Wrong key, or key scoped to wrong bucket | Re-check §3 — each key has a specific bucket list; `BACKUP_S3_*` key must include the backups bucket |
| `SignatureDoesNotMatch` | Region mismatch between `S3_ENDPOINT` and `S3_REGION` | Both must match the bucket's actual region. Copy the endpoint URL fresh from B2's bucket details page |
| `BucketAlreadyExists` when creating a bucket | Bucket names are globally unique across B2 | Pick a more specific name (suffix with your domain) |
| OG images don't appear in social previews | `S3_PUBLIC_URL` wrong, or bucket still Private | Curl the computed og:image URL directly; if 403 → bucket visibility; if 404 → URL mismatch |
| Monthly bill surprise | Egress spike without CDN in front | Add Cloudflare (§6) — B2 + Cloudflare = zero egress |
| `mc mirror` fails with "host not reachable" | Endpoint URL typo | `mc admin info b2` shows what mc resolved — compare against B2 console's endpoint |
| B2 dashboard shows "key used N times/day" but app logs errors | Rate-limit on the free tier? | B2 has generous rate limits (thousands of requests/second); this is almost always app-side. Check app logs for the real error |

---

## 10. Security checklist

- [ ] 2FA enabled on the Backblaze root account
- [ ] Master application key never used by the app (scoped keys only)
- [ ] Media + OG buckets Public (expected) — backups bucket Private (critical)
- [ ] Backups bucket has SSE-B2 encryption enabled
- [ ] `.env` containing the application keys is NOT committed (check `.gitignore`)
- [ ] `S3_PUBLIC_URL` uses HTTPS (not HTTP)
- [ ] Caps & Alerts configured in the B2 dashboard to catch runaway costs
- [ ] Application keys rotated annually (make new key → update `.env` → delete old key; <5 min downtime)
- [ ] If using Cloudflare in front: "Authenticated Origin Pulls" enabled so bucket URL can't be hit directly
- [ ] Object Lock enabled on backups bucket if compliance requires tamper-evident backups

---

## 11. See also

- [S3-COMPATIBLE-PROVIDERS.md](S3-COMPATIBLE-PROVIDERS.md) — other S3-compatible backends + when to pick each
- [S3-BACKUP-SETUP.md](S3-BACKUP-SETUP.md) — the AWS S3 equivalent of this runbook (IAM + CloudFront)
- [MINIO-SELF-HOSTED.md](MINIO-SELF-HOSTED.md) — self-host your own S3-compatible server
- [../../DEPLOY.md](../../DEPLOY.md) — how the `.env` values here plug into a full deploy
