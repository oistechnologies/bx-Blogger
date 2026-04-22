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

The `cfengine: "boxlang@1"` entry in `server.json` tells CommandBox to install BoxLang on first server start — we do not need the `:boxlang`-tagged image variant. `server.json`'s `onServerInitialInstall` installs runtime-level BoxLang modules into the server home on first boot (`bx-compat-cfml`, `bx-esapi`, `bx-mysql`, `bx-mail`). Adding a new BoxLang runtime module there means **rebuilding the image** (`docker compose build app`) — `onServerInitialInstall` only fires once per fresh server home.

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

## BoxLang / ColdBox / qb / Quick gotchas (Phase 1 field notes)

Hard-won lessons from Chunks 1.E → 1.I. Read these before adding new handlers, services, or entities — they will save hours.

### BoxLang syntax

- **Classes use `class`, not `component`.** `class extends="coldbox.system.Interceptor" {}` compiles; `component extends=...` throws `'component' was unexpected` at parse time. Same for handlers, services, interceptors, entities.
- **Script-mode tags need the `bx:` prefix.** `<bx:savecontent>`, `<bx:include>`, `<bx:if>`, `<bx:output>`, etc. Plain `savecontent {}` inside a `<bx:script>` block is a parse error.
- **No mixed positional + named arguments in one call.** `foo( arg1, name = "x" )` → `cannot mix named and positional arguments`. All-positional or all-named.
- **`generateSecretKey("AES", 256)` returns base64, not hex.** For a 64-char hex token: `lCase( binaryEncode( binaryDecode( generateSecretKey("AES", 256), "base64" ), "hex" ) )`. Stripping non-hex chars off the raw base64 string discards most of the entropy (yielding a ~18-char token).

### Null handling

- **`javaCast("null", "")` assigned to a local, then referenced, throws `"key X not located"` in BoxLang.** Safer pattern: build a struct without the key, then conditionally add it:

  ```cfml
  var row = { a: 1, b: 2 };
  if ( !isNull( user ) ) row.user_id = user.getId();
  ```

- **Quick's `entity.setXxx( javaCast("null","") )` silently drops that column from the generated UPDATE.** Use qb for any column that must actually be cleared to NULL.
- **qb's `.update( struct )` rejects mixed bound + raw values.** `update({ a: 1, b: qb.raw("NULL"), c: 2 })` produces `Too many positional parameters [N] provided for query having only [M] '?' chars`. Split into separate updates, or use `queryExecute("UPDATE ... SET col = NULL WHERE ...", { ... })`.
- **Reusing the same qb instance across two updates accumulates bindings.** Call `wirebox.getInstance("QueryBuilder@qb").newQuery()` (or a `freshQb()` helper) for each statement. This bites when a service needs to run two separate UPDATEs in sequence.

### Quick ORM

- **`entity.save()` persists *every* field currently in memory.** If service code runs a qb update and then calls `entity.save()`, the save overwrites the qb-updated values with whatever the entity holds. Order operations so qb-only updates happen *after* any entity.save() calls, or reload the entity in between.
- **Don't call `.where( closure ).first()` on a Quick entity** with an unscoped inner where/orWhere chain — Quick tries to resolve it via its relation builder and can trigger an unrelated INSERT. Drop to qb for grouped where clauses: `qb.from("users").where( function( q ) { q.where(...).orWhere(...); } ).get()`.
- **`isNull( quickEntity )` is reliable; `quickEntity ?: "default"` can mis-behave** depending on loader state. When checking whether a `.first()` found a row, use `isNull( row )`.
- **Entity → table inference uses English singular→plural.** It's wrong for already-plural words (`Media` → `medias`) and for unusual pivots (`PostMeta` → `post_metas`). Pin explicitly via the class-level attribute: `class extends="quick.models.BaseEntity" accessors="true" table="media" {`. Don't use `this.table = "foo"` — Quick reads the metadata attribute, not the `this` scope.
- **Class-body ordering: `property` declarations must come before any `this.xxx = ...` assignment.** BoxLang throws `'property' was unexpected` if you put `this.table = "..."` at the top and then declare properties. Put all `property` lines first, then the `this.memento = {...}` and other `this.` assignments at the bottom.
- **Quick pluralizes JSON columns away.** If a JSON column holds `{...}` and you call `entity.getXxx()` you may get either a string or a pre-deserialized struct depending on whether Quick's column-caster fired. Wrap reads in a try/catch + `isStruct` check rather than blindly calling `deserializeJSON` on the result.

### ColdBox

