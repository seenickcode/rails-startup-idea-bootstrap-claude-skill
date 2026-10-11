#!/usr/bin/env bash
# Wait for DNS + TLS, then confirm the homepage serves "hello".
# Usage: health-check.sh <domain> [timeout_seconds]
set -euo pipefail
domain=${1:?domain}
timeout=${2:-600}
deadline=$(( $(date +%s) + timeout ))

echo "Waiting for https://$domain ..."
while [ "$(date +%s)" -lt "$deadline" ]; do
  if body=$(curl -fsS --max-time 10 "https://$domain" 2>/dev/null); then
    if echo "$body" | grep -qi 'hello'; then
      echo "HEALTH_OK: https://$domain is live and says hello"
      exit 0
    fi
    echo "Site responding but no 'hello' yet; retrying..."
  fi
  sleep 15
done
echo "HEALTH_FAIL: https://$domain not healthy after ${timeout}s" >&2
exit 1
