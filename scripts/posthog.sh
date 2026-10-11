#!/usr/bin/env bash
# PostHog helpers — one project per site. Requires POSTHOG_PERSONAL_API_KEY
# (phx_..., NOT a phc_ project key) and POSTHOG_HOST.
# Note: multiple projects require a paid PostHog Cloud plan.
set -euo pipefail
# POSTHOG_HOST is the ingestion host (eu.i.posthog.com); the REST API lives
# on the app host without the ".i." segment.
API="$(echo "${POSTHOG_HOST:?}" | sed 's|\.i\.posthog\.com|.posthog.com|')/api"
auth=(-H "Authorization: Bearer ${POSTHOG_PERSONAL_API_KEY}" -H "Content-Type: application/json")

case "${1:?command required}" in
  create-project)
    # Prints the new project's phc_ token (the site's POSTHOG_API_KEY).
    name=${2:?project name}
    curl -sS "${auth[@]}" -X POST "$API/organizations/@current/projects/" \
      --data "{\"name\":\"$name\"}" | jq -r '.api_token // ("ERROR: " + (.detail // .type // "unknown"))' ;;
  list-projects)
    curl -sS "${auth[@]}" "$API/organizations/@current/projects/" \
      | jq -r '.results[] | "\(.id)\t\(.name)\t\(.api_token)"' ;;
  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
