#!/bin/bash
set -e

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    if [ -f .runner ]; then
        ./config.sh remove --unattended --token ${RUNNER_TOKEN} || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Validate required environment variables
# Support both organization and repository runners
if [ -z "$ORG_URL" ] && [ -z "$REPO_URL" ]; then
    echo "ERROR: Either ORG_URL or REPO_URL environment variable is required"
    echo "  For organization runners: ORG_URL=https://github.com/your-org"
    echo "  For repository runners: REPO_URL=https://github.com/your-org/your-repo"
    exit 1
fi

if [ -z "$RUNNER_TOKEN" ]; then
    echo "ERROR: RUNNER_TOKEN environment variable is required"
    echo "  Get this from GitHub Settings -> Actions -> Runners -> New runner"
    exit 1
fi

# Determine the URL to use
if [ -n "$ORG_URL" ]; then
    TARGET_URL="$ORG_URL"
    RUNNER_SCOPE="organization"
    echo "Configuring organization runner for: $ORG_URL"
else
    TARGET_URL="$REPO_URL"
    RUNNER_SCOPE="repository"
    echo "Configuring repository runner for: $REPO_URL"
fi

# Set default runner name if not provided
if [ -z "$RUNNER_NAME" ]; then
    if [ "$RUNNER_SCOPE" = "organization" ]; then
        RUNNER_NAME="org-podman-runner-$(hostname)"
    else
        RUNNER_NAME="repo-podman-runner-$(hostname)"
    fi
fi

# Set default work directory if not provided
if [ -z "$RUNNER_WORKDIR" ]; then
    RUNNER_WORKDIR="_work"
fi

# Set default labels based on scope
if [ -z "$RUNNER_LABELS" ]; then
    if [ "$RUNNER_SCOPE" = "organization" ]; then
        RUNNER_LABELS="ubuntu-22.04,podman,self-hosted,organization"
    else
        RUNNER_LABELS="ubuntu-22.04,podman,self-hosted,repository"
    fi
fi

# Set default runner group for organization runners
if [ "$RUNNER_SCOPE" = "organization" ] && [ -z "$RUNNER_GROUP" ]; then
    RUNNER_GROUP="Default"
fi

# Test Podman functionality
echo "Testing Podman functionality..."
podman --version
podman info --format "{{.Host.RemoteSocket}}" || true

# Create Docker alias in current session
alias docker=podman
export DOCKER_HOST=""

# Verify Docker alias works
echo "Testing Docker compatibility..."
docker --version
docker info > /dev/null 2>&1 && echo "Podman accessible via 'docker' command" || echo "Warning: Podman not accessible via 'docker' command"

# Configure the runner
echo "Configuring GitHub Actions runner..."
echo "Scope: $RUNNER_SCOPE"
echo "Target URL: $TARGET_URL"

# Build configuration command
CONFIG_CMD="./config.sh --url \"${TARGET_URL}\" --token \"${RUNNER_TOKEN}\" --name \"${RUNNER_NAME}\" --work \"${RUNNER_WORKDIR}\" --labels \"${RUNNER_LABELS}\" --unattended --replace"

# Add runner group for organization runners
if [ "$RUNNER_SCOPE" = "organization" ] && [ -n "$RUNNER_GROUP" ]; then
    CONFIG_CMD="$CONFIG_CMD --runnergroup \"${RUNNER_GROUP}\""
fi

# Execute configuration
eval $CONFIG_CMD

# Start the runner
echo "Starting GitHub Actions runner..."
echo "Runner Name: ${RUNNER_NAME}"
echo "Target: ${TARGET_URL}"
echo "Scope: ${RUNNER_SCOPE}"
echo "Work Directory: ${RUNNER_WORKDIR}"
echo "Labels: ${RUNNER_LABELS}"
if [ "$RUNNER_SCOPE" = "organization" ]; then
    echo "Runner Group: ${RUNNER_GROUP}"
fi
echo "Podman Version: $(podman --version)"

# Run the GitHub Actions runner
./run.sh
