#!/bin/bash

set -euo pipefail

echo "Github Runner for CSE on $(hostname)"

TYPE="ci"
COUNT=4
CPUS=8

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

if [[ -z "${TOKEN:-}" ]]; then
    echo "Usage: $0 --token <token> [--type <*/ci/cd>] [--count <count>] [--cpus <limit>]"
    echo "Defaults: --type ci, --count 4, --cpus 8 (count and CPU limit apply to CI only)"
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "${TYPE}" == "ci" || "${TYPE}" == "*" ]]; then
    "$script_dir/run.sh" --owner tidbcloud --repo cloud-storage-engine --token "$TOKEN" --type ci --count "$COUNT" --cpus "$CPUS"
fi
if [[ "${TYPE}" == "cd" || "${TYPE}" == "*" ]]; then
    "$script_dir/run.sh" --owner tidbcloud --repo cloud-storage-engine --token "$TOKEN" --type cd
fi
