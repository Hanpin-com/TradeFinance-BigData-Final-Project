#!/usr/bin/env bash
set -e
HOST="$1"
PORT="$2"
NAME="${3:-$HOST:$PORT}"
until nc -z "$HOST" "$PORT" >/dev/null 2>&1; do
  echo "Waiting for $NAME..."
  sleep 2
done
