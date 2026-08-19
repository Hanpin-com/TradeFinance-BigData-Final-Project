#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
docker build -t bigdata-hadoop-base:local -f docker/base/Dockerfile .
