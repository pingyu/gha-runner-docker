#!/bin/bash

set -euo pipefail

echo "Github Runner for $(hostname)"

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
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

if [[ -z "${OWNER:-}" || -z "${REPO:-}" || -z "${TOKEN:-}" ]]; then
    echo "Usage: $0 --owner <owner> --repo <repo> --token <token> --type <ci/cd>"
    exit 1
fi

TYPE="${TYPE:-}"
CONTAINER_NAME="gha-runner-$OWNER-$REPO"
if [[ -n "$TYPE" ]]; then
    CONTAINER_NAME="$CONTAINER_NAME-$TYPE"
fi

docker build -t gha-runner .
docker run -ti --name="$CONTAINER_NAME" -d --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock gha-runner \
    --owner "$OWNER" --repo "$REPO" --token "$TOKEN" --type "$TYPE" --hostname "$(hostname)"
