# Docker deployment for Self-hosted LiveSync

This directory contains a production-ready CouchDB container setup for [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync).

## What this gives you

- A pinned CouchDB image.
- A one-shot init container that runs the upstream LiveSync `couchdb-init.sh` logic.
- Optional JWT auth setup when explicitly enabled in `.env`.
- Persistent data via named Docker volume.
- Healthcheck for basic availability.
- Simple `.env`-driven setup.

## Quick start

```bash
cd deploy/docker
cp .env.example .env
# Edit .env and set strong secrets
docker compose up -d --build
```

When it is up, CouchDB will be reachable at:

```text
http://<your-server-ip>:5984
```

## HTTPS with Caddy (recommended for internet exposure)

Use this if you have a domain already pointing at your server.

```bash
cd deploy/docker
cp .env.example .env
# Set COUCHDB_USER, COUCHDB_PASSWORD, ERLANG_COOKIE, DOMAIN, ACME_EMAIL
docker compose -f compose.caddy.yml up -d --build
```

Your LiveSync endpoint will be:

```text
https://<your-domain>
```

Notes:
- Ports `80` and `443` must be reachable from the internet for ACME certificate issuance.
- CouchDB is not exposed directly in this mode; only Caddy is public.

## How init works

- `couchdb` starts first.
- `couchdb-init` waits for CouchDB health and applies all REST config from `deploy/docker/couchdb-init/couchdb-init.sh`.
- If `JWT_ENABLED=true`, the init entrypoint also configures CouchDB JWT auth after the upstream script completes.
- In Caddy mode, `caddy` waits for `couchdb-init` to finish successfully.

The init script is idempotent, so reruns are safe.

## Optional JWT configuration

Set these in `.env` only if you want JWT enabled:

```dotenv
JWT_ENABLED=true
JWT_ALG=hmac
JWT_KID=_default
JWT_KEY=<shared-secret-or-public-key>
JWT_USERNAME_CLAIM=sub
JWT_ROLES_CLAIM=roles
JWT_CLAIMS_REQUIRED=exp,iat
JWT_AUDIENCE_CHECK=obsidian-livesync
```

Notes:
- `JWT_KEY` is required when `JWT_ENABLED=true`.
- `JWT_ALG` supports `hmac`, `rsa`, or `ec`.
- Leave JWT vars empty to keep cookie/basic auth only.

## Security notes

- Do not expose port `5984` directly to the internet without TLS.
- Prefer placing this service behind a reverse proxy (Traefik, Caddy, Nginx) with HTTPS.
- Keep `COUCHDB_PASSWORD` and `ERLANG_COOKIE` long and random.
- Restrict inbound access with firewall rules.

## Verify service

```bash
curl -u "$COUCHDB_USER:$COUCHDB_PASSWORD" http://127.0.0.1:5984/_up
```

Expected response:

```json
{"status":"ok"}
```

## Optional: publish your own image

If you want to run this on multiple hosts, build and push to your own registry:

```bash
docker build -t ghcr.io/<your-user>/obsidian-livesync-couchdb:latest ./couchdb
docker push ghcr.io/<your-user>/obsidian-livesync-couchdb:latest
```

Then replace `build:` in `compose.yml` with:

```yaml
image: ghcr.io/<your-user>/obsidian-livesync-couchdb:latest
```

You should also publish and reference the init image:

```bash
docker build -t ghcr.io/<your-user>/obsidian-livesync-couchdb-init:latest ./couchdb-init
docker push ghcr.io/<your-user>/obsidian-livesync-couchdb-init:latest
```

## Auto-sync from upstream and rebuild

This repo includes two workflows:

- `.github/workflows/sync-upstream-couchdb-init.yml`
  - Runs every 6 hours.
  - Downloads upstream `utils/couchdb/couchdb-init.sh`.
  - If changed, commits the new version to `deploy/docker/couchdb-init/couchdb-init.sh`.
- `.github/workflows/docker-images.yml`
  - Runs on pushes to `main` that touch `deploy/docker/**`.
  - Builds and publishes:
    - `ghcr.io/<owner>/obsidian-livesync-couchdb`
    - `ghcr.io/<owner>/obsidian-livesync-couchdb-init`

If upstream disappears, your last synced script remains in this repo and deployments keep working with that last known-good version.
