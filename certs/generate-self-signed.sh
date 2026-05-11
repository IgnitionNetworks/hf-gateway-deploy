#!/usr/bin/env bash
# Generate a self-signed TLS certificate for Ignition HF Gateway.
# Output: certs/fullchain.pem  (certificate)
#         certs/privkey.pem    (private key)
#
# These are the paths nginx expects. Replace them with real certs when
# deploying to a production environment accessible from the internet.
# For a trusted certificate use scripts/letsencrypt-setup.sh instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAYS=3650

echo "Generating self-signed certificate (valid ${DAYS} days) ..."

openssl req -x509 -nodes -newkey rsa:4096 \
    -keyout "${SCRIPT_DIR}/privkey.pem" \
    -out    "${SCRIPT_DIR}/fullchain.pem" \
    -days   "${DAYS}" \
    -subj   "/CN=ignition-hf-gateway/O=Ignition Networks" \
    -addext "subjectAltName=IP:127.0.0.1"

chmod 644 "${SCRIPT_DIR}/privkey.pem"
chmod 644 "${SCRIPT_DIR}/fullchain.pem"

echo ""
echo "Certificate : ${SCRIPT_DIR}/fullchain.pem"
echo "Private key : ${SCRIPT_DIR}/privkey.pem"
echo ""
echo "Start nginx with:  docker compose up -d"
echo ""
echo "NOTE: Browsers will show a security warning for self-signed certificates."
echo "      Accept the warning once or add the certificate to your trust store."
echo "      For a publicly trusted certificate use:  scripts/letsencrypt-setup.sh"
