#!/usr/bin/env bash
# Member 1 – YARN visibility checks (screenshot these)
set -euo pipefail

echo "=== YARN nodes ==="
yarn node -list || true

echo "=== YARN apps (recent) ==="
yarn application -list || true

echo "=== RM web UI hint ==="
echo "Open ResourceManager UI: http://localhost:8088"
echo "Screenshot cluster metrics / applications page for Member 1 evidence."
