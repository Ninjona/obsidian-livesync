# Obsidian LiveSync Docker Images

This repository contains a minimal, production-oriented Docker setup for self-hosted Obsidian LiveSync infrastructure.

## Included

- `deploy/docker/couchdb`: Base CouchDB image
- `deploy/docker/couchdb-init`: Init image that runs upstream LiveSync CouchDB init script plus optional JWT configuration
- `deploy/docker/compose.yml`: CouchDB + init stack
- `deploy/docker/compose.caddy.yml`: CouchDB + init + Caddy HTTPS reverse proxy
- `.github/workflows/sync-upstream-couchdb-init.yml`: Auto-syncs upstream init script into this repo
- `.github/workflows/docker-images.yml`: Builds and publishes Docker images to GHCR when image inputs change

## Quick Start

```bash
cd deploy/docker
cp .env.example .env
docker compose -f compose.caddy.yml up -d --build
```

For all deployment options and configuration details, see `deploy/docker/README.md`.

## Upstream Sync Policy

`deploy/docker/couchdb-init/couchdb-init.sh` is synchronized from:

- `https://github.com/vrtmrz/obsidian-livesync`

The latest synced upstream details are recorded in `deploy/docker/couchdb-init/UPSTREAM.txt`.
