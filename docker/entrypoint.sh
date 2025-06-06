#!/bin/bash
set -euo pipefail

# Obtain SSL certificate if not exists (for Fly.io domain)
DOMAIN="mlc-llm-app.fly.dev"
WEBROOT="/var/www/certbot"

mkdir -p $WEBROOT

echo "[INFO] Obtaining SSL cert for $DOMAIN if needed"
certbot certonly --webroot -w $WEBROOT -d $DOMAIN --non-interactive --agree-tos --email your-email@example.com || true

echo "[INFO] Starting Nginx"
nginx

echo "[INFO] Starting FastAPI server"
exec mlc_llm serve --host 0.0.0.0 --port 8000
