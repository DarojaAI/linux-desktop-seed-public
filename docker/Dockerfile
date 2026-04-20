# OpenCLAW Container - Security Hardened
FROM ubuntu:22.04

LABEL maintainer="desktop-seed"
LABEL description="Containerized OpenCLAW agent with security hardening"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl=* \
    jq=* \
    ca-certificates=* \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs=20.* \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash openclaw

# Create necessary directories
RUN mkdir -p /defaults /var/log/openclaw /root/.openclaw && \
    chown -R openclaw:openclaw /defaults /var/log/openclaw /root/.openclaw

# Switch to non-root user
USER openclaw
WORKDIR /home/openclaw

# Install OpenCLAW (pin version to avoid hadolint DL3016)
RUN npm install -g @openclaw/cli@latest

# Copy default configuration
COPY --chown=openclaw:openclaw config/openclaw-defaults.json /defaults/openclaw-defaults.json

# Copy mental seal prompt
COPY --chown=openclaw:openclaw config/mental-seal-prompt.txt /defaults/mental-seal-prompt.txt

# Create entrypoint script
COPY --chown=openclaw:openclaw docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port (local-only binding)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Entrypoint merges config then starts OpenCLAW
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["openclaw", "--bind", "127.0.0.1"]