- **Interceptor injection fails at boot.** Interceptors are instantiated before the full model scan completes; `property name="fooService" inject="FooService"` on an interceptor throws `Instance not found` during application startup. Use lazy `getInstance("FooService")` inside `preProcess`/`postProcess` methods instead.
- **Route ordering matters — specific before generic.** `route("/account/password")` must be declared before `route("/account")`, otherwise the parent swallows the more specific path.
- **`index.bxm` is a placeholder — never call `processColdBoxRequest()`** in it. `Application.bx`'s lifecycle hooks own the request; duplicating in `index.bxm` renders the page twice.
- **Flash scope in this app auto-purges after one render** (per `variables.flash.autoPurge = true` in `config/Coldbox.bx`). Curl-based test sequences must GET the page once to consume the flash before asserting the next flash is fresh.
- **HMVC module routes live in `modules_app/{name}/config/Router.bx`**, not in `routes = [...]` inside ModuleConfig. Declaring `routes` inside the module's `configure()` method is silently ignored by ColdBox — it looks for the Router.bx / Router.cfc file convention instead. Without a router, the module falls back to `:handler/:action?` conventions, which means bare `/{entryPoint}` (no sub-path) fails to resolve.
- **ModuleService auto-registers the entry-point route** via `addModuleRoutes(pattern=entryPoint, append=false)` — you don't need `route("/admin").moduleRouting("admin")` in the app router. Just set `this.entryPoint = "admin"` in ModuleConfig.bx and drop a `config/Router.bx` in the module.

### BoxLang + MySQL

- **`users.password_hash` is exactly `VARCHAR(60)` for bcrypt.** Test-fixture placeholder hashes must be exactly 60 chars or MySQL throws "Data too long for column".
- **`queryExecute` is available in any scope** and bypasses qb's binding logic entirely. Useful fallback for edge cases that trip up qb (mixed raw/bound updates, NULL assignment in a struct).

### CBWIRE

- **Single-file components need `@startWire` / `@endWire` markers** inside the `<bx:script>` block. Only code between those markers is treated as the component class; everything else (including `data = {...}` sitting outside) is discarded into "remaining template contents" and never runs. Result: `_getDataProperties()` returns empty and the template throws `key [...] not found`.
- **Template interpolation uses BoxLang syntax, not Livewire's mustache.** Write `<bx:output>#args.count#</bx:output>` (or `#variables.count#`), not `{{ count }}`. `{{ }}` renders as literal text. Data properties are exposed in `variables`, `variables.data`, and `variables.args` in the encapsulated render context.
- **CBWIRE compiles single-file components into a `modules/cbwire/views/tmp/` cache.** When you edit a wire's structure and nothing picks up, delete the matching tmp file(s) (`docker compose exec app rm -f /app/modules/cbwire/views/tmp/hello.*`). `fwreinit` alone doesn't invalidate this cache.
- **Every layout that renders a wire must call `#wireStyles()#` in `<head>` and `#wireScripts()#` before `</body>`.** Without these, the client runtime isn't loaded and `wire:click` / reactive updates silently no-op.
- **Wires always live in the app-root `wires/` folder** — even for components only used by an HMVC module. CBWire's `wire("name")` resolves against WireBox instance path `wires.name`; putting files under `modules_app/{module}/wires/` gives `Instance not found: 'wires.posts.list'`. Module-scoped component lookup is a Phase 11 problem, not Phase 2.
- **`<bx:/bx:if>` is not how you close a BX tag.** Use `</bx:if>`. BoxLang's parser emits `token recognition error at: '/'` which doesn't obviously point at the typo.
- **Module handler default action is `index`**, not whatever you name it. ColdBox's conventions route `:handler/:action?` resolves a bare `/admin/posts` to `admin:Posts.index`. Name the list-view action `index()`, not `list()`, or register an explicit route.

### Testing

- `tests/support/` is outside the runner's spec-glob — put `BaseIntegrationSpec` and other non-runnable base classes there, not under `tests/specs/`.
- Integration specs hit the real MySQL container. Always create throwaway users (UUID in the email) and clean them up in `afterAll()`; never mutate the dev admin seed (`id=1`).
- **Global BIFs from inside TestBox `it()` closures are unreliable.** Calling `serializeJSON(x)` from within `function() { ... }` passed to `it()` dispatches as a method on BaseSpec, which throws `The method serializeJSON does not exist.` Move BIF calls into a spec class method (declared outside any `it()`), or construct the value as a literal string, or wrap in try/catch. Same risk applies to other globals.
- **qb multi-alias select lists can collapse.** `.select( "roles.slug AS role_slug", "permissions.slug AS perm_slug" )` sometimes returns only the first alias. Fetch each table separately and join in-memory when the query is simple enough, or use `.selectRaw( "roles.slug AS role_slug, permissions.slug AS perm_slug" )`.
- **Don't hardcode "X permissions" / "Y rows" counts in assertions** — later phases add more. Use `toBeGTE` for minimums or query `count()` from the DB and compare to the entity's relation size.
