#!/bin/bash

# GitHub Organization Runner Management Script
# This script helps manage multiple GitHub Action runners for an organization

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="github-runner-podman"
ORG_URL=""
RUNNER_TOKEN=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
load_config() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
        log_info "Loaded configuration from .env file"
    fi
    
    if [ -z "$ORG_URL" ]; then
        read -p "Enter GitHub organization URL (e.g., https://github.com/your-org): " ORG_URL
    fi
    
    if [ -z "$RUNNER_TOKEN" ]; then
        log_warn "Runner token not set. You'll need to provide it for each runner."
        read -s -p "Enter runner token (optional, can be set per runner): " RUNNER_TOKEN
        echo
    fi
}

# Build the Docker image
build_image() {
    log_info "Building GitHub runner image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
    log_info "Image built successfully"
}

# Create a new runner
create_runner() {
    local runner_name="$1"
    local runner_group="${2:-Default}"
    local runner_labels="${3:-ubuntu-22.04,podman,self-hosted,organization}"
    local runner_token="${4:-$RUNNER_TOKEN}"
    local cpus="${5:-2}"
    local memory="${6:-4g}"
    
    if [ -z "$runner_token" ]; then
        read -s -p "Enter runner token for $runner_name: " runner_token
        echo
    fi
    
    log_info "Creating runner: $runner_name"
    
    docker run -d \
        --name "$runner_name" \
        --restart unless-stopped \
        --cpus="$cpus" \
        --memory="$memory" \
        -e ORG_URL="$ORG_URL" \
        -e RUNNER_TOKEN="$runner_token" \
        -e RUNNER_NAME="$runner_name" \
        -e RUNNER_GROUP="$runner_group" \
        -e RUNNER_LABELS="$runner_labels" \
        -v "${runner_name}-work:/home/runner/_work" \
        -v "${runner_name}-storage:/home/runner/.local/share/containers" \
        "$IMAGE_NAME"
    
    log_info "Runner $runner_name created and started"
}

# Stop and remove a runner
remove_runner() {
    local runner_name="$1"
    
    log_info "Removing runner: $runner_name"
    
    # Stop the container gracefully (this should trigger cleanup)
    docker stop "$runner_name" 2>/dev/null || true
    
    # Wait a bit for cleanup
    sleep 5
    
    # Remove the container
    docker rm "$runner_name" 2>/dev/null || true
    
    # Optionally remove volumes
    read -p "Remove associated volumes? (y/N): " remove_volumes
    if [[ $remove_volumes =~ ^[Yy]$ ]]; then
        docker volume rm "${runner_name}-work" 2>/dev/null || true
        docker volume rm "${runner_name}-storage" 2>/dev/null || true
        log_info "Volumes removed"
    fi
    
    log_info "Runner $runner_name removed"
}

# List all runners
list_runners() {
    log_info "GitHub Action Runners:"
    docker ps -a --filter "ancestor=$IMAGE_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
}

# Show runner logs
show_logs() {
    local runner_name="$1"
    docker logs -f "$runner_name"
}

# Scale runners
scale_runners() {
    local base_name="$1"
    local count="$2"
    local runner_group="${3:-Default}"
    local runner_labels="${4:-ubuntu-22.04,podman,self-hosted,organization}"
    
    log_info "Scaling $base_name runners to $count instances"
    
    for i in $(seq 1 "$count"); do
        local runner_name="${base_name}-$(printf "%02d" $i)"
        
        # Check if runner already exists
        if docker ps -a --format '{{.Names}}' | grep -q "^${runner_name}$"; then
            log_warn "Runner $runner_name already exists, skipping"
            continue
        fi
        
        create_runner "$runner_name" "$runner_group" "$runner_labels"
        sleep 2  # Brief delay between creating runners
    done
}

# Create predefined runner configurations
create_preset_runners() {
    log_info "Creating preset runner configurations..."
    
    # High-CPU builder
    create_runner "org-builder-01" "Builders" "ubuntu-22.04,podman,self-hosted,organization,high-cpu,builder" "" "4" "8g"
    
    # Standard test runner
    create_runner "org-tester-01" "Testing" "ubuntu-22.04,podman,self-hosted,organization,testing" "" "2" "4g"
    
    # mc_rtc specific runner
    create_runner "org-mc-rtc-01" "Development" "ubuntu-22.04,podman,self-hosted,organization,mc-rtc,cpp" "" "4" "6g"
}

# Health check for runners
health_check() {
    log_info "Checking runner health..."
    
    local unhealthy_runners=()
    
    for runner in $(docker ps --filter "ancestor=$IMAGE_NAME" --format '{{.Names}}'); do
        # Check if runner is responding
        if ! docker exec "$runner" podman --version >/dev/null 2>&1; then
            unhealthy_runners+=("$runner")
        fi
    done
    
    if [ ${#unhealthy_runners[@]} -eq 0 ]; then
        log_info "All runners are healthy"
    else
        log_warn "Unhealthy runners found: ${unhealthy_runners[*]}"
        
        read -p "Restart unhealthy runners? (y/N): " restart_unhealthy
        if [[ $restart_unhealthy =~ ^[Yy]$ ]]; then
            for runner in "${unhealthy_runners[@]}"; do
                log_info "Restarting $runner"
                docker restart "$runner"
            done
        fi
    fi
}

# Main menu
show_menu() {
    echo
    echo "GitHub Organization Runner Management"
    echo "===================================="
    echo "1. Build runner image"
    echo "2. Create single runner"
    echo "3. Create preset runners"
    echo "4. Scale runners"
    echo "5. List runners"
    echo "6. Show runner logs"
    echo "7. Remove runner"
    echo "8. Health check"
    echo "9. Exit"
    echo
}

# Main script
main() {
    load_config
    
    while true; do
        show_menu
        read -p "Choose an option (1-9): " choice
        
        case $choice in
            1)
                build_image
                ;;
            2)
                read -p "Runner name: " name
                read -p "Runner group (Default): " group
                group=${group:-Default}
                read -p "Labels (ubuntu-22.04,podman,self-hosted,organization): " labels
                labels=${labels:-ubuntu-22.04,podman,self-hosted,organization}
                create_runner "$name" "$group" "$labels"
                ;;
            3)
                create_preset_runners
                ;;
            4)
                read -p "Base name: " base_name
                read -p "Count: " count
                read -p "Runner group (Default): " group
                group=${group:-Default}
                scale_runners "$base_name" "$count" "$group"
                ;;
            5)
                list_runners
                ;;
            6)
                read -p "Runner name: " name
                show_logs "$name"
                ;;
            7)
                read -p "Runner name: " name
                remove_runner "$name"
                ;;
            8)
                health_check
                ;;
            9)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
