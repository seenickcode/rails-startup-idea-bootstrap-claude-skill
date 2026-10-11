#!/usr/bin/env bash
# Postmark domain setup (Account API). Requires POSTMARK_ACCOUNT_TOKEN.
# Without these DNS records, sign-in emails silently fail — nobody can log in.
set -euo pipefail
API=https://api.postmarkapp.com
auth=(-H "X-Postmark-Account-Token: ${POSTMARK_ACCOUNT_TOKEN}" -H "Accept: application/json" -H "Content-Type: application/json")

case "${1:?command required}" in
  add-domain)
    # Prints the domain object incl. DKIMPendingHost/DKIMPendingTextValue and
    # ReturnPathDomain values needed for Cloudflare DNS.
    domain=${2:?domain}
    curl -sS "${auth[@]}" -X POST "$API/domains" \
      --data "{\"Name\":\"$domain\",\"ReturnPathDomain\":\"pm-bounces.$domain\"}" ;;

  get-domain)
    id=${2:?domain id}
    curl -sS "${auth[@]}" "$API/domains/$id" ;;

  verify-dkim)
    id=${2:?domain id}
    curl -sS "${auth[@]}" -X PUT "$API/domains/$id/verifyDkim" ;;

  verify-return-path)
    id=${2:?domain id}
    curl -sS "${auth[@]}" -X PUT "$API/domains/$id/verifyReturnPath" ;;

  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
