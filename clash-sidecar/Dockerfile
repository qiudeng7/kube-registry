# Alpine-based Clash sidecar container
FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    ca-certificates \
    ca-certificates-bundle \
    openssl \
    shadow && \
    update-ca-certificates

# Create app user and directory
RUN addgroup -g 1000 clash && \
    adduser -D -u 1000 -G clash clash && \
    mkdir -p /home/clash/.config/clash && \
    chown -R clash:clash /home/clash

# Set working directory
WORKDIR /home/clash

# Download GeoIP and GeoSite databases (essential for clash to work)
# These databases are required for GEOIP and GEOSITE rules in clash configs
RUN echo "Downloading GeoIP database..." && \
    (wget --no-check-certificate --tries=5 --timeout=60 -qO- \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb" \
        > /home/clash/.config/clash/Country.mmdb || \
    curl -k --ssl-no-revoke --retry 5 --connect-timeout 15 --max-time 60 -L \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb" \
        -o /home/clash/.config/clash/Country.mmdb) && \
    echo "Downloading GeoSite database..." && \
    (wget --no-check-certificate --tries=5 --timeout=60 -qO- \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
        > /home/clash/.config/clash/geosite.dat || \
    curl -k --ssl-no-revoke --retry 5 --connect-timeout 15 --max-time 60 -L \
        "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat" \
        -o /home/clash/.config/clash/geosite.dat) && \
    chown clash:clash /home/clash/.config/clash/*.mmdb /home/clash/.config/clash/*.dat && \
    ls -lh /home/clash/.config/clash/

# Download and install mihomo (clash premium alternative)
# Using mihomo for better compatibility and active development
# Use version without CPU optimization prefix for better compatibility
ARG MIHOMO_VERSION=v1.18.7
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64)  MIHOMO_ARCH="amd64" ;; \
        aarch64) MIHOMO_ARCH="arm64" ;; \
        armv7l)  MIHOMO_ARCH="armv7" ;; \
        *)       MIHOMO_ARCH="amd64" ;; \
    esac && \
    MIHOMO_BASE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}" && \
    MIHOMO_URL="${MIHOMO_BASE_URL}/mihomo-linux-${MIHOMO_ARCH}-${MIHOMO_VERSION}.gz" && \
    echo "Downloading mihomo ${MIHOMO_VERSION} for ${MIHOMO_ARCH}..." && \
    echo "URL: ${MIHOMO_URL}" && \
    (wget --no-check-certificate --tries=5 --timeout=60 -qO- "${MIHOMO_URL}" || \
    curl -k --ssl-no-revoke --retry 5 --connect-timeout 15 --max-time 60 -L "${MIHOMO_URL}") | \
    gunzip - > /usr/local/bin/clash && \
    chmod +x /usr/local/bin/clash && \
    /usr/local/bin/clash -v

# Download and install yq for YAML processing
ARG YQ_VERSION=v4.44.3
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64)  YQ_ARCH="amd64" ;; \
        aarch64) YQ_ARCH="arm64" ;; \
        armv7l)  YQ_ARCH="arm" ;; \
        *)       YQ_ARCH="amd64" ;; \
    esac && \
    YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" && \
    echo "Downloading yq ${YQ_VERSION} for ${YQ_ARCH}..." && \
    (wget --no-check-certificate --tries=5 --timeout=60 -qO "${YQ_URL}" /usr/local/bin/yq || \
    curl -k --ssl-no-revoke --retry 5 --connect-timeout 15 --max-time 60 -L "${YQ_URL}" -o /usr/local/bin/yq) && \
    chmod +x /usr/local/bin/yq && \
    /usr/local/bin/yq --version

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
