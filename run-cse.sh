#!/bin/bash

set -euo pipefail

echo "Github Runner for CSE on $(hostname)"

TYPE="*"
COUNT=1
COVERAGE=0

while [[ $# -gt 0 ]]; do
    case $1 in
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

if [[ -z "${TOKEN:-}" ]]; then
    echo "Usage: $0 --token <token> --type <*/ci/cd> [--coverage]"
    exit 1
fi

run_sh_args=()
if [[ "$COVERAGE" -eq 1 ]]; then
    run_sh_args+=(--coverage)
fi

if [[ "${TYPE}" == "ci" || "${TYPE}" == "*" ]]; then
    ./run.sh --owner tidbcloud --repo cloud-storage-engine --token "$TOKEN" --type ci --count "$COUNT" "${run_sh_args[@]}"
fi
if [[ "${TYPE}" == "cd" || "${TYPE}" == "*" ]]; then
    ./run.sh --owner tidbcloud --repo cloud-storage-engine --token "$TOKEN" --type cd "${run_sh_args[@]}"
fi
