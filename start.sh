#!/bin/bash

cd /home/docker/actions-runner || exit 1

ARCH=`dpkg --print-architecture`

./config.sh --url https://github.com/$1/$2 --token $3 --name runner-${ARCH}-"$4" --replace --labels linux,${ARCH} --unattended

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token ${REG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
