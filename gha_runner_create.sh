#!/bin/bash
#
# Simple bash wrapper to create sysbox-based github-actions runners. Script can be easily
# extended to accommodate the various config options offered by the GHA runner.
#

set -o errexit
set -o pipefail
set -o nounset

function create_sysbox_gha_runner_image() {
    docker rm -f $name >/dev/null 2>&1 || true

    docker build -t gha-sysbox-runner-custom:latest .
}

# Function creates a per-repo runner; it can be easily extended to support org-level
# runners by passing a PAT as ACCESS_TOKEN and set RUNNER_SCOPE="org".
function create_sysbox_gha_runner_repo {
    name=$1
    org=$2
    repo=$3
    token=$4

    echo "Creating repo runner for name=$name org=$org repo=$repo token=$token"

    create_sysbox_gha_runner_image

    docker run -d --restart=always \
        --runtime=sysbox-runc \
        -e REPO_URL="https://github.com/${org}/${repo}" \
        -e RUNNER_TOKEN="$token" \
        -e RUNNER_NAME="$name" \
        -e RUNNER_GROUP="" \
        -e LABELS="" \
        --name "$name" gha-sysbox-runner-custom:latest
}

function create_sysbox_gha_runner_org {
    name=$1
    org=$2
    pat=$3

    echo "Creating org runner for name=$name org=$org pat=$pat"

    create_sysbox_gha_runner_image

    docker run -d --restart=always \
        --runtime=sysbox-runc \
        -e RUNNER_SCOPE="org" \
        -e ORG_NAME="$org" \
        -e ACCESS_TOKEN="$pat" \
        -e RUNNER_NAME="$name" \
        -e RUNNER_GROUP="" \
        -e LABELS="" \
        --name "$name" gha-sysbox-runner-custom:latest
}

# Function to display help message
show_help() {
    echo "Usage: $0 <type> [additional arguments]"
    echo
    echo "<type>:"
    echo "  repo     Requires name org repo token"
    echo "  org      Requires name org [pat]"
    echo "           If pat is not provided, attempt to read it from github.pat file" 
    echo
    echo "Arguments:"
    echo "  name     Runner name"
    echo "  org      Organization name"
    echo "  repo     Repository name"
    echo "  pat      Personal access token with read/write access to self-hosted runners"

    echo "Flags:"
    echo "  -h, --help   Show this help message and exit"
    exit 0
}

function main() {
    # Check if no arguments are provided
    if [ $# -lt 1 ]; then
        echo "Error: No arguments provided. Use '-h' or '--help' for usage information."
        show_help
        exit 1
    fi

    # Check for help flags
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
    fi

    # Check the first argument type and validate argument count
    if [ "$1" == "org" ]; then
        if [ $# -lt 4 ]; then
            if [ -f "github.pat" ]; then
                PAT_VALUE=$(cat github.pat)
                echo "Using token from github.pat"
            else
                echo "Error: neither github.pat nor 'pat' argument is provided"
                show_help
                exit 1
            fi
        elif [ $# -eq 4 ]; then
            PAT_VALUE=$4
        else
            echo "Invalid arguments provided"
            show_help
            exit 1
        fi
        create_sysbox_gha_runner_org $2 $3 $PAT_VALUE
    elif [ "$1" == "repo" ]; then
        if [ $# -ne 5 ]; then
            echo "Error: invalid arguments provided. $#"
            show_help
            exit 1
        else
            create_sysbox_gha_runner_repo $2 $3 $4 $5
        fi
    else
        echo "Invalid arguments provided"
        show_help
    fi
}

main "$@"
