#!/usr/bin/env bash
# Stripe helpers. Requires STRIPE_SECRET_KEY (restricted key with write on
# Checkout Sessions, Products, Prices, Webhook Endpoints).
set -euo pipefail
API=https://api.stripe.com/v1

case "${1:?command required}" in
  create-webhook)
    # Prints the signing secret (whsec_..., shown only at creation).
    domain=${2:?domain}
    curl -sS -u "${STRIPE_SECRET_KEY}:" "$API/webhook_endpoints" \
      -d "url=https://$domain/webhooks/stripe" \
      -d "enabled_events[]=checkout.session.completed" \
      -d "enabled_events[]=checkout.session.async_payment_succeeded" \
      | jq -r '.secret // ("ERROR: " + (.error.message // "unknown"))' ;;

  create-product)
    # create-product <name> <amount_cents> [currency] — prints the price id.
    name=${2:?product name}; amount=${3:?amount cents}; currency=${4:-usd}
    curl -sS -u "${STRIPE_SECRET_KEY}:" "$API/prices" \
      -d "unit_amount=$amount" \
      -d "currency=$currency" \
      -d "product_data[name]=$name" \
      | jq -r '.id // ("ERROR: " + (.error.message // "unknown"))' ;;

  list-prices)
    curl -sS -u "${STRIPE_SECRET_KEY}:" "$API/prices?active=true&limit=100&expand[]=data.product" \
      | jq -r '.data[] | "\(.id)\t\(.unit_amount) \(.currency)\t\(.product.name)"' ;;

  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
