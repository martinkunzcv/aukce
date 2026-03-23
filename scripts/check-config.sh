#!/usr/bin/env bash
set -euo pipefail

required_files=(
  ".env.example"
  "docker-compose.yml"
  "oauth2-proxy/oauth2-proxy.cfg.example"
  "db/migrations/001_internal_auction_extensions.sql"
  "keycloak/README.md"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
  echo "OK $file"
done

if ! grep -q 'ended_pending_approval' db/migrations/001_internal_auction_extensions.sql; then
  echo 'Missing ended_pending_approval state in migration' >&2
  exit 1
fi

if ! grep -q 'oauth2-proxy' docker-compose.yml; then
  echo 'docker-compose.yml does not reference oauth2-proxy' >&2
  exit 1
fi

echo 'Configuration scaffold looks consistent.'
