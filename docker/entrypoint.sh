#!/bin/bash
set -euo pipefail

CERTBOT_WEBROOT="/var/www/certbot"
DOMAIN="mlc-llm-app.fly.dev"
EMAIL="b4uharsha@gmail.com"  

function obtain_cert() {
  if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "[INFO] Obtaining SSL cert for $DOMAIN"
    certbot certonly --webroot -w "$CERTBOT_WEBROOT" -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL"
  else
    echo "[INFO] SSL cert already exists for $DOMAIN"
  fi
}

function renew_cert() {
  echo "[INFO] Renewing SSL certs if needed"
  certbot renew --webroot -w "$CERTBOT_WEBROOT" --non-interactive --quiet
}

obtain_cert || true

echo "[INFO] Starting Nginx"
nginx

# Run cert renewal loop in background
while true; do
  renew_cert
  sleep 43200  # 12 hours
done &

echo "[INFO] Starting FastAPI server"
exec mlc_llm serve --host 0.0.0.0 --port 8000
