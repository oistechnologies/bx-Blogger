# bx-Blogger

A self-hosted content management system for pages and a blog, built on [BoxLang](https://boxlang.io) and [ColdBox 8](https://www.coldbox.org).

## Status

**Pre-development — planning phase.** No runnable code yet. Detailed architectural design has been worked through; implementation starts at Phase 0 (template scaffold + Docker stack + smoke test). Watch the repo to follow along.

## What it is

bx-Blogger is a production-quality CMS you run yourself. The goals:

- Ship a real, modern blog platform on BoxLang and ColdBox 8.
- Authors write in Markdown in a clean web editor; readers see fast, syntax-highlighted, SEO-friendly pages.
- Designers drop in new themes without touching application code.
- Operators deploy locally with a single `docker compose up` and in production with a tagged container image.

It is not trying to be WordPress, Ghost, or a multi-tenant SaaS. It is aimed at single-site operators — bloggers, small teams, publishers — who want control over their own stack.

## Who it's for

- Developers who want a CMS they can run, read, modify, and extend in BoxLang.
- Writers who prefer Markdown to visual page builders.
- Solo authors and small editorial teams publishing long-form content.
- The BoxLang and ColdBox community — this is a proof point for the ecosystem on a non-trivial application.

## Planned architecture

### Runtime and framework

- **BoxLang 1.6+** (JVM, native)
- **ColdBox 8.1** (HMVC, interceptors, scheduler)
- **CommandBox 6+** with the BoxLang MiniServer for local development
- **MySQL 8** for persistence

### Domain layer

- **Quick ORM** for entities (User, Post, Page, Category, Tag, Comment, Media, Setting, AuditLog)
- **qb** query builder for ad-hoc queries
- **cfmigrations** for schema evolution

### Admin UI

- **CBWIRE** — server-rendered reactive components, no heavy JavaScript framework in the admin
- **EasyMDE** Markdown editor with live preview rendered on the server
- **cbauth** + **cbsecurity** for authentication and authorization
- **cbvalidation** for input validation
- **bcrypt** for password hashing, two-factor auth schema-ready from Phase 1

### Public site

- Swappable theme system — themes extend Bootstrap 5 but never replace it, and are schema-validated for compatibility
- A lightweight always-on fallback theme so a broken theme never leaves the site blank
- Prism.js for lazy-loaded, per-language code highlighting
- SEO built in — Open Graph, Twitter Cards, JSON-LD structured data, XML sitemap, RSS and Atom feeds
- MySQL FULLTEXT search at MVP, with a swap seam for Elasticsearch later

### Media

- **cbfs** file abstraction — MinIO in dev for parity, S3 in production
- Production bucket is fully private; public reads served through CloudFront with Origin Access Control, never directly from S3
- Auto-generated thumbnails, WebP variants, and Open Graph share cards per post

### Deployment

- **Docker-first.** `docker compose up` spins a full local stack: app, MySQL, MinIO, Mailpit.
- Production image tagged in CI, deployable to any VPS or container platform. NGINX is the reverse-proxy default; Caddy and Apache configs ship as alternatives.
- Schema migrations run automatically on container start.

### Extension points

Designed for MVP, reserved for later phases:

- **`MediaService`** — image backend is swappable (bx-image today, Thumbnailator via cbjavaloader later).
- **`ISearchProvider`** — MySQL FULLTEXT today, Elasticsearch later.
- **`Authenticator`** strategy — form login today, OAuth / Google / Microsoft / GitHub SSO later.
- Interception points for comments, newsletters, passkeys, and real-time features are named up front so the roadmap work doesn't require core rewrites.

## Principles

- **Production-quality, not demoware.** Backups, rate limiting, CSP, accessibility, observability — all MVP concerns, not afterthoughts.
- **Self-hostable on one box.** A single-VPS deployment is a first-class target, alongside container platforms.
- **Swappable, not monolithic.** Every third-party dependency the app leans on (ORM, image backend, search, storage, auth) sits behind an interface with a documented fallback.
- **Themes extend Bootstrap, they do not replace it.** This constraint is mechanically enforced by theme schema validation, not by convention.

## Roadmap

MVP is broken into phases. High-level:

- **Phase 0** — Bootstrap: template scaffold, Vite, Docker Compose stack, smoke test
- **Phase 1** — Identity and authentication
- **Phase 2** — Posts and pages CRUD, media management, editorial workflow
- **Phase 3** — Public site v1 with the fallback and default themes
- **Phase 4** — Theming system and theme options UI
- **Phase 5** — Caching and performance
- **Phase 6** — Background jobs, scheduling, notifications
- **Phase 7** — SEO polish and Open Graph image generation
- **Phase 8** — Audit log and admin tooling
- **Phases 9–10** — Hardening, accessibility, operator documentation
- **Phase 11** — Roadmap: SSO, passkeys, Elasticsearch, comments, newsletter, editorial calendar

## License

TBD — no `LICENSE` file ships until decided.

## Contributing

Contribution guidelines will be published once Phase 0 is complete and there is runnable code to build against. Until then, watch or star the repo to follow progress.
