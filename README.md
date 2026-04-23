# bx-Blogger

A self-hosted content management system for pages and a blog. Built on [BoxLang](https://boxlang.io) + [ColdBox 8](https://www.coldbox.org), runs in Docker, talks to MySQL, stores media on any S3-compatible backend (or a local disk), and ships as a single tagged container image.

bx-Blogger is for single-site operators — bloggers, small teams, publishers — who want full control over their stack without running a multi-tenant SaaS.

---

## What it does

### Writing + publishing

- **Markdown editor** with live server-rendered preview, autosave, and per-post revision history
- **Scheduled publishes** — set a future date/time, the platform flips the post live
- **Share-a-draft links** — signed 24h preview URLs for unpublished posts
- **Contributor → editor review workflow** — contributors write, editors publish
- **Per-post SEO fields** — override title, description, OG image, canonical, robots directive
- **Embedded media** from YouTube, Vimeo, Spotify, CodePen, Twitter/X, GitHub Gist — paste a URL on its own line, it auto-oEmbed expands

### Reading

- **Bootstrap 5 theme system** — swappable, extensible, schema-validated for compatibility
- **Always-on fallback theme** — a broken theme never leaves the site blank
- **Prism.js** per-language syntax highlighting, lazy-loaded
- **Full-text search** over published posts
- **RSS + Atom feeds** site-wide, per-category, per-tag, per-author
- **Category archives, tag archives, author archives, date archives** — all first-class

### SEO, social, operations

- **OpenGraph + Twitter Card + JSON-LD structured data** (Article, WebSite + SearchAction, BreadcrumbList, Person) — auto-populated per page type
- **Automatic share-card generation** — Java2D 1200×630 PNG rendered from the post title + author + site logo when no image is picked, cached by content version
- **XML sitemap** with automatic sitemap-index split at 40k published posts, per-year sub-sitemaps
- **Admin-editable `robots.txt`** driven by a settings row; handler injects the real `Sitemap:` line
- **301/302 redirects table** — slug changes on published posts auto-push the old URL into the redirects table with chain-collapse semantics; admin CRUD surface for manual entries
- **Broken-link tracker (404 report)** — admin can promote a frequently-hit 404 into a redirect with one click
- **Audit log** — filterable viewer covering logins, post lifecycle, and other admin actions, with CSV export for compliance

### Admin + security

- **CBWIRE** reactive admin UI with no heavy JavaScript framework
- **cbauth + cbsecurity** — login, logout, session management, firewall rules
- **bcrypt** passwords (cost factor 12), two-factor schema-ready
- **Email verification** on signup and on email change
- **Password-reset flow** with time-limited signed tokens
- **Rate-limited login** (5 attempts / 15 min per IP) with durable per-user lockout
- **Role-based permissions** (super_admin, admin, editor, author, contributor) with fine-grained permission slugs
- **CSRF protection** on forms
- **Input sanitization** via AntiSamy on all Markdown-rendered HTML

### GDPR + privacy

- **Export user data** — download a ZIP of everything the platform holds about a user (profile, posts, revisions, audit slice, media manifest)
- **Right-to-be-forgotten purge** — two-step admin confirm; reassigns authored posts to a sentinel "Deleted User" account, redacts audit IPs, hard-deletes orphan notifications and unreferenced media
- **Self-serve "Download my data"** on the user's account page

### Background jobs

- **cbq-powered** job queue with DB provider (no external queue dependency)
- **Built-in jobs:** send email, generate thumbnails + WebP variants, ping search engines on publish, record post views (off-thread), warm the page cache, prune old data, rebuild sitemap, backup the database, send notification digests
- **Scheduler** fires jobs on cron-like schedules; timezone-aware
- **Graceful handling of non-request threads** — jobs use `writeLog()` so they work correctly on worker threads where WireBox-injected loggers may not resolve

### Media + assets

- **Inline media library** picker in the editor — search, upload, reuse existing
- **Auto-generated thumbnails** + WebP variants on upload
- **Alt-text + focal-point** per image
- **Featured image + OG image fields** per post, with fallback chain (post → featured → first category → site default → generated share card)
- **Pluggable storage** via cbfs — local disk by default; switch to AWS S3, Cloudflare R2, DigitalOcean Spaces, Backblaze B2, Wasabi, or self-hosted MinIO via env vars alone (no code change)

### Performance + reliability

- **Full-page HTML cache** on public anonymous GETs, flushed on post / setting / theme / category mutations
- **60-minute cache** on sitemap, RSS feeds, and related-post lookups
- **Content-version–keyed cache** on generated OG images so updates don't serve stale art
- **Daily database backup job** with 14-day rotation; optional S3 off-host sync
- **Prune-old-data job** for login audits, page views, notifications
- **Nightly table-optimize** pass on high-churn tables

---

## Getting started

### Production deployment

See **[DEPLOY.md](DEPLOY.md)** — a 15-minute walkthrough from `git clone` to first admin login.

Running **multiple bx-Blogger sites on one Docker host**: see [docs/operators/MULTI-INSTANCE.md](docs/operators/MULTI-INSTANCE.md).

### Local development

```bash
git clone https://github.com/oistechnologies/bx-Blogger.git
cd bx-Blogger
cp .env.example .env
docker compose up -d
docker compose exec app box migrate up
open http://localhost:8080
```

The dev stack runs the app + MySQL + MinIO (local S3 emulator) + MailHog (captures outbound email at <http://localhost:8025>). Default admin: `admin@bx-blogger.local` / `ChangeMe-Admin-4242!`.

### Running tests

```bash
docker compose exec app box testbox run
```

---

## Configuration

Every runtime knob is in `.env` — `.env.example` is the exhaustive reference. Key areas:

| Section | Controls |
| --- | --- |
| **Identity** | `APP_KEY`, `APP_URL`, `APP_TIMEZONE`, `APPNAME` |
| **Database** | `DB_*` — host, port, database, username, password, driver |
| **Email** | `SMTP_*`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` |
| **Storage** | `S3_*` — endpoint, credentials, buckets, path-style override |
| **Reverse proxy** | `PROXY_NETWORK`, `TRUSTED_PROXIES` |
| **Admin seed** | `ADMIN_EMAIL`, `ADMIN_PASSWORD` — used on first boot when `users` is empty |
| **AI features** | `AI_ENABLED` + per-provider keys (opt-in, off by default) |

Settings that operators tune *after* deploy — robots.txt body, site default OG image, notification destination, etc. — live in the `settings` table and are managed via the admin UI rather than env vars.

---

## Themes

Themes ship as self-contained packs under `themes/`. Each declares a `theme.json` manifest with name, options, and supported templates. Three themes ship in the box:

- `bx-blogger-default` — the primary theme
- `bx-blogger-magazine` — alternate look
- `bx-blogger-fallback` — always-on safety net (never remove)

Writing a custom theme is a matter of copying an existing one, renaming, and editing the SCSS + `.bxm` layouts. The theme system extends Bootstrap 5 but never replaces it — your theme's CSS layers on top of the core bundle.

---

## Project layout

```text
bx-Blogger/
├── Application.bx               Web-root bootstrap
├── index.bxm                    Front-controller placeholder
├── config/                      Coldbox, WireBox, Cachebox, Router, Scheduler, cbq
├── handlers/                    Public-site ColdBox handlers
├── modules_app/admin/           Admin HMVC module
├── models/
│   ├── entities/                Quick ORM entities
│   ├── services/                Business-logic services
│   └── jobs/                    cbq background jobs
├── interceptors/                Cross-cutting request-lifecycle logic
├── views/                       Handler views (.bxm)
├── layouts/                     Top-level page layouts
├── themes/                      Theme packs
├── includes/helpers/            App-wide UDFs
├── resources/database/          Migrations + seeds
├── tests/specs/                 TestBox integration + unit specs
├── docker/                      Dockerfile + entrypoint
├── docker-compose.yml           Dev stack
├── docker-compose.prod.yml      Production stack (no ports published; reverse-proxy-fronted)
├── docs/                        Public operator + developer documentation
└── DEPLOY.md                    Production deployment guide
```

---

## Documentation

### For operators

- **[DEPLOY.md](DEPLOY.md)** — single-site production deploy
- **[docs/operators/NGINX-PROXY-MANAGER.md](docs/operators/NGINX-PROXY-MANAGER.md)** — NPM proxy-host setup, field-by-field
- **[docs/operators/MULTI-INSTANCE.md](docs/operators/MULTI-INSTANCE.md)** — multiple sites on one Docker host
- **[docs/operators/S3-BACKUP-SETUP.md](docs/operators/S3-BACKUP-SETUP.md)** — AWS S3 with bucket + IAM + CloudFront
- **[docs/operators/BACKBLAZE-B2.md](docs/operators/BACKBLAZE-B2.md)** — Backblaze B2 with scoped app keys + optional Cloudflare fronting
- **[docs/operators/S3-COMPATIBLE-PROVIDERS.md](docs/operators/S3-COMPATIBLE-PROVIDERS.md)** — env-var blocks for every supported S3 backend
- **[docs/operators/MINIO-SELF-HOSTED.md](docs/operators/MINIO-SELF-HOSTED.md)** — self-hosted MinIO as a prod S3 replacement

### For developers

- **[CLAUDE.md](CLAUDE.md)** — repo conventions, Docker-only workflow rules, BoxLang / ColdBox / Quick / qb gotchas collected during development

---

## Tech stack

- **Runtime:** BoxLang 1.12+ on the JVM
- **Framework:** ColdBox 8.1 (HMVC, interceptors, scheduler)
- **Admin UI:** CBWIRE (server-rendered reactive components)
- **ORM:** Quick entities + qb query builder
- **Migrations:** cfmigrations
- **Auth:** cbauth + cbsecurity
- **Validation:** cbvalidation
- **Jobs:** cbq with DB provider
- **Storage:** cbfs (local + S3-compatible)
- **Email:** cbmailservices
- **Testing:** TestBox
- **Database:** MySQL 8.4
- **Container:** Ortus Solutions' CommandBox Docker image
- **Reverse proxy:** NGINX Proxy Manager (reference) — any proxy that speaks HTTP 1.1 + websockets + `X-Forwarded-*` works

---

## License

See [LICENSE](LICENSE).

---

## Contributing

Issues and pull requests welcome at <https://github.com/oistechnologies/bx-Blogger>.

Before opening a PR, `docker compose exec app box testbox run` must be green on the full suite.
