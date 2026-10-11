#!/usr/bin/env bash
# Sentry helpers — one project per site. Requires SENTRY_AUTH_TOKEN,
# SENTRY_ORG (org slug); SENTRY_TEAM defaults to the org slug.
set -euo pipefail
API=https://sentry.io/api/0
auth=(-H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" -H "Content-Type: application/json")
team=${SENTRY_TEAM:-$SENTRY_ORG}

case "${1:?command required}" in
  create-project)
    # create-project <name> — prints the project's DSN (the site's SENTRY_DSN).
    # "A project with this slug already exists" -> reuse it via get-dsn.
    name=${2:?project name}
    curl -sS "${auth[@]}" -X POST "$API/teams/$SENTRY_ORG/$team/projects/" \
      --data "{\"name\":\"$name\",\"platform\":\"ruby-rails\"}" | jq -r '.slug // ("ERROR: " + (.detail // tostring))'
    ;;
  get-dsn)
    # get-dsn <project-slug> — prints the public DSN.
    slug=${2:?project slug}
    curl -sS "${auth[@]}" "$API/projects/$SENTRY_ORG/$slug/keys/" \
      | jq -r '.[0].dsn.public // "ERROR: no keys found"' ;;
  list-projects)
    curl -sS "${auth[@]}" "$API/organizations/$SENTRY_ORG/projects/" | jq -r '.[].slug' ;;
  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
