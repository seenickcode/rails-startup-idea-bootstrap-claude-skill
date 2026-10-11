#!/usr/bin/env bash
# Cloudflare helpers for /webapp-bootstrap. Requires CLOUDFLARE_API_TOKEN,
# CLOUDFLARE_ACCOUNT_ID in env. Usage: cloudflare.sh <command> <args...>
set -euo pipefail

API=https://api.cloudflare.com/client/v4
auth=(-H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" -H "Content-Type: application/json")

cf() { curl -sS "${auth[@]}" "$@"; }

case "${1:?command required}" in
  check-domain)
    # Is the domain available to register? Prints availability JSON.
    domain=${2:?domain}
    cf "$API/accounts/$CLOUDFLARE_ACCOUNT_ID/registrar/domains/$domain" ;;

  buy-domain)
    # Attempt registration via Cloudflare Registrar API. Not all TLDs
    # supported; non-success output means: buy manually in the dashboard.
    domain=${2:?domain}
    cf -X POST "$API/accounts/$CLOUDFLARE_ACCOUNT_ID/registrar/domains/$domain" \
      --data '{"years":1,"auto_renew":true,"privacy":true}' ;;

  create-zone)
    domain=${2:?domain}
    cf -X POST "$API/zones" \
      --data "{\"name\":\"$domain\",\"account\":{\"id\":\"$CLOUDFLARE_ACCOUNT_ID\"},\"type\":\"full\"}" ;;

  zone-id)
    domain=${2:?domain}
    cf "$API/zones?name=$domain" | jq -r '.result[0].id // empty' ;;

  create-dns)
    # create-dns <zone_id> <name> <ip>  — proxied A record
    zone=${2:?zone id}; name=${3:?record name}; ip=${4:?ip}
    cf -X POST "$API/zones/$zone/dns_records" \
      --data "{\"type\":\"A\",\"name\":\"$name\",\"content\":\"$ip\",\"proxied\":true,\"ttl\":1}" ;;

  configure-ssl)
    # Full (strict) + always-use-HTTPS
    zone=${2:?zone id}
    cf -X PATCH "$API/zones/$zone/settings/ssl" --data '{"value":"strict"}'
    cf -X PATCH "$API/zones/$zone/settings/always_use_https" --data '{"value":"on"}' ;;

  create-bucket)
    # Per-site R2 bucket for Litestream backups. 10006 = already exists, fine.
    name=${2:?bucket name}
    cf -X POST "$API/accounts/$CLOUDFLARE_ACCOUNT_ID/r2/buckets" \
      --data "{\"name\":\"$name\"}" ;;

  nameservers)
    domain=${2:?domain}
    cf "$API/zones?name=$domain" | jq -r '.result[0].name_servers[]' ;;

  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
