# Operator Runbook — AWS S3 Setup for bx-Blogger Production

**Audience:** operators provisioning a new production environment for bx-Blogger who have chosen AWS S3 + CloudFront as their object storage backend.
**Outcome:** a fully private S3 bucket for media storage, served publicly through CloudFront with Origin Access Control, with least-privilege IAM credentials, lifecycle rules, and audit logging in place.
**Time:** ~30–45 minutes the first time, ~10 minutes thereafter.

> **This is one of several supported prod backends.** The app's object-storage layer is endpoint-configurable — any S3-compatible provider works via a single `S3_ENDPOINT` env var. Alternatives:
> **Self-hosted MinIO** in the prod compose stack (no AWS bill, operator-owned data) — see [MINIO-SELF-HOSTED.md](MINIO-SELF-HOSTED.md).
> **Cloudflare R2 / DigitalOcean Spaces / Backblaze B2 / Wasabi** — see [S3-COMPATIBLE-PROVIDERS.md](S3-COMPATIBLE-PROVIDERS.md) for provider-specific env-var values.
> This runbook is the AWS-S3-specific walkthrough — the **recommended default** for managed simplicity and edge-caching integration (CloudFront). Operators landing here who want a different backend should start with the provider-agnostic reference above. This runbook is referenced by §22 Q2 of [PLAN.md](PLAN.md). Follow every step — the security posture depends on the combination, not any one setting.

---

## 0. Prerequisites

- AWS account with root access (one-time — we lock root away after setup).
- A payment method on file (bucket + CloudFront cost pennies/month for a small blog; no free-tier trap).
- `aws` CLI installed locally (`brew install awscli` on macOS).
- The application's production domain decided (e.g., `blog.example.com`) — needed for CORS and CloudFront.
- Decided on an AWS region. **Default: `us-east-1`** (required for certain CloudFront features like root-cert ACM certs). If your VPS is in Europe or APAC, pick the closest region and read §7.

---

## 1. Secure the root account (do this once per AWS account, not per project)

Skip if the account is already hardened.

1. **AWS Console → IAM → Security credentials** (top-right dropdown → *Security credentials*).
2. Enable **MFA on the root user**. Use a hardware key (YubiKey) if you own one; otherwise a TOTP app (1Password, Authy, Google Authenticator).
3. Delete any existing **root-user access keys**. The root account should never have programmatic keys.
4. **IAM → Users → Create user** → `ops-admin`:
   - Attach policy `AdministratorAccess` (scoped later if you grow a team).
   - Enable MFA on this user too.
   - Generate an access key pair; store in your password manager.
5. From now on, log in as `ops-admin`, not as root. Root stays for billing only.

**Why:** AWS root is unscoped, unrevokable, and single-owner. If those keys leak, the account is compromised. IAM users are revokable, auditable, scoped.

---

## 2. Create the S3 bucket

Use the CLI — faster and reproducible. Console instructions follow for reference.

**Naming rules:**

- Globally unique across *all* of AWS.
- Lowercase, 3–63 chars, no dots (dots break TLS cert validation in virtual-hosted-style URLs).
- Environment suffix so staging and prod never collide: `bx-blogger-media-prod`, `bx-blogger-media-staging`.

**CLI (recommended):**

```bash
# Set these once per session
export AWS_PROFILE=ops-admin
export AWS_REGION=us-east-1
export BUCKET=bx-blogger-media-prod

# Create the bucket
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$AWS_REGION" \
  $( [ "$AWS_REGION" != "us-east-1" ] && echo "--create-bucket-configuration LocationConstraint=$AWS_REGION" )

# Lock down public access (ALL FOUR flags ON — this is the single most important step)
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,\
IgnorePublicAcls=true,\
BlockPublicPolicy=true,\
RestrictPublicBuckets=true

# Disable ACLs entirely — bucket owner owns every object
aws s3api put-bucket-ownership-controls \
  --bucket "$BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

# Enable versioning (protects against accidental overwrites and deletes)
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

# Enable server-side encryption (SSE-S3 is free + automatic)
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" },
      "BucketKeyEnabled": true
    }]
  }'
```

**Verify:**

```bash
# Should print: PublicAccessBlockConfiguration with all four flags = true
aws s3api get-public-access-block --bucket "$BUCKET"

# Should print: Status: Enabled
aws s3api get-bucket-versioning --bucket "$BUCKET"

# Should print: SSEAlgorithm AES256
aws s3api get-bucket-encryption --bucket "$BUCKET"
```

**Console equivalent (for reference):**

