#!/usr/bin/env bash
# Obtain a Let's Encrypt TLS certificate for Ignition HF Gateway.
#
# Prerequisites:
#   - Docker installed and running
#   - Port 80 reachable from the internet (for ACME HTTP-01 challenge)
#   - nginx container running:  docker compose up -d nginx
#   - DNS record for DOMAIN pointing to this server's public IP
#
# Usage:
#   bash scripts/letsencrypt-setup.sh <domain> [email]
#
# Example:
#   bash scripts/letsencrypt-setup.sh radio.example.com admin@example.com

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_DIR="${REPO_ROOT}/certs"
WEBROOT="${REPO_ROOT}/nginx/certbot-webroot"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <domain> [email]"
    echo "  domain — FQDN to obtain a certificate for (e.g. radio.example.com)"
    echo "  email  — contact address for expiry notices (recommended)"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-}"

if [[ -n "${EMAIL}" ]]; then
    EMAIL_ARGS=(--email "${EMAIL}" --no-eff-email)
else
    EMAIL_ARGS=(--register-unsafely-without-email)
fi

mkdir -p "${WEBROOT}" "${CERT_DIR}/letsencrypt"

echo "==> Let's Encrypt certificate request"
echo "    Domain  : ${DOMAIN}"
echo "    Webroot : ${WEBROOT}"
echo ""
echo "    nginx must be running and port 80 must be reachable from the internet."
echo "    The ACME challenge will be served at http://${DOMAIN}/.well-known/acme-challenge/"
echo ""
read -rp "Continue? [y/N] " yn
[[ "${yn}" =~ ^[Yy]$ ]] || exit 0

echo ""
echo "==> Requesting certificate via webroot challenge ..."
docker run --rm \
    -v "${WEBROOT}:/var/www/certbot" \
    -v "${CERT_DIR}/letsencrypt:/etc/letsencrypt" \
    certbot/certbot certonly \
        --webroot \
        --webroot-path /var/www/certbot \
        -d "${DOMAIN}" \
        "${EMAIL_ARGS[@]}" \
        --agree-tos \
        --non-interactive

LIVE="${CERT_DIR}/letsencrypt/live/${DOMAIN}"

echo ""
echo "==> Certificate obtained. Linking into certs/ ..."
ln -sf "${LIVE}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
ln -sf "${LIVE}/privkey.pem"   "${CERT_DIR}/privkey.pem"

echo ""
echo "==> Reloading nginx ..."
docker compose -f "${REPO_ROOT}/docker-compose.yml" exec nginx nginx -s reload

echo ""
echo "==> Done. Your site is now served over HTTPS with a trusted certificate."
echo ""
echo "==> Auto-renewal (add to root crontab with: sudo crontab -e)"
echo ""
echo "    0 3 * * * docker run --rm \\"
echo "        -v ${WEBROOT}:/var/www/certbot \\"
echo "        -v ${CERT_DIR}/letsencrypt:/etc/letsencrypt \\"
echo "        certbot/certbot renew --quiet && \\"
echo "        docker compose -f ${REPO_ROOT}/docker-compose.yml exec nginx nginx -s reload"
echo ""
