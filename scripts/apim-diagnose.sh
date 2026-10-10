#!/usr/bin/env bash
# Prints what API Manager actually holds for the API Product, and probes its gateway URLs.
# Run inside the apim-init container:   docker compose run --rm --entrypoint bash apim-init scripts/apim-diagnose.sh
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && . ./.env && set +a
APIM_URL="${APIM_URL:-https://localhost:9443}"; GATEWAY_URL="${GATEWAY_URL:-https://localhost:8243}"
DCR=$(curl -sk -u "$APIM_ADMIN_USER:$APIM_ADMIN_PASSWORD" -H 'Content-Type: application/json' \
  -d "{\"callbackUrl\":\"https://localhost\",\"clientName\":\"jamii_diagnose\",\"owner\":\"$APIM_ADMIN_USER\",\"grantType\":\"password client_credentials\",\"saasApp\":true}" \
  "$APIM_URL/client-registration/v0.17/register")
TOKEN=$(curl -sk -u "$(echo "$DCR" | jq -r .clientId):$(echo "$DCR" | jq -r .clientSecret)" \
  -d "grant_type=password&username=$APIM_ADMIN_USER&password=$APIM_ADMIN_PASSWORD&scope=apim:api_view apim:subscribe" \
  "$APIM_URL/oauth2/token" | jq -r .access_token)
H=(-H "Authorization: Bearer $TOKEN")
echo "== Publisher: product"
PID=$(curl -sk "${H[@]}" "$APIM_URL/api/am/publisher/v4/api-products?limit=50" | jq -r '.list[] | select(.name=="JamiiRetailBanking") | .id' | head -1)
P=$(curl -sk "${H[@]}" "$APIM_URL/api/am/publisher/v4/api-products/$PID")
echo "$P" | jq '{id, name, context, version, state, lifeCycleStatus, visibility, policies, securityScheme, gatewayVendor, apis: [.apis[] | {name, version, operations: [.operations[] | "\(.verb) \(.target)"]}]}'
echo "== Publisher: product deployments"
curl -sk "${H[@]}" "$APIM_URL/api/am/publisher/v4/api-products/$PID/deployments" | jq '.' 2>/dev/null | head -30
echo "== Developer Portal: everything listed (name / type / version / context)"
curl -sk "${H[@]}" "$APIM_URL/api/am/devportal/v3/apis?limit=100" | jq -r '.list[] | "\(.name)  \(.type)  \(.version)  \(.context)"'
echo "== Gateway probes (with the demo app token)"
. "${DEMO_ENV_FILE:-.apim-demo.env}"
GATEWAY_URL="${GATEWAY_URL_OVERRIDE:-https://apim:8243}"   # inside Docker, not the host URL from .apim-demo.env
APPTOKEN=$(curl -sk -u "$PRODUCT_CONSUMER_KEY:$PRODUCT_CONSUMER_SECRET" -d grant_type=client_credentials "$APIM_URL/oauth2/token" | jq -r .access_token)
CTX=$(echo "$P" | jq -r .context); VER=$(echo "$P" | jq -r '.version // "1.0.0"')
for u in "$CTX/0123456789/balance" "$CTX/$VER/0123456789/balance" "${CTX%/$VER}/$VER/0123456789/balance" "${CTX%/$VER}/0123456789/balance"; do
  code=$(curl -sk -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $APPTOKEN" "$GATEWAY_URL$u")
  echo "   $code  $u"
done
