#!/bin/bash
set -e

# Find all docker-compose.yml files in gitlab directory (excluding vendor directories)
COMPOSE_FILES=$(find /home/kienct/gitlab -name "docker-compose.yml" -type f | grep -v vendor)

echo "Found $(echo "$COMPOSE_FILES" | wc -l) docker-compose.yml files to update..."

for compose_file in $COMPOSE_FILES; do
    echo "Processing: $compose_file"
    
    # Check if file has TLS configuration but missing certresolver
    if grep -q "traefik.http.routers.*tls=true" "$compose_file" && ! grep -q "tls.certresolver" "$compose_file"; then
        echo "  Adding certresolver to TLS configuration..."
        
        # Add certresolver after each tls=true line
        sed -i '/traefik\.http\.routers\..*\.tls=true/a\            - traefik.http.routers.\1.tls.certresolver=default' "$compose_file"
        
        echo "  ✓ Updated"
    else
        echo "  - Already has certresolver or no TLS config"
    fi
done

echo "All docker-compose.yml files updated!"