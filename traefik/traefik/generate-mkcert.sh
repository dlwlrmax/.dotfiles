#!/bin/bash
set -e

CERT_DIR="./traefik-config/certs"

# Create certs directory if it doesn't exist
mkdir -p "$CERT_DIR"

# List of domains from your original script
DOMAINS=(
	"langmaster.edu.test"
	"inertia.test"
	"erp.langmaster.test"
	"cafemom.test"
	"erp.hbr.test"
	"yusic.test"
	"fcm.langtech.test"
	"template.hbr.test"
	"careers.hbr.test"
	"careers.hbrholding.test"
	"langmaster.edu.test"
	"hbrbooks.test"
	"careers.langmaster.test"
	"careers.langgo.test"
	"binggo.edu.test"
	"portainer.test"
)

# Install mkcert CA if not already installed
if ! mkcert -CAROOT &>/dev/null; then
	echo "Installing mkcert CA..."
	mkcert -install
fi

# Generate certificates for each domain
for domain in "${DOMAINS[@]}"; do
	cert_file="$CERT_DIR/${domain}.pem"
	key_file="$CERT_DIR/${domain}-key.pem"

	echo "Checking for $cert_file and $key_file"
	if [ -f "$cert_file" ] && [ -f "$key_file" ]; then
		echo "Certificates for $domain already exist. Skipping."
		continue
	fi

	echo "Generating mkcert certificate for $domain..."
	
	# Generate certificate with mkcert
	mkcert -cert-file "$cert_file" -key-file "$key_file" "$domain" "*.$domain"

	if [ $? -eq 0 ]; then
		echo "Generated $cert_file and $key_file"
	else
		echo "Failed to generate for $domain"
	fi
done

echo "All mkcert certificates generated."
echo "Note: mkcert certificates are trusted by your local system!"