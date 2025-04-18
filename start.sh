#!/bin/bash

cd /home/docker/actions-runner || exit 1

ARCH=$(dpkg --print-architecture)
LABELS="linux,${ARCH}"

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
        if [[ -n "$TYPE" ]]; then
            LABELS="$LABELS,$TYPE"
        fi
        ;;
    -h | --hostname)
        shift
        HOSTNAME="$1"
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

RUNNER_NAME="runner-$ARCH-$HOSTNAME"
if [[ -n "${TYPE:-}" ]]; then
    RUNNER_NAME="$RUNNER_NAME-$TYPE"
fi

./config.sh --url https://github.com/"$OWNER"/"$REPO" --token "$TOKEN" --name "$RUNNER_NAME" --replace --labels "$LABELS" --unattended

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token "$TOKEN"
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh &
wait $!
