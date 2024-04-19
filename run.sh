#!/bin/bash

set -euo pipefail

echo "Github Runner for $(hostname)"

docker build -t gha-runner .
docker run -ti --name=gha-runner-$1-$2 -d --restart=always -v /var/run/docker.sock:/var/run/docker.sock gha-runner $1 $2 $3 "$(hostname)"
