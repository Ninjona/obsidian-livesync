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
   - `couchdb-init` now prints a ready-to-import LiveSync Setup URI to container logs

   ```bash
   docker logs obsidian-livesync-couchdb-init
   ```

   Look for:
   - `SETUP_URI_PASSPHRASE=...`
   - `obsidian://setuplivesync?settings=...`

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

## Setup URI

The stack generates a Setup URI for each user defined in `USERS`. These are printed to `couchdb-init` container logs.

```dotenv
SETUP_URI_ENABLED=true
SETUP_URI_HOSTNAME=
SETUP_URI_PASSPHRASE=
USERS=obsidian:adminpass:obsidiannotes;alice:secret123:vault-alice
```

- Each user entry is `user:password:database`, separated by semicolons.
- Leave `SETUP_URI_PASSPHRASE` empty to auto-generate a fresh value.
- Leave `SETUP_URI_HOSTNAME` empty to auto-use `http://localhost:${COUCHDB_PORT}`.
- For remote clients, set `SETUP_URI_HOSTNAME` to your public HTTPS URL.
- Set `FORCE_SETUP_URI=true` to regenerate URIs for existing users on restart.

## Security

- Never expose CouchDB (port 5984) directly to the internet without HTTPS.
- Use strong, random secrets for all credentials.
- Restrict access with firewall rules.

## Upstream Sync & CI

- The init script is auto-synced from upstream and committed to this repo.
- Docker images are built and published to Docker Hub via GitHub Actions.

## License

See [LICENSE](LICENSE).