1. S3 → *Create bucket* → name + region.
2. **Block all public access: ON** (all four sub-options checked). Acknowledge the warning.
3. *Bucket Versioning: Enable*.
4. *Default encryption: Server-side encryption with Amazon S3 managed keys (SSE-S3), Bucket Key: Enable*.
5. *Advanced: Object Ownership: ACLs disabled (Bucket owner enforced)*.

---

## 3. Create the least-privilege IAM policy

This policy is scoped to exactly this bucket. No wildcards. No cross-bucket access.

Save as `policy-bx-blogger-media-prod.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::bx-blogger-media-prod"
    },
    {
      "Sid": "ObjectOps",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::bx-blogger-media-prod/*"
    }
  ]
}
```

Create the policy:

```bash
aws iam create-policy \
  --policy-name bx-blogger-media-prod-rw \
  --description "Read/write access to bx-blogger-media-prod bucket only" \
  --policy-document file://policy-bx-blogger-media-prod.json
```

Capture the returned `Arn` — you need it for the next step.

**What's deliberately *not* in this policy:**

- `s3:PutObjectAcl` — ACLs are disabled at the bucket level (§2).
- `s3:*` wildcard — never; if a credential leaks we want blast radius small.
- `s3:DeleteBucket` / `PutBucketPolicy` — the app doesn't need to touch bucket config.
- Cross-bucket access — each environment has its own policy for its own bucket.

---

## 4. Create the application IAM user

**Do *not* reuse `ops-admin` for the app.** The app needs a machine user with only the one policy attached.

```bash
# Create the user
aws iam create-user --user-name bx-blogger-app-prod

# Attach the scoped policy (replace ARN with the one from §3)
aws iam attach-user-policy \
  --user-name bx-blogger-app-prod \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/bx-blogger-media-prod-rw

# Generate access keys (one pair — AWS allows max 2)
aws iam create-access-key --user-name bx-blogger-app-prod
```

The output is the **only time** AWS will show you `SecretAccessKey`. Store immediately in:

- **Prod secrets manager** (AWS Secrets Manager, HashiCorp Vault, 1Password Business, Doppler — your call).
- **Never** in git, never in `.env` that's checked in, never in plain config files.

Your application's prod `.env` will reference the secret by name (or pull it at boot via AWS SDK with IAM Role if the app runs on EC2/ECS/EKS — see §10 for the IAM Role upgrade path).

---

## 5. Configure CloudFront for public read access

The bucket stays private; CloudFront is the only thing that can read it.

### 5a. Create the distribution

```bash
# Create an Origin Access Control (OAC) — the modern replacement for OAI
aws cloudfront create-origin-access-control \
  --origin-access-control-config '{
    "Name": "bx-blogger-media-prod-oac",
    "Description": "OAC for bx-blogger-media-prod",
    "OriginAccessControlOriginType": "s3",
    "SigningBehavior": "always",
    "SigningProtocol": "sigv4"
  }'
```

Capture the returned OAC `Id`.

Then create the distribution via the console (the CLI JSON is unwieldy):

1. **CloudFront → Create distribution.**
2. **Origin domain:** pick your bucket from the dropdown (should show as `bx-blogger-media-prod.s3.<region>.amazonaws.com`).
3. **Origin access:** *Origin access control settings (recommended)* → select the OAC you just created.
4. **Viewer protocol policy:** *Redirect HTTP to HTTPS*.
5. **Allowed HTTP methods:** `GET, HEAD` (the app writes via direct S3 SDK, not CloudFront).
6. **Cache policy:** `CachingOptimized` (1 day default).
7. **Response headers policy:** `CORS-with-preflight-and-SecurityHeadersPolicy`.
8. **Price class:** `Use only North America and Europe` (cheapest that covers most blog traffic; bump to "all edge locations" only if you actually need APAC).
9. **Alternate domain names (CNAMEs):** `media.blog.example.com` (or skip, and use the `*.cloudfront.net` URL).
10. **Custom SSL certificate:** request one via ACM in `us-east-1` (CloudFront requires this region for certs), validate via DNS.
11. **Default root object:** leave blank.
12. Create distribution — takes ~10 minutes to deploy globally.

### 5b. Grant the distribution read access to the bucket

After the distribution is created, AWS shows a banner: "Update bucket policy to grant this distribution read access." Click **Copy policy**, then:

1. **S3 → your bucket → Permissions → Bucket policy → Edit → paste → Save.**

Or via CLI — save as `bucket-policy.json` (replace the two placeholders):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::bx-blogger-media-prod/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::<ACCOUNT_ID>:distribution/<DISTRIBUTION_ID>"
        }
      }
    }
  ]
}
```

```bash
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://bucket-policy.json
```

**Verify the combination:**

```bash
# Should 403 — bucket is locked down
curl -I "https://bx-blogger-media-prod.s3.$AWS_REGION.amazonaws.com/test.jpg"

