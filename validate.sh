#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
docker compose --profile tools run --rm validator
