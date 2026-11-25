ARG CONTEXT=prod

FROM traefik:3.6.0 AS base

## Setup
ARG CONTEXT
WORKDIR /app
ENV APP_CONTEXT=${CONTEXT}

# curl for healthcheck, gettext for templating (envsubst)
RUN apk add --no-cache curl gettext jq

# Copy configuration files
COPY entrypoint.sh /entrypoint.sh
COPY certs /certs
COPY services /services
COPY templates /templates
COPY plugins-local plugins-local

# Create dynamic config directory and make entrypoint executable
RUN mkdir -p /etc/traefik/dynamic
RUN chmod +x /entrypoint.sh

# External Information
LABEL org.opencontainers.image.title="OpenSlides Traefik Proxy"
LABEL org.opencontainers.image.description="The Traefik proxy is the entrypoint for traffic going into an OpenSlides instance."
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/OpenSlides/OpenSlides/tree/main/openslides-proxy"

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:8080/ping

# Command
ENTRYPOINT ["/entrypoint.sh"]
COPY ./dev/command.sh ./
RUN chmod +x command.sh
CMD ["./command.sh"]


# Development Image
FROM base AS dev

ENV ENABLE_LOCAL_HTTPS=1
ENV ENABLE_DASHBOARD=1
ENV TRAEFIK_LOG_LEVEL=DEBUG


# Testing Image
FROM base AS tests


# Production Image
FROM base AS prod

# Add appuser for security
RUN adduser -S -D -H appuser
RUN chown -R appuser /app/ && \
    chown -R appuser /etc/traefik/ && \
    chown appuser /entrypoint.sh

USER appuser
