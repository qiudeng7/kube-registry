# Alpine-based Clash sidecar container
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    ca-certificates \
    shadow

# Create app user and directory
RUN addgroup -g 1000 clash && \
    adduser -D -u 1000 -G clash clash && \
    mkdir -p /home/clash/.config/clash && \
    chown -R clash:clash /home/clash

# Set working directory
WORKDIR /home/clash

# Download and install mihomo (clash premium alternative)
# Using mihomo for better compatibility and active development
ARG MIHOMO_VERSION=v1.18.10
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64)  MIHOMO_ARCH="amd64" ;; \
        aarch64) MIHOMO_ARCH="arm64" ;; \
        armv7l)  MIHOMO_ARCH="armv7" ;; \
        *)       MIHOMO_ARCH="amd64" ;; \
    esac && \
    curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${MIHOMO_ARCH}.gz" | \
    gunzip - > /usr/local/bin/clash && \
    chmod +x /usr/local/bin/clash

# Download and install yq for YAML processing
ARG YQ_VERSION=v4.44.3
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Copy main.sh script
COPY --chown=clash:clash main.sh /home/clash/main.sh
RUN chmod +x /home/clash/main.sh

# Switch to clash user
USER clash

# Expose clash ports
# 7890: HTTP proxy
# 7891: SOCKS5 proxy
# 9090: Dashboard/RESTful API
EXPOSE 7890 7891 9090

# Set environment variables
ENV CLASH_CONFIG_DIR=/home/clash/.config/clash
ENV CLASH_CONFIG_FILE=/home/clash/.config/clash/config.yaml

# Run main.sh on container start
CMD ["/bin/bash", "/home/clash/main.sh"]
