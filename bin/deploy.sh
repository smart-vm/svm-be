#!/usr/bin/env bash
# Runs ON the production droplet to deploy the latest main branch.
# Invoked by .github/workflows/deploy.yml over SSH after tests pass.
set -euo pipefail

APP_PATH="${DEPLOY_APP_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVICE_NAME="vending-erp-web"
# Public API + payment callbacks + background jobs, as its own service.
API_SERVICE_NAME="vending-erp-api"

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
if systemctl cat "$API_SERVICE_NAME" >/dev/null 2>&1; then
  echo "==> Restarting $API_SERVICE_NAME..."
  sudo systemctl restart "$API_SERVICE_NAME"
fi

echo "==> Verifying $SERVICE_NAME came back up..."
sleep 2
for service in "$SERVICE_NAME" "$API_SERVICE_NAME"; do
  systemctl cat "$service" >/dev/null 2>&1 || continue
  if systemctl is-active --quiet "$service"; then
    echo "==> $service is active."
  else
    echo "!!! Deploy FAILED: $service is not active after restart." >&2
    systemctl status "$service" --no-pager || true
    exit 1
  fi
done
echo "==> Deploy succeeded."
