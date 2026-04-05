#!/bin/bash

set -euo pipefail

echo "Github Runner for $(hostname)"

COUNT=1
COVERAGE=0

while [[ $# -gt 0 ]]; do
    case $1 in
    -o | --owner)
        shift
        OWNER="$1"
        ;;
    -r | --repo)
        shift
        REPO="$1"
        ;;
    -t | --token)
        shift
        TOKEN="$1"
        ;;
    --type)
        shift
        TYPE="$1"
        ;;
    -c | --count)
        shift
        COUNT="$1"
        ;;
    --coverage)
        COVERAGE=1
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

if [[ -z "${OWNER:-}" || -z "${REPO:-}" || -z "${TOKEN:-}" ]]; then
    echo "Usage: $0 --owner <owner> --repo <repo> --token <token> --type <ci/cd> [--coverage]"
    exit 1
fi

TYPE="${TYPE:-}"
CONTAINER_NAME="gha-runner-$OWNER-$REPO"
if [[ -n "$TYPE" ]]; then
    CONTAINER_NAME="$CONTAINER_NAME-$TYPE"
fi

docker build -t gha-runner .

for ((i = 0; i < COUNT; i++)); do
    if [[ $i -eq 0 ]]; then
        CONTAINER_NAME_INSTANCE="$CONTAINER_NAME"
    else
        CONTAINER_NAME_INSTANCE="${CONTAINER_NAME}-${i}"
    fi
    if docker ps -a --format '{{.Names}}' | grep -q "$CONTAINER_NAME_INSTANCE"; then
        echo "Container $CONTAINER_NAME_INSTANCE already exists, removing it."
        docker rm -f "$CONTAINER_NAME_INSTANCE"
    fi

    docker_run_args=(
        -ti
        --name="$CONTAINER_NAME_INSTANCE"
        -d
        --restart=always
        -v /var/run/docker.sock:/var/run/docker.sock
    )

    if [[ "$COVERAGE" -eq 1 ]]; then
        docker_run_args+=(
            -v /data/nvme0n1/coverage_reports:/var/www/html/reports:rw
        )
    fi

    runner_args=(
        --owner "$OWNER"
        --repo "$REPO"
        --token "$TOKEN"
        --type "$TYPE"
        --instance-id "$i"
        --hostname "$(hostname)"
    )

    if [[ "$COVERAGE" -eq 1 ]]; then
        runner_args+=(--coverage)
    fi

    docker run "${docker_run_args[@]}" gha-runner "${runner_args[@]}"
done
