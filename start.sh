#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
./build-base.sh
docker compose build --no-cache
docker compose up -d