# Should 200 once you upload test.jpg and CloudFront has cached it
curl -I "https://<DISTRIBUTION_ID>.cloudfront.net/test.jpg"
```

If the first curl returns 200, **stop and re-check §2 public-access-block settings**. If the second curl returns 403 after a fresh upload, the bucket policy didn't apply — recheck §5b.

---

## 6. Lifecycle rules

Save cost and reduce blast radius of a compromise.

```bash
cat > lifecycle.json <<'EOF'
{
  "Rules": [
    {
      "ID": "AbortIncompleteMultipartUploads",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    },
    {
      "ID": "ExpireOldVersions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 }
    },
    {
      "ID": "DeleteMarkerCleanup",
      "Status": "Enabled",
      "Filter": {},
      "Expiration": { "ExpiredObjectDeleteMarker": true }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" \
  --lifecycle-configuration file://lifecycle.json
```

**What this does:**

- Aborts orphaned multipart uploads after 7 days (you were billed for these; always clean them up).
- Deletes old object versions 30 days after they were replaced — versioning is a safety net, not unlimited history. Tune `NoncurrentDays` up to 90 if you want a longer rollback window.
- Cleans up dangling delete markers once the underlying versions are gone.

---

## 7. CORS (only if the browser needs direct access to S3 URLs)

**For MVP: skip CORS.** All media flows through CloudFront (which doesn't need CORS for `<img src>` tags), and uploads go through the server using SDK credentials.

**Add CORS later if:** you implement signed-URL direct-browser uploads (faster big-file uploads bypassing the app server) or JS needs to fetch JSON-ish metadata from CloudFront.

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedOrigins": [
      "https://blog.example.com",
      "https://www.blog.example.com"
    ],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

Applied via `aws s3api put-bucket-cors --bucket "$BUCKET" --cors-configuration file://cors.json`.

---

## 8. Enable audit logging (CloudTrail)

If CloudTrail isn't already on for your account:

1. **CloudTrail → Trails → Create trail** `bx-blogger-audit`.
2. **Storage location:** a *separate* bucket (e.g., `bx-blogger-cloudtrail-logs-prod`) with the same hardening as §2.
3. **Log file SSE-KMS:** enabled.
4. **Log file validation:** enabled (detects tampering).
5. **Events:** Management events (read + write) and Data events for the `bx-blogger-media-prod` bucket (both read + write). Data events cost extra — budget ~$0.10/10 000 events; leave write-only if read-event volume is high.

**Why:** if a key leaks, CloudTrail is how you find out *what* was accessed/changed and when. Without it, a compromise is invisible until the bill arrives.

---

## 9. Configure the application

Prod `.env` (pulled from secrets manager, never committed):

```bash
# cbfs S3 disk configuration (production)
CBFS_DISK_MEDIA_PROVIDER=S3Provider
CBFS_DISK_MEDIA_PROPERTIES_BUCKET=bx-blogger-media-prod
CBFS_DISK_MEDIA_PROPERTIES_REGION=us-east-1
CBFS_DISK_MEDIA_PROPERTIES_ACCESS_KEY=<from-step-4>
CBFS_DISK_MEDIA_PROPERTIES_SECRET_KEY=<from-step-4>
CBFS_DISK_MEDIA_PROPERTIES_PUBLIC_URL=https://media.blog.example.com
```

The `PUBLIC_URL` points at CloudFront, not S3 directly — that's how the app generates URLs for `<img src>` tags.

Exact variable names match §17 of [PLAN.md](PLAN.md); rename there if the mapping drifts.

---

## 10. Upgrade path: IAM Roles instead of access keys (later)

Access keys are fine for MVP on a VPS. But if you migrate to EC2, ECS, EKS, or Lambda:

1. Delete the access-key pair generated in §4.
2. Create an **IAM Role** with the same policy attached.
3. Attach the role to the compute resource (EC2 instance profile, ECS task role, etc.).
4. The AWS SDK picks up role credentials automatically — no `.env` secrets to rotate.

This eliminates the "key rotation" chore entirely and is the AWS-recommended pattern. Plan for this at the same time you outgrow the single-VPS deployment.

---

## 11. Key rotation schedule (while on access keys)

- **Every 90 days:** generate a new access-key pair, update prod `.env` / secrets manager, confirm the app still works, then delete the old key pair.
- **Immediately:** if a laptop with access keys is lost, or if access keys accidentally end up in a git commit (even a deleted branch — rotate), or if anyone who had access leaves the team.
- **Never:** share keys between environments. Staging has its own bucket + own IAM user + own keys.

```bash
# Rotate: create new key, then deactivate (not delete) the old one
aws iam create-access-key --user-name bx-blogger-app-prod
# ... update prod secrets with new key, deploy, verify ...
aws iam update-access-key --user-name bx-blogger-app-prod --access-key-id <OLD_KEY_ID> --status Inactive
# After 48 hours with no breakage:
aws iam delete-access-key --user-name bx-blogger-app-prod --access-key-id <OLD_KEY_ID>
```

---

## 12. Security checklist (final verification)

Before declaring the setup complete, confirm every row:

- [ ] Root account has MFA enabled and zero access keys.
- [ ] `ops-admin` IAM user has MFA enabled.
- [ ] Bucket has **all four** "Block public access" flags on.
- [ ] Bucket has **ACLs disabled** (BucketOwnerEnforced).
- [ ] Bucket has **versioning enabled**.
- [ ] Bucket has **default SSE-S3 encryption** enabled.
- [ ] IAM policy is scoped to exactly one bucket ARN (no wildcards).
- [ ] App IAM user has *only* the scoped policy attached (no `AdministratorAccess`, no `S3FullAccess`).
- [ ] Bucket policy allows `s3:GetObject` **only** to the specific CloudFront distribution ARN via `AWS:SourceArn` condition.
- [ ] `curl` against the `.s3.amazonaws.com` URL returns **403**.
- [ ] `curl` against the CloudFront URL returns **200** for a test object.
- [ ] Lifecycle rules are active (list them: `aws s3api get-bucket-lifecycle-configuration --bucket "$BUCKET"`).
- [ ] CloudTrail is logging management events and (ideally) data events for this bucket.
- [ ] Access keys are in a secrets manager, not in git, not in a plain-text file.
- [ ] Key rotation date is on the calendar (+90 days from today).
- [ ] A test object uploaded via the app renders correctly in production.

---

## 13. Cost expectations (small blog, ~10k monthly visitors)

- **S3 storage:** $0.023/GB-month → ~$0.25/mo for 10GB of media.
- **S3 requests:** $0.005/1 000 PUT + $0.0004/1 000 GET → pennies.
- **CloudFront egress:** $0.085/GB (NA/EU price class) → ~$0.85 for 10GB/mo of traffic.
- **CloudTrail:** $2.00/100k management events + $0.10/100k data events → $0–2/mo for a blog.
- **Realistic total:** $2–5/month. Shouldn't be a budget concern; do not skip any security step to save pennies.

---

## 14. Staging / additional environments

Repeat this runbook per environment, with one-letter substitutions:

- Bucket: `bx-blogger-media-staging`
- IAM user: `bx-blogger-app-staging`
- IAM policy: `bx-blogger-media-staging-rw`
- CloudFront: separate distribution, separate cert, separate OAC.

**Never** share a bucket or IAM user between prod and staging. The whole point of the separation is that a staging deploy can't accidentally scribble on or delete prod data.

---

## 15. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| App throws `AccessDenied` on PUT | IAM policy missing `s3:PutObject` or key is scoped to wrong bucket | §3 policy ARN check |
| CloudFront returns 403 for everything | Bucket policy missing CloudFront OAC rule | §5b — re-paste bucket policy |
| CloudFront returns 403 for new uploads only | Cache not yet populated (first request) or object uploaded with ACL that bucket ownership overrode | Wait 30s, or check SDK call doesn't set `ACL=public-read` (it shouldn't — see §2) |
| `aws s3 ls` works from local but app fails in prod | App has wrong keys, or keys are rotated but not redeployed | Verify prod secrets manager value matches current active key |
| Objects upload but are unretrievable via any URL | Object uploaded with `x-amz-server-side-encryption-customer-algorithm` (customer-managed key); app can't read its own uploads | Remove `SSECustomer*` headers from SDK calls; SSE-S3 (§2) handles encryption transparently |
| Versioning cost spiraling | App uploads replace same key repeatedly; old versions accumulate | §6 lifecycle rule should be cleaning up; verify `get-bucket-lifecycle-configuration` shows `ExpireOldVersions` active |

---

## 16. When you're done

Commit *this file* to the repo. Do **not** commit the rendered `policy-bx-blogger-media-prod.json`, `bucket-policy.json`, or any file containing account IDs or distribution IDs — treat account IDs as mildly sensitive (they enable recon for targeted attacks).

Add a line to `DEV-NOTES/PLAN.md` §26 when this runbook is first exercised against a real AWS account, so we know the steps have been validated end-to-end.
