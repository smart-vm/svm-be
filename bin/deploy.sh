#!/usr/bin/env bash
# Runs ON the production droplet to deploy the latest main branch.
# Invoked by .github/workflows/deploy.yml over SSH after tests pass.
set -euo pipefail

APP_PATH="${DEPLOY_APP_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVICE_NAME="vending-erp-web"

# rbenv shims aren't guaranteed to be on PATH in a non-interactive SSH session.
export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH"

cd "$APP_PATH"

echo "==> Fetching latest code in $APP_PATH..."
git fetch origin
git reset --hard origin/main

echo "==> Loading production environment variables..."
set -a
source "$APP_PATH/.env.production"
set +a

echo "==> Installing gems..."
bundle install --without development test

echo "==> Running database migrations..."
RAILS_ENV=production bin/rails db:migrate

echo "==> Precompiling assets..."
RAILS_ENV=production bin/rails assets:precompile

echo "==> Restarting $SERVICE_NAME..."
sudo systemctl restart "$SERVICE_NAME"

echo "==> Verifying $SERVICE_NAME came back up..."
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "==> Deploy succeeded: $SERVICE_NAME is active."
else
  echo "!!! Deploy FAILED: $SERVICE_NAME is not active after restart." >&2
  systemctl status "$SERVICE_NAME" --no-pager || true
  exit 1
fi
