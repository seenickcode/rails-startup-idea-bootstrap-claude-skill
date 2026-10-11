#!/usr/bin/env bash
# Verify Postmark actually SENT a message to a recipient recently — a
# positive delivery check, not just an app-side ack. Polls because the job
# queue + Postmark ingestion take a few seconds.
# Usage: verify-email.sh <recipient> [timeout_seconds]
# Requires POSTMARK_SERVER_TOKEN.
set -euo pipefail
recipient=${1:?recipient email}
timeout=${2:-90}
deadline=$(( $(date +%s) + timeout ))

# Filter client-side: Postmark's recipient query param mismatches
# plus-addressed emails (user+tag@...), so fetch recent and match with jq.
while [ "$(date +%s)" -lt "$deadline" ]; do
  status=$(curl -sS -H "X-Postmark-Server-Token: ${POSTMARK_SERVER_TOKEN}" \
    "https://api.postmarkapp.com/messages/outbound?count=30&offset=0" \
    | jq -r --arg r "$recipient" '[.Messages[] | select(.To[].Email == $r)][0].Status // empty')
  case "$status" in
    Sent) echo "EMAIL_OK: Postmark reports Sent to $recipient"; exit 0 ;;
    "")   ;; # not visible yet
    *)    echo "EMAIL_STATUS: $status (waiting for Sent)" ;;
  esac
  sleep 10
done
echo "EMAIL_FAIL: no Sent message to $recipient within ${timeout}s" >&2
exit 1
