#!/usr/bin/env bash
set -euo pipefail

# Kiro Desktop Update Checker
# Fetches the latest version from the official metadata API and updates flake.nix

METADATA_URL="https://prod.download.desktop.kiro.dev/stable/metadata-linux-x64-stable.json"
FLAKE_FILE="flake.nix"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Fetch metadata from API with retries
fetch_metadata() {
    local retries=3
    local delay=5
    local attempt=1

    while [ $attempt -le $retries ]; do
        log_info "Fetching metadata (attempt $attempt/$retries)..." >&2
        if metadata=$(curl -sL --fail --max-time 30 "$METADATA_URL"); then
            echo "$metadata"
            return 0
        fi
        log_warn "Fetch failed, retrying in ${delay}s..." >&2
        sleep $delay
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done

    log_error "Failed to fetch metadata after $retries attempts" >&2
    return 1
}

# Extract version from metadata
get_latest_version() {
    local metadata="$1"
    echo "$metadata" | jq -r '.currentRelease'
}

# Extract download URL from metadata
get_download_url() {
    local metadata="$1"
    echo "$metadata" | jq -r '.releases[0].updateTo | select(.url | contains(".tar.gz")) | .url'
}

# Get current version from flake.nix
get_current_version() {
    grep -oP 'version = "\K[^"]+' "$FLAKE_FILE" | head -1
}

# Compare versions (semantic version comparison)
version_greater_than() {
    local new_version="$1"
    local current_version="$2"

    # Use sort -V for semantic version comparison
    if [ "$(printf '%s\n%s' "$current_version" "$new_version" | sort -V | tail -1)" = "$new_version" ] && [ "$new_version" != "$current_version" ]; then
        return 0
    else
        return 1
    fi
}

# Compute SHA256 hash using nix-prefetch-url
compute_hash() {
    local url="$1"
    log_info "Computing SHA256 hash for download..."

    # Run nix-prefetch-url with timeout to get the hash
    if ! raw_hash=$(timeout 600 nix-prefetch-url --type sha256 "$url" 2>&1 | tail -1); then
        log_error "Hash computation failed or timed out"
        return 1
    fi

    # Convert to SRI format (sha256-xxx) using nix hash convert
    if ! sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$raw_hash" 2>&1); then
        log_error "Hash conversion to SRI format failed"
        return 1
    fi

    echo "$sri_hash"
}

# Update flake.nix with new version, URL, and hash
update_flake() {
    local new_version="$1"
    local new_url="$2"
    local new_hash="$3"

    log_info "Updating flake.nix..."

    # Create backup
    cp "$FLAKE_FILE" "${FLAKE_FILE}.backup"

    # Update version
    sed -i "s|version = \"[^\"]*\";|version = \"${new_version}\";|" "$FLAKE_FILE"

    # Update URL - escape special characters for sed
    local escaped_url=$(printf '%s\n' "$new_url" | sed 's/[&/\]/\\&/g')
    sed -i "s|url = \"https://prod.download.desktop.kiro.dev/releases/[^\"]*\";|url = \"${escaped_url}\";|" "$FLAKE_FILE"

    # Update hash
    sed -i "s|hash = \"sha256-[^\"]*\";|hash = \"${new_hash}\";|" "$FLAKE_FILE"

    # Validate that flake.nix is still valid Nix
    if ! nix flake metadata . --no-write-lock-file &>/dev/null; then
        log_error "flake.nix validation failed, rolling back"
        mv "${FLAKE_FILE}.backup" "$FLAKE_FILE"
        return 1
    fi

    rm "${FLAKE_FILE}.backup"
    log_info "flake.nix updated successfully"
}

# Build verification
verify_build() {
    log_info "Verifying build with new version..."

    if ! timeout 1800 nix build .#kiro-desktop --no-link 2>&1 | tee build.log; then
        log_error "Build verification failed"
        return 1
    fi

    log_info "Build verification successful"
    return 0
}

# Main execution
main() {
    log_info "Starting Kiro Desktop update check..."

    # Fetch metadata
    if ! metadata=$(fetch_metadata); then
        exit 1
    fi

    # Extract version and URL
    new_version=$(get_latest_version "$metadata")
    new_url=$(get_download_url "$metadata")

    if [ -z "$new_version" ] || [ -z "$new_url" ]; then
        log_error "Failed to parse metadata (version or URL missing)"
        exit 1
    fi

    log_info "Latest version: $new_version"
    log_info "Download URL: $new_url"

    # Get current version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Compare versions
    if ! version_greater_than "$new_version" "$current_version"; then
        log_info "No update needed (current: $current_version, latest: $new_version)"
        exit 0
    fi

    log_info "Update available: $current_version -> $new_version"

    # Compute hash
    if ! new_hash=$(compute_hash "$new_url"); then
        exit 1
    fi

    log_info "Computed hash: $new_hash"

    # Update flake.nix
    if ! update_flake "$new_version" "$new_url" "$new_hash"; then
        exit 1
    fi

    # Verify build
    if ! verify_build; then
        log_error "Build verification failed, update aborted"
        # Reset changes
        git checkout -- "$FLAKE_FILE"
        exit 1
    fi

    # Export variables for GitHub Actions
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "updated=true" >> "$GITHUB_OUTPUT"
        echo "new_version=$new_version" >> "$GITHUB_OUTPUT"
        echo "new_url=$new_url" >> "$GITHUB_OUTPUT"
        echo "current_version=$current_version" >> "$GITHUB_OUTPUT"
    fi

    log_info "Update complete! Version $current_version -> $new_version"
}

main "$@"
