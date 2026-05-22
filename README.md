# OpenSlides Traefik Proxy Service

The OpenSlides Traefik proxy service is a reverse proxy based on [Traefik](https://traefik.io/) that
routes all external traffic to the appropriate OpenSlides services.

## Overview

This service:

- Can provide HTTPS termination with self-signed certificates for development
  or with certs retrieved via ACME protocol (e.g. lets encrypt) for production
- Routes requests to appropriate microservices based on URL paths
- Handles WebSocket connections for real-time features

## Configuration

The proxy service is configured through:

- `traefik.yml` - Static/install configuration
- `dynamic.yml` - Dynamic/routing configuration
- `entrypoint.sh`  - Both yml config files are generated here during container startup.
  - -> Environment variables are taken into account affecting the final `.yml` configuration, see below.

### Environment Variables

- `ENABLE_LOCAL_HTTPS` - Enable HTTPS with local certificates (default: 1 in dev image)
- `TRAEFIK_LOG_LEVEL` - Log level (default: INFO, DEBUG in dev image)
- `ENABLE_DASHBOARD` - Enable traefik web-based dashboard, also sets `debug: true` for now
- `ENABLE_LOCAL_HTTPS` - Enable TLS using certs provided through `HTTPS_*_FILE`. Can be self-signed (used in dev by default) or manually generated/trusted.
- `ENABLE_AUTO_HTTPS` - Enable cert retrieval through ACME. Depends on further variables. (Overruled by `ENABLE_LOCAL_HTTPS` if both are set)
  - `EXTERNAL_ADDRESS` - domain for which to retrieve cert
  - `ACME_ENDPOINT` - when unset will fallback to traefiks default value for `acme.caServer: https://acme-v02.api.letsencrypt.org/directory`
  - `ACME_EMAIL` - Email Address sent to acme endpoint during cert retrieval
- `*_HOST` and `*_PORT` - endpoints (container (host-)names) of OpenSlides microservices. Defaults should be fine in most cases.

## License

This service is part of OpenSlides and licensed under the MIT license.
