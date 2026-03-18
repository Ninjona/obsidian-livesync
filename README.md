# Obsidian LiveSync: Production Docker Stack

This repository provides a ready-to-deploy, production-oriented Docker stack for self-hosting [Obsidian LiveSync](https://github.com/vrtmrz/obsidian-livesync) with CouchDB, automated initialization, optional HTTPS, and scheduled backups.

## Features

- Prebuilt CouchDB image for LiveSync
- Automated, idempotent database initialization
- Optional JWT authentication
- Scheduled and on-demand database backups
- Interactive CLI restore for disaster recovery
- Optional HTTPS and domain proxying via Caddy (just uncomment in the stack file)
- Single, unified configuration: `docker-compose.yml`

## Quick Start

1. Copy and edit the environment file:

   ```bash
   cp .env.example .env
   # Edit .env and set strong secrets (COUCHDB_USER, COUCHDB_PASSWORD, ERLANG_COOKIE, etc)
   ```

2. Start the stack:

   ```bash
   docker compose -f docker-compose.yml up -d
   ```

   - CouchDB will be available at http://localhost:5984
   - Data is persisted in a Docker volume

3. (Optional) Enable HTTPS and domain proxying:

   - Edit `docker-compose.yml` and uncomment the `caddy` service section.
   - Set `DOMAIN` and `ACME_EMAIL` in your `.env` file.
   - Expose ports 80 and 443.

## Backups & Restore

- Backups are created automatically on a schedule and can be triggered on demand.
- Backup files are stored in the `backup-data` volume.
- To restore, run the interactive restore script inside the backup container:

  ```bash
  docker compose exec backup /usr/local/bin/restore.sh
  ```

  - The script will prompt you to select a backup and confirm before restoring.

## JWT Authentication (optional)

To enable JWT auth, set these in your `.env`:

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

## Security

- Never expose CouchDB (port 5984) directly to the internet without HTTPS.
- Use strong, random secrets for all credentials.
- Restrict access with firewall rules.

## Upstream Sync & CI

- The init script is auto-synced from upstream and committed to this repo.
- Docker images are built and published to Docker Hub via GitHub Actions.

## License

See [LICENSE](LICENSE).
