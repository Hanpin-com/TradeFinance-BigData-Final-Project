#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
mkdir -p downloads
curl -fL https://jdbc.postgresql.org/download/postgresql-42.7.4.jar -o downloads/postgresql-42.7.4.jar
