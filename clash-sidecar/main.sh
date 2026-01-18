#!/usr/bin/env bash
set -e

# Configuration
CLASH_CONFIG_DIR="${CLASH_CONFIG_DIR:-/home/clash/.config/clash}"
CLASH_CONFIG_FILE="${CLASH_CONFIG_FILE:-${CLASH_CONFIG_DIR}/config.yaml}"
CLASH_TEMP_CONFIG="${CLASH_CONFIG_DIR}/temp.yaml"
SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate configuration using clash binary
validate_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    if [[ $(wc -l < "$config_file") -lt 1 ]]; then
        log_error "Config file is empty"
        return 1
    fi

    log_info "Validating configuration..."
    if clash -d "$CLASH_CONFIG_DIR" -f "$config_file" -t; then
        log_info "Configuration is valid"
        return 0
    else
        log_error "Configuration validation failed"
        return 1
    fi
}

# Download configuration from subscription URL
download_config() {
    local url="$1"
    local output="$2"

    log_info "Downloading configuration from subscription URL..."

    # Save raw response for debugging
    local raw_output="${output}.raw"

    if curl --silent --show-error --fail --insecure --location \
        --max-time 30 \
        --retry 3 \
        --user-agent "clash-verge/v1.4.8" \
        --output "$raw_output" \
        "$url"; then
        log_info "Download successful"
    else
        log_error "Failed to download configuration"
        return 1
    fi

    # Check if the downloaded content is valid
    if [[ ! -s "$raw_output" ]]; then
        log_error "Downloaded file is empty"
        return 1
    fi

    # Try to use the downloaded config directly
    cp "$raw_output" "$output"

    # Validate the configuration
    if validate_config "$output"; then
        log_info "Configuration downloaded and validated successfully"
        rm -f "$raw_output"
        return 0
    fi

    # If validation fails, try to detect and handle base64 encoded config
    log_warn "Direct validation failed, checking for base64 encoding..."
    if base64 -d "$raw_output" > "$output" 2>/dev/null; then
        if validate_config "$output"; then
            log_info "Base64 encoded configuration decoded successfully"
            rm -f "$raw_output"
            return 0
        fi
    fi

    # Try to handle subscription conversion API
    log_warn "Attempting subscription conversion..."
    if convert_subscription "$url" "$output"; then
        log_info "Subscription conversion successful"
        rm -f "$raw_output"
        return 0
    fi

    log_error "All conversion attempts failed"
    log_error "Raw config saved at: $raw_output"
    return 1
}

# Convert subscription using a public subconverter
convert_subscription() {
    local subscription_url="$1"
    local output="$2"

    # Try multiple public subconverter services
    local converters=(
        "https://sub.xeton.dev/sub"
        "https://api.dler.io/sub"
        "https://sub.id9.cc/sub"
    )

    for converter in "${converters[@]}"; do
        log_info "Trying converter: $converter"

        local convert_url="${converter}?target=clash&new_name=true&url=${subscription_url}"

        if curl --silent --show-error --fail --location \
            --max-time 30 \
            --user-agent "clash-verge/v1.4.8" \
            --output "$output" \
            "$convert_url"; then

            if validate_config "$output"; then
                log_info "Conversion successful using: $converter"
                return 0
            fi
        fi

        log_warn "Converter failed: $converter"
    done

    return 1
}

# Apply mixin configuration (custom overrides)
apply_mixin() {
    local base_config="$1"
    local mixin_config="$2"
    local output_config="$3"

    if [[ ! -f "$mixin_config" ]]; then
        cp "$base_config" "$output_config"
        return 0
    fi

    log_info "Applying mixin configuration..."

    # Use yq to merge configurations
    if yq eval-all '
        select(fileIndex==0) as $base |
        select(fileIndex==1) as $mixin |
        ($base // {}) * $mixin |
        .rules = (($mixin.rules.prefix // []) + ($base.rules // []) + ($mixin.rules.suffix // [])) |
        .proxies = (($mixin.proxies.prefix // []) + ($base.proxies // []) + ($mixin.proxies.suffix // [])) |
        .["proxy-groups"] = (($mixin["proxy-groups"].prefix // []) + ($base["proxy-groups"] // []) + ($mixin["proxy-groups"].suffix // []))
    ' "$base_config" "$mixin_config" > "$output_config"; then
        log_info "Mixin applied successfully"
        return 0
    else
        log_warn "Failed to apply mixin, using base config"
        cp "$base_config" "$output_config"
        return 1
    fi
}

# Create default mixin configuration
create_default_mixin() {
    cat > "${CLASH_CONFIG_DIR}/mixin.yaml" << 'EOF'
# Clash mixin configuration
# This will be merged with the subscription config

mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: info
external-controller: 0.0.0.0:9090
external-ui: ui
secret: ""

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

proxies: []
proxy-groups: []
rules: []
EOF
}

# Main function
main() {
    log_info "Starting Clash sidecar container..."

    # Create config directory
    mkdir -p "$CLASH_CONFIG_DIR"

    # Check if subscription URL is provided
    if [[ -z "$SUBSCRIPTION_URL" ]]; then
        log_error "SUBSCRIPTION_URL environment variable is not set"
        log_error "Please provide a subscription URL via SUBSCRIPTION_URL environment variable"
        exit 1
    fi

    log_info "Subscription URL: ${SUBSCRIPTION_URL}"

    # Download configuration
    if ! download_config "$SUBSCRIPTION_URL" "$CLASH_TEMP_CONFIG"; then
        log_error "Failed to download/convert subscription configuration"
        exit 1
    fi

    # Create default mixin if it doesn't exist
    if [[ ! -f "${CLASH_CONFIG_DIR}/mixin.yaml" ]]; then
        log_info "Creating default mixin configuration..."
        create_default_mixin
    fi

    # Apply mixin configuration
    if ! apply_mixin "$CLASH_TEMP_CONFIG" "${CLASH_CONFIG_DIR}/mixin.yaml" "$CLASH_CONFIG_FILE"; then
        log_error "Failed to apply mixin configuration"
        exit 1
    fi

    # Clean up temp config
    rm -f "$CLASH_TEMP_CONFIG"

    log_info "Configuration file ready: $CLASH_CONFIG_FILE"

    # Display configuration info
    log_info "Configuration details:"
    yq '.mixed-port, .port, .socks-port, .external-controller, .mode' "$CLASH_CONFIG_FILE" | while read -r line; do
        log_info "  $line"
    done

    # Start clash
    log_info "Starting Clash..."
    exec clash -d "$CLASH_CONFIG_DIR" -f "$CLASH_CONFIG_FILE"
}

# Run main function
main "$@"
