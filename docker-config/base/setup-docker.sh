#!/bin/bash
set -e

# Capture the directory where the script is run
ORIGINAL_PWD=$(pwd)

# Change to the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
echo "Script directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR"
echo "Now running in: $(pwd)"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <hostname> <port>"
  exit 1
fi

HOSTNAME=$1
PORT=$2
OUTPUT_PATH=$ORIGINAL_PWD

if [ ! -d "$OUTPUT_PATH" ]; then
  mkdir -p "$OUTPUT_PATH"
fi

# Ensure OUTPUT_PATH is absolute
OUTPUT_PATH=$(cd "$OUTPUT_PATH" && pwd)
echo "Output path: $OUTPUT_PATH"

# Prevent copying to the same directory as the script
if [ "$OUTPUT_PATH" = "$(pwd)" ]; then
  echo "Error: Output path cannot be the same as the script directory."
  exit 1
fi

# Remove existing docker/ and docker-compose.yml if they exist (avoid removing source)
if [ "$OUTPUT_PATH" != "$(pwd)" ]; then
  if [ -d "$OUTPUT_PATH/docker" ]; then
    rm -rf "$OUTPUT_PATH/docker"
  fi
  if [ -f "$OUTPUT_PATH/docker-compose.yml" ]; then
    rm -f "$OUTPUT_PATH/docker-compose.yml"
  fi
fi

cp -r docker-compose.yml docker/ "$OUTPUT_PATH/"

# Sanitize hostname for service name (replace dots and hyphens with underscores)
SANITIZED_HOSTNAME=$(echo "$HOSTNAME" | tr '.' '_' | tr '-' '_')
NEW_SERVICE_NAME="app_${SANITIZED_HOSTNAME}"

# Update service name from erp_hbr_app to app_<hostname>
sed -i "s/erp_hbr_app:/${NEW_SERVICE_NAME}:/g" "$OUTPUT_PATH/docker-compose.yml"

# Update container_name for app service
sed -i "s/container_name: erp.hbr-app/container_name: ${NEW_SERVICE_NAME}/g" "$OUTPUT_PATH/docker-compose.yml"

# Add hostname to app service
sed -i "/container_name: ${NEW_SERVICE_NAME}/a\        hostname: ${HOSTNAME}" "$OUTPUT_PATH/docker-compose.yml"

# Update port for nginx service
sed -i "s/\"8060:80\"/\"${PORT}:80\"/g" "$OUTPUT_PATH/docker-compose.yml"

# Update Traefik rule hostname
sed -i "s/Host(\`erp.hbr.test\`)/Host(\`${HOSTNAME}\`)/g" "$OUTPUT_PATH/docker-compose.yml"

# Update Traefik router/service names to avoid conflicts
sed -i "s/erphbr/${SANITIZED_HOSTNAME}/g" "$OUTPUT_PATH/docker-compose.yml"

# Update nginx service name
sed -i "s/erp_hbr_nginx:/nginx_${SANITIZED_HOSTNAME}:/g" "$OUTPUT_PATH/docker-compose.yml"

# Update container_name for nginx service
sed -i "s/container_name: erp.hbr-nginx/container_name: nginx_${SANITIZED_HOSTNAME}/g" "$OUTPUT_PATH/docker-compose.yml"

# Update nginx.conf server_name
sed -i "s/server_name erp.hbr.test;/server_name ${HOSTNAME};/g" "$OUTPUT_PATH/docker/nginx/nginx.conf"

# Update nginx.conf fastcgi_pass to new app service name
sed -i "s/fastcgi_pass erp_hbr_app:9000;/fastcgi_pass ${NEW_SERVICE_NAME}:9000;/g" "$OUTPUT_PATH/docker/nginx/nginx.conf"

# Generate self-signed certificate for the hostname
CERT_DIR="../../traefik/traefik/traefik-config/certs"
CERT_FILE="$CERT_DIR/${HOSTNAME}.pem"
KEY_FILE="$CERT_DIR/${HOSTNAME}-key.pem"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Generating self-signed certificate for $HOSTNAME..."
    openssl req -x509 -newkey rsa:4096 -keyout "$KEY_FILE" -out "$CERT_FILE" -days 365 -nodes -subj "/CN=$HOSTNAME"
    echo "Generated $CERT_FILE and $KEY_FILE"
else
    echo "Certificate for $HOSTNAME already exists."
fi

# Add certificate to Traefik certs.yml if not already present
CERTS_YML="../../traefik/traefik/traefik-config/dynamic_conf/certs.yml"
if ! grep -q "certFile: /etc/traefik/certs/${HOSTNAME}.pem" "$CERTS_YML"; then
    echo "Adding certificate entry to $CERTS_YML"
    cat >> "$CERTS_YML" << EOF
    - certFile: /etc/traefik/certs/${HOSTNAME}.pem
      keyFile: /etc/traefik/certs/${HOSTNAME}-key.pem
EOF
else
    echo "Certificate entry for $HOSTNAME already in $CERTS_YML"
fi

echo "Docker config copied to $OUTPUT_PATH and configured for hostname=$HOSTNAME, port=$PORT"
