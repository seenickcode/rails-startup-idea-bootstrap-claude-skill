#!/usr/bin/env bash
# sender.net helpers. Requires SENDER_API_TOKEN.
set -euo pipefail
API=https://api.sender.net/v2
auth=(-H "Authorization: Bearer ${SENDER_API_TOKEN}" -H "Content-Type: application/json" -H "Accept: application/json")

case "${1:?command required}" in
  create-group)
    # Prints the new group's id (SENDER_GROUP_ID for the site).
    title=${2:?group title}
    curl -sS "${auth[@]}" -X POST "$API/groups" --data "{\"title\":\"$title\"}" | jq -r '.data.id' ;;
  list-groups)
    curl -sS "${auth[@]}" "$API/groups" | jq -r '.data[] | "\(.id)\t\(.title)"' ;;
  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
