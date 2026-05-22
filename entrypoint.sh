#!/bin/sh
# Co-authored-by: Claude <noreply@anthropic.com>

set -ae

# Define variables and set defaults where applicable
TRAEFIK_CONFIG="${TRAEFIK_CONFIG:-/etc/traefik/traefik.yml}"
TRAEFIK_LOG_LEVEL="${TRAEFIK_LOG_LEVEL:-INFO}"
ENABLE_DASHBOARD="${ENABLE_DASHBOARD:-}"
DYNAMIC_DIR="${DYNAMIC_DIR:-/etc/traefik/dynamic}"
DYNAMIC_CONFIG="${DYNAMIC_DIR}/dynamic.yml"
SERVICES_DIR="${SERVICES_DIR:-/services}"
ENABLE_LOCAL_HTTPS="${ENABLE_LOCAL_HTTPS:-}"
HTTPS_CERT_FILE="${HTTPS_CERT_FILE:-/certs/cert.pem}"
HTTPS_KEY_FILE="${HTTPS_KEY_FILE:-/certs/key.pem}"
ENABLE_AUTO_HTTPS="${ENABLE_AUTO_HTTPS:-}"
EXTERNAL_ADDRESS="${EXTERNAL_ADDRESS:-openslides.example.com}"
ACME_ENDPOINT="${ACME_ENDPOINT:-}"
ACME_EMAIL="${ACME_EMAIL:-}"

# Set default values for service endpoints
ACTION_HOST="${ACTION_HOST:-backend}"
ACTION_PORT="${ACTION_PORT:-9002}"
PRESENTER_HOST="${PRESENTER_HOST:-backend}"
PRESENTER_PORT="${PRESENTER_PORT:-9003}"
AUTOUPDATE_HOST="${AUTOUPDATE_HOST:-autoupdate}"
AUTOUPDATE_PORT="${AUTOUPDATE_PORT:-9012}"
ICC_HOST="${ICC_HOST:-icc}"
ICC_PORT="${ICC_PORT:-9007}"
AUTH_HOST="${AUTH_HOST:-auth}"
AUTH_PORT="${AUTH_PORT:-9004}"
SEARCH_HOST="${SEARCH_HOST:-search}"
SEARCH_PORT="${SEARCH_PORT:-9050}"
PROJECTOR_HOST="${PROJECTOR_HOST:-projector}"
PROJECTOR_PORT="${PROJECTOR_PORT:-9051}"
MEDIA_HOST="${MEDIA_HOST:-media}"
MEDIA_PORT="${MEDIA_PORT:-9006}"
VOTE_HOST="${VOTE_HOST:-vote}"
VOTE_PORT="${VOTE_PORT:-9013}"
CLIENT_HOST="${CLIENT_HOST:-client}"
CLIENT_PORT="${CLIENT_PORT:-9001}"


# =================================
# = Build static / install config =
# =================================

# Generate base config from template
envsubst < /templates/traefik.yml > "$TRAEFIK_CONFIG"

# Add dashboard if enabled
if [ -n "$ENABLE_DASHBOARD" ]; then
  echo "Enabling dashboard. 'debug: true' for now. NOT FOR PRODUCTION"
  cat >> "$TRAEFIK_CONFIG" << 'EOF'

api:
  dashboard: true
  debug: true
EOF
fi

# Add entryPoints in accordance to HTTPS related variables
cat >> "$TRAEFIK_CONFIG" << 'EOF'
entryPoints:
  main:
    address: ":8000"
    http:
EOF

if [ -n "$ENABLE_LOCAL_HTTPS" ]; then
  # Define tls property, which will cause all routers to terminate TLS and
  # foward decrypted traffic.
  cat >> "$TRAEFIK_CONFIG" << 'EOF'
      tls: {}
EOF
elif [ -n "$ENABLE_AUTO_HTTPS" ]; then
  # Also needs tls property, but with additional information for cert retrieval
  cat >> "$TRAEFIK_CONFIG" << EOF
      tls:
        domains:
          - main: ${EXTERNAL_ADDRESS}
        certResolver: acmeResolver
EOF
  # Additionally a plain HTTP endpoint to answer ACME challenges on must be
  # configured
  cat >> "$TRAEFIK_CONFIG" << 'EOF'

  acme:
    address: ":8001"
EOF
  # Add the certificates resolver providing information for automatic ACME
  # based cert retrieval.
  cat >> "$TRAEFIK_CONFIG" << EOF

certificatesResolvers:
  acmeResolver:
    acme:
      email: ${ACME_EMAIL}
      storage: acme.json
      httpChallenge:
        entryPoint: acme
EOF
  if [ -n "$ACME_ENDPOINT" ]; then
    cat >> "$TRAEFIK_CONFIG" << EOF
      caServer: ${ACME_ENDPOINT}
EOF
  fi

  echo "traefik was configured to automatically retrieve a TLS certificates via acme."
  echo "Make sure incoming challange requests (to HOST:80/.well-known/acme-challenge/) reach this container on port 8001"
  echo "In most cases forwarding the hosts port 80 to containers port 8001 is enough."
fi


# ==================================
# = Build dynamic / routing config =
# ==================================

# Start with empty file
echo "" > "$DYNAMIC_CONFIG"

if [ -n "$ENABLE_LOCAL_HTTPS" ]; then
  if [ -f "$HTTPS_CERT_FILE" ] && [ -f "$HTTPS_KEY_FILE" ]; then
    envsubst < /templates/tls.yml >> "$DYNAMIC_CONFIG"
  else
    echo "ERROR: no local cert-files provided. Did you run make-localhost-cert.sh?"
    exit 1
  fi
fi

# First build SERVICES list (space separated) based on files present in
# services directory
SERVICES=
for service_file in $SERVICES_DIR/*.service; do
  service=$(basename $service_file .service)
  service_upper=$(echo "$service" | tr '[:lower:]' '[:upper:]')
  host_var="${service_upper}_HOST"

  if [[ ! -f "$SERVICES_DIR/$service.service" ]] || [[ ! -f "$SERVICES_DIR/$service.router" ]]; then
    echo "Skipping, config incomplete: $service"
    continue
  fi

  if eval [[ -n "\$${host_var}" ]]; then
    eval "echo \"Adding config: $service (host: \$${host_var})\"" >&2
    SERVICES="$SERVICES $service"
  else
    echo "Skipping, disabled in environment: $service"
  fi
done

# Write to config file
cat >> "$DYNAMIC_CONFIG" << 'EOF'

http:
  routers:
EOF

# Concatenate all enabled .router files
for service in $SERVICES; do
  envsubst < "$SERVICES_DIR/${service}.router" >> "$DYNAMIC_CONFIG"
done

# Add services section
cat >> "$DYNAMIC_CONFIG" << 'EOF'

  services:
EOF

# Concatenate all enabled .service files
for service in $SERVICES; do
  envsubst < "$SERVICES_DIR/${service}.service" >> "$DYNAMIC_CONFIG"
done


# Finally start CMD
exec "$@"
