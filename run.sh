#!/bin/bash

set -euo pipefail

echo "Github Runner for $(hostname)"

COUNT=1
CPUS=8

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
    --cpus)
        if [[ $# -lt 2 || "$2" == -* ]]; then
            echo "--cpus requires a CPU limit" >&2
            exit 1
        fi
        shift
        CPUS="$1"
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

if [[ -z "${OWNER:-}" || -z "${REPO:-}" || -z "${TOKEN:-}" ]]; then
    echo "Usage: $0 --owner <owner> --repo <repo> --token <token> --type <ci/cd> [--count <count>] [--cpus <limit> (CI only, default: 8)]"
    exit 1
fi

TYPE="${TYPE:-}"
if [[ "$TYPE" == "ci" ]] && [[ ! "$CPUS" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ || ! "$CPUS" =~ [1-9] ]]; then
    echo "--cpus must be a positive number" >&2
    exit 1
fi
if [[ "$TYPE" == "ci" ]] && [[ ! "$OWNER" =~ ^[a-zA-Z0-9-]+$ || ! "$REPO" =~ ^[a-zA-Z0-9_.-]+$ || "$REPO" == "." || "$REPO" == ".." ]]; then
    echo "Invalid GitHub owner or repository name" >&2
    exit 1
fi
CONTAINER_NAME="gha-runner-$OWNER-$REPO"
if [[ -n "$TYPE" ]]; then
    CONTAINER_NAME="$CONTAINER_NAME-$TYPE"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
docker build -t gha-runner "$script_dir"

ci_run_args=()
if [[ "$TYPE" == "ci" ]]; then
    cache_rel=".mbx-cache/$OWNER/$REPO"
    (umask 027 && mkdir -p -- "$script_dir/$cache_rel")
    cache_dir="$(cd -- "$script_dir/$cache_rel" && pwd -P)"
    cache_mount="type=bind,source=$cache_dir,target=/opt/mbx-cache"

    # Grant the image's runner group access without changing the host owner's UID.
    docker run --rm --user root --entrypoint /bin/sh \
        --mount "$cache_mount" gha-runner -ec '
            runner_can_use_cache() {
                runuser -u docker -- sh -c "test -r /opt/mbx-cache && test -w /opt/mbx-cache && test -x /opt/mbx-cache"
            }
            if ! runner_can_use_cache; then
                chgrp docker /opt/mbx-cache
                chmod g+rwx /opt/mbx-cache
                runner_can_use_cache
            fi
        '

    ci_run_args=(--cpus="$CPUS" --mount "$cache_mount" --env MBX_CACHE_DIR=/opt/mbx-cache)
fi

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
    docker_run_args+=("${ci_run_args[@]}")

    runner_args=(
        --owner "$OWNER"
        --repo "$REPO"
        --token "$TOKEN"
        --type "$TYPE"
        --instance-id "$i"
        --hostname "$(hostname)"
    )

    docker run "${docker_run_args[@]}" gha-runner "${runner_args[@]}"
done
