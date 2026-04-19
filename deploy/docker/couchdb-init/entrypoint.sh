#!/bin/bash
set -euo pipefail

# Run the upstream script first so baseline LiveSync config stays aligned.
# Upstream uses `username`/`password`; we keep `admin_username`/`admin_password`
# internally to distinguish from per-user creds in USERS. Translate for the call.
username="${admin_username:?}" password="${admin_password:?}" \
  bash /usr/local/bin/couchdb-init.sh

# Set up setup URI hostname for later use
if [[ -z "${SETUP_URI_HOSTNAME:-}" ]]; then
  export SETUP_URI_HOSTNAME="http://localhost:${SETUP_URI_PORT:-5984}"
fi

# Create users, their databases, and generate setup URIs.
# Format: USERS="user1:pass1:db1;user2:pass2:db2"
if [[ -n "${USERS:-}" ]]; then
  admin_url="${hostname:?}"
  admin_user="${admin_username:?}"
  admin_pass="${admin_password:?}"

  IFS=';' read -ra entries <<< "$USERS"
  for entry in "${entries[@]}"; do
    entry="$(echo "$entry" | xargs)"
    [[ -z "$entry" ]] && continue

    IFS=':' read -r u_name u_pass u_db <<< "$entry"
    if [[ -z "${u_name:-}" || -z "${u_pass:-}" || -z "${u_db:-}" ]]; then
      echo "WARNING: Skipping malformed USERS entry: $entry (expected user:pass:db)"
      continue
    fi

    user_created=false
    db_created=false

    # Create CouchDB user
    user_http_code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT \
      "${admin_url}/_users/org.couchdb.user:${u_name}" \
      --user "${admin_user}:${admin_pass}" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${u_name}\",\"password\":\"${u_pass}\",\"type\":\"user\",\"roles\":[]}" \
      2>/dev/null) || true
    if [[ "$user_http_code" == "201" ]]; then
      user_created=true
    fi

    # Create database
    db_http_code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT \
      "${admin_url}/${u_db}" \
      --user "${admin_user}:${admin_pass}" \
      2>/dev/null) || true
    if [[ "$db_http_code" == "201" ]]; then
      db_created=true
    fi

    # Lock database to this user only (admins always have access)
    curl -sS -X PUT "${admin_url}/${u_db}/_security" \
      --user "${admin_user}:${admin_pass}" \
      -H "Content-Type: application/json" \
      -d "{\"admins\":{\"names\":[],\"roles\":[]},\"members\":{\"names\":[\"${u_name}\"],\"roles\":[]}}" \
      >/dev/null 2>&1

    setup_uri_mode="${SETUP_URI:-true}"

    if [[ "$user_created" == "true" || "$db_created" == "true" ]]; then
      echo "-- Setting up user: ${u_name} with database: ${u_db} -->"
      if [[ "$setup_uri_mode" != "false" ]]; then
        SETUP_URI_USER="$u_name" \
        SETUP_URI_PASS="$u_pass" \
        SETUP_URI_DATABASE="$u_db" \
        node /opt/setupuri/generate-setupuri.mjs
      fi
      echo "<-- User ${u_name} setup complete!"
    elif [[ "$setup_uri_mode" == "always" ]]; then
      echo "User ${u_name} already exists with database ${u_db} (OK)"
      SETUP_URI_USER="$u_name" \
      SETUP_URI_PASS="$u_pass" \
      SETUP_URI_DATABASE="$u_db" \
      node /opt/setupuri/generate-setupuri.mjs
    else
      echo "User ${u_name} already exists with database ${u_db} (OK)"
    fi
  done
fi

# Optional JWT setup for CouchDB auth. No-op unless explicitly enabled.
if [[ "${JWT_ENABLED:-false}" != "true" ]]; then
  echo "INFO: JWT support disabled (set JWT_ENABLED=true to enable)"
  exit 0
fi

if [[ -z "${hostname:-}" || -z "${admin_username:-}" || -z "${admin_password:-}" ]]; then
  echo "ERROR: hostname/admin_username/admin_password must be set for JWT setup"
  exit 1
fi

node="${node:-_local}"
jwt_alg="${JWT_ALG:-hmac}"
jwt_kid="${JWT_KID:-_default}"
jwt_key="${JWT_KEY:-}"

if [[ -z "$jwt_key" ]]; then
  echo "ERROR: JWT_ENABLED=true requires JWT_KEY"
  exit 1
fi

if [[ "$jwt_alg" != "hmac" && "$jwt_alg" != "rsa" && "$jwt_alg" != "ec" ]]; then
  echo "ERROR: JWT_ALG must be one of: hmac, rsa, ec"
  exit 1
fi

echo "-- Configuring optional JWT auth... -->"

auth_handlers='{chttpd_auth, cookie_authentication_handler}, {chttpd_auth, jwt_authentication_handler}, {chttpd_auth, default_authentication_handler}'
until (curl -sS -X PUT "${hostname}/_node/${node}/_config/chttpd/authentication_handlers" -H "Content-Type: application/json" -d "\"${auth_handlers}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done

key_config_path="${jwt_alg}:${jwt_kid}"
until (curl -sS -X PUT "${hostname}/_node/${node}/_config/jwt_keys/${key_config_path}" -H "Content-Type: application/json" -d "\"${jwt_key}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done

if [[ -n "${JWT_USERNAME_CLAIM:-}" ]]; then
  until (curl -sS -X PUT "${hostname}/_node/${node}/_config/jwt_auth/username_claim_path" -H "Content-Type: application/json" -d "\"${JWT_USERNAME_CLAIM}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done
fi

if [[ -n "${JWT_ROLES_CLAIM:-}" ]]; then
  until (curl -sS -X PUT "${hostname}/_node/${node}/_config/jwt_auth/roles_claim_path" -H "Content-Type: application/json" -d "\"${JWT_ROLES_CLAIM}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done
fi

if [[ -n "${JWT_CLAIMS_REQUIRED:-}" ]]; then
  until (curl -sS -X PUT "${hostname}/_node/${node}/_config/jwt_auth/required_claims" -H "Content-Type: application/json" -d "\"${JWT_CLAIMS_REQUIRED}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done
fi

if [[ -n "${JWT_AUDIENCE_CHECK:-}" ]]; then
  until (curl -sS -X PUT "${hostname}/_node/${node}/_config/jwt_auth/audience" -H "Content-Type: application/json" -d "\"${JWT_AUDIENCE_CHECK}\"" --user "${admin_username}:${admin_password}"); do sleep 5; done
fi

echo "<-- Configuring optional JWT auth Done!"
