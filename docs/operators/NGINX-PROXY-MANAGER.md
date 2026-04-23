# Operator Runbook — Nginx Proxy Manager Integration

**Audience:** operators running an existing Nginx Proxy Manager (NPM) instance who are adding bx-Blogger behind it.

**Outcome:** public traffic hits NPM on 80/443, NPM terminates TLS and forwards to the bx-Blogger `app` container at `http://bx-blogger-app:8080` over a shared Docker network. Our compose stack ships no nginx service of its own.

**Time:** ~10 minutes once your domain DNS is already pointing at the NPM host.

> NPM project homepage: <https://nginxproxymanager.com>
>
> NPM dashboard is usually at `https://npm.your-host.tld:81` (default admin UI port).

---

## 0. Prerequisites

- A running NPM instance on the target Docker server. If you don't have one yet, NPM's [Quick Setup](https://nginxproxymanager.com/setup/) covers a 5-minute bring-up.
- NPM's Docker network name. Inspect it with:
  ```bash
  docker network ls | grep -i proxy
  # Or, if you know NPM's compose project name:
  docker inspect <npm-container-id> --format '{{range $k, $_ := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}'
  ```
  Typical defaults: `npm_default`, `proxy`, `nginxproxymanager_default`.
- A domain name with DNS pointing at the NPM host (e.g., `blog.example.com`).
- Admin credentials for the NPM web UI.

---

## 1. Tell bx-Blogger which Docker network NPM is on

In the production `.env` (the one that ships alongside `docker-compose.prod.yml` on the host):

```dotenv
PROXY_NETWORK=npm_default
```

Replace with whatever `docker network ls` reported in step 0. The `docker-compose.prod.yml` reads this variable at the `networks:` section — it attaches the `app` container to that shared network as an **external** network (meaning compose expects it to already exist, and only joins it).

No other networking config is required on our side. The `worker` and `mysql` services stay on the private `bx-blogger` network — they never need to be reachable from NPM.

---

## 2. Bring up the app stack

From the project directory on the prod host:

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

Verify the app is on the shared network:

```bash
docker network inspect npm_default | grep bx-blogger-app
# Should print a line with the container's IP on that network.
```

If this fails with "network npm_default not found," NPM isn't running on this Docker daemon or the network name is wrong — revisit step 0.

---

## 3. Add a proxy host in the NPM dashboard

1. Log into NPM at `https://npm.your-host.tld:81`.
2. **Hosts → Proxy Hosts → Add Proxy Host.**
3. Fill in the **Details** tab:

   | Field | Value |
   | --- | --- |
   | Domain Names | `blog.example.com` (+ `www.blog.example.com` if desired) |
   | Scheme | `http` |
   | Forward Hostname / IP | `bx-blogger-app` |
   | Forward Port | `8080` |
   | Cache Assets | off (Phase 5 handles app-level caching) |
   | Block Common Exploits | **on** |
   | Websockets Support | **on** (required for CBWire Livewire) |
   | Access List | Publicly Accessible (unless you're staging) |

4. **SSL** tab:

   | Field | Value |
   | --- | --- |
   | SSL Certificate | Request a new SSL Certificate with Let's Encrypt |
   | Force SSL | **on** |
   | HTTP/2 Support | **on** |
   | HSTS Enabled | **on** (once stable — gives browsers a 2-year no-HTTP guarantee) |
   | Email Address for Let's Encrypt | your ops email |
   | I Agree to the Let's Encrypt Terms of Service | check |

5. **Advanced** tab — paste the following so client IPs survive the proxy hop (PLAN §17 B15 TrustedProxy relies on these):

   ```nginx
   # Preserve real client IP + scheme for our TrustedProxyInterceptor
   proxy_set_header Host              $host;
   proxy_set_header X-Real-IP         $remote_addr;
   proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto $scheme;
   proxy_set_header X-Forwarded-Host  $host;

   # Match the app's MEDIA_MAX_UPLOAD_MB setting (Phase 2 adds media uploads)
   client_max_body_size 1000m;

   # Timeouts — tune up if you have slow-generating reports / exports
   proxy_connect_timeout 60s;
   proxy_read_timeout    300s;
   proxy_send_timeout    60s;
   ```

6. **Save.**

NPM immediately requests a certificate from Let's Encrypt (takes ~15 seconds), reloads its internal nginx, and starts routing.

---

## 4. Verify

From anywhere on the internet:

```bash
# HTTP should redirect to HTTPS
curl -I http://blog.example.com/__health
# → HTTP/1.1 301 Moved Permanently, Location: https://blog.example.com/__health

# HTTPS should return the app's health JSON
curl https://blog.example.com/__health
# → {"status":"ok","version":"0.1.0","phase":"0","timestamp":"..."}
```

On the host, verify client-IP propagation by tailing the app logs while hitting the domain:

```bash
docker compose -f docker-compose.prod.yml logs -f app | grep -i "X-Forwarded\|remote"
```

The app's `last_login_ip` / audit rows should now show the real visitor IP, not NPM's internal Docker IP (because our `TrustedProxyInterceptor` unwraps `X-Forwarded-For` when it sees NPM as the immediate hop — that's what the `TRUSTED_PROXIES` env var is for, per PLAN §17 B15).

---

## 5. Optional — additional hosts for MinIO-in-prod or admin split-domain

If you run **self-hosted MinIO in prod** (per [MINIO-SELF-HOSTED.md](MINIO-SELF-HOSTED.md)), add a second NPM proxy host for `media.your-domain.tld` pointing at the MinIO container's S3 API port:

| Field | Value |
| --- | --- |
| Domain Names | `media.blog.example.com` |
| Forward Hostname / IP | `bx-blogger-minio` |
| Forward Port | `9000` |
| Block Common Exploits | **on** |
| Websockets Support | off (not needed for S3 API) |

**Advanced tab (required for MinIO):**

```nginx
# Do NOT proxy MinIO's admin console paths
location /minio/    { return 444; }
location /minio/ui/ { return 444; }

# MinIO-specific tuning
chunked_transfer_encoding off;
proxy_http_version 1.1;
proxy_set_header Connection "";
client_max_body_size 1000m;
```

(The 444 return intentionally drops the connection — matches the R35 mitigation in PLAN §23.)

Some operators prefer a **split-domain admin pattern**: `blog.example.com` for public, `admin.blog.example.com` for the admin UI. In NPM that's a second proxy host with the same forward target (`bx-blogger-app:8080`) but only the admin domain on it, plus an Access List in NPM to IP-allowlist the admins.

---

## 6. Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `502 Bad Gateway` from NPM | NPM can't reach `bx-blogger-app:8080` over the shared network | `docker network inspect ${PROXY_NETWORK}` — confirm both `bx-blogger-app` and NPM's container are listed. If not, check `PROXY_NETWORK` in prod `.env` matches NPM's network name. |
| `Let's Encrypt` cert request fails | DNS not pointing at NPM host yet, or port 80 blocked | `dig blog.example.com` — should resolve to NPM host's public IP. Check firewall allows 80/443 inbound. |
| App logs show `last_login_ip` = `172.x.x.x` (Docker internal) | TrustedProxyInterceptor isn't trusting NPM's IP | Add NPM's docker-network CIDR (typically `172.16.0.0/12`) to `TRUSTED_PROXIES` in prod `.env`. Default is `127.0.0.1/32,172.16.0.0/12` which should cover it. |
| Websockets (CBWire) fail in production | Websockets Support toggle off in NPM proxy host | Edit proxy host → Details → turn Websockets Support **on** → Save. NPM reloads nginx instantly. |
| Cert renewal fails silently | NPM's renewal cron healthy? | NPM dashboard → SSL Certificates → check expiry dates. Manual renew via the certificate's "Renew" button. |

---

## 7. When changing the app domain

Edit the proxy host's Domain Names field in NPM → request a new cert on the SSL tab → save. No app restart required.

If you're also migrating the DNS to a new provider, first update DNS with a low TTL (300s) before swapping certs — lets the switchover cascade quickly.
