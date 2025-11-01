#!/bin/bash
set -e

CERT_DIR="./traefik-config/certs"

# List of domains from certs.yml
DOMAINS=(
    "erp.hbr.test"
    "erp.langmaster.test"
    "yusic.test"
    "fcm.langtech.test"
    "template.hbr.test"
    "hbr.edu.test"
)

for domain in "${DOMAINS[@]}"; do
    cert_file="$CERT_DIR/${domain}.pem"
    key_file="$CERT_DIR/${domain}-key.pem"

    echo "Checking for $cert_file and $key_file"
    if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
        echo "Certificates for $domain already exist. Skipping."
        continue
    fi

    echo "Generating self-signed certificate for $domain..."

    openssl req -x509 -newkey rsa:4096 -keyout "$key_file" -out "$cert_file" -days 365 -nodes -subj "/CN=$domain"

    if [ $? -eq 0 ]; then
        echo "Generated $cert_file and $key_file"
    else
        echo "Failed to generate for $domain"
    fi
done

echo "All certificates generated."