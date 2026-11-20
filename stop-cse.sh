#!/bin/bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: $0" >&2
    exit 2
fi

name_prefix="gha-runner-tidbcloud-cloud-storage-engine"

# Verify the owner and repo arguments set by run.sh without printing the token.
repo_matches='{{- with .Config.Cmd -}}
    {{- if ge (len .) 4 -}}
        {{- and (eq (index . 0) "--owner") (eq (index . 1) "tidbcloud")
                (eq (index . 2) "--repo") (eq (index . 3) "cloud-storage-engine") -}}
    {{- end -}}
{{- end -}}'

running=$(docker ps --no-trunc --format '{{.ID}} {{.Names}}')
runner_ids=()
while read -r id name; do
    case "$name" in
    "$name_prefix" | "$name_prefix"-*)
        matches=$(docker inspect --type container --format "$repo_matches" "$id")
        if [[ "$matches" == "true" ]]; then
            runner_ids+=("$id")
        fi
        ;;
    esac
done <<< "$running"

if [[ ${#runner_ids[@]} -eq 0 ]]; then
    echo "No running cloud-storage-engine runners found."
    exit 0
fi

docker stop --timeout 30 "${runner_ids[@]}"
