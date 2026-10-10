#!/usr/bin/env bash
# Experiment: does an API Product created via REST with an explicit version "1" (as the Publisher UI does) route and authenticate?
# Creates a throwaway product (Balance operation only), deploys it, subscribes jamii-channel,
# calls it, prints the result, then deletes it. Does not touch JamiiRetailBanking.
# Run:  docker compose run --rm --no-deps --entrypoint bash apim-init scripts/apim-product-test.sh
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] && set -a && . ./.env && set +a
. ./.apim-demo.env
APIM_URL="${APIM_URL:-https://apim:9443}"; GW="${GATEWAY_URL_OVERRIDE:-https://apim:8243}"
PUB="$APIM_URL/api/am/publisher/v4"; DEV="$APIM_URL/api/am/devportal/v3"
DCR=$(curl -sk -u "$APIM_ADMIN_USER:$APIM_ADMIN_PASSWORD" -H 'Content-Type: application/json' \
  -d "{\"callbackUrl\":\"https://localhost\",\"clientName\":\"jamii_product_test\",\"owner\":\"$APIM_ADMIN_USER\",\"grantType\":\"password client_credentials\",\"saasApp\":true}" \
  "$APIM_URL/client-registration/v0.17/register")
TOKEN=$(curl -sk -u "$(echo "$DCR" | jq -r .clientId):$(echo "$DCR" | jq -r .clientSecret)" \
  -d "grant_type=password&username=$APIM_ADMIN_USER&password=$APIM_ADMIN_PASSWORD&scope=apim:api_view apim:api_create apim:api_publish apim:api_manage apim:subscribe apim:app_manage apim:sub_manage" \
  "$APIM_URL/oauth2/token" | jq -r .access_token)
H=(-H "Authorization: Bearer $TOKEN"); J=(-H 'Content-Type: application/json')

BAL=$(curl -sk "${H[@]}" "$PUB/apis?limit=200" | jq -r '.list[] | select(.name=="JamiiAccountBalance") | .id' | head -1)
echo "== creating JamiiProductTest with context /jamii/product-test and version 1 (as the Publisher does)"
BODY=$(jq -nc --arg id "$BAL" '{name:"JamiiProductTest", context:"/jamii/product-test", version:"1", isDefaultVersion:true, description:"throwaway test", policies:["Gold"],
  securityScheme:["oauth2","oauth_basic_auth_api_key_mandatory"], transport:["https"], visibility:"PUBLIC", gatewayVendor:"wso2",
  apis:[{apiId:$id, operations:[{target:"/{accountNumber}/balance", verb:"GET"}]}]}')
RESP=$(curl -sk "${H[@]}" "${J[@]}" -X POST "$PUB/api-products" --data "$BODY")
PID=$(echo "$RESP" | jq -r .id)
[[ $PID == null || -z $PID ]] && { echo "create failed: $RESP"; exit 1; }
echo "   stored context: $(echo "$RESP" | jq -r .context)   version: $(echo "$RESP" | jq -r .version)"
REV=$(curl -sk "${H[@]}" "${J[@]}" -X POST "$PUB/api-products/$PID/revisions" --data '{"description":"test"}' | jq -r .id)
curl -sk "${H[@]}" "${J[@]}" -X POST "$PUB/api-products/$PID/deploy-revision?revisionId=$REV" \
  --data '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]' >/dev/null
curl -sk "${H[@]}" -X POST "$PUB/api-products/change-lifecycle?action=Publish&apiProductId=$PID" >/dev/null
echo "== subscribing jamii-channel"
APP=$(curl -sk "${H[@]}" "$DEV/applications?limit=100" | jq -r '.list[] | select(.name=="jamii-channel") | .applicationId' | head -1)
sleep 10
SUB=$(curl -sk "${H[@]}" "${J[@]}" -X POST "$DEV/subscriptions" --data "{\"applicationId\":\"$APP\",\"apiId\":\"$PID\",\"throttlingPolicy\":\"Gold\"}" | jq -r .subscriptionId)
echo "   subscription: $SUB"
PT=$(curl -sk -u "$PRODUCT_CONSUMER_KEY:$PRODUCT_CONSUMER_SECRET" -d grant_type=client_credentials "$APIM_URL/oauth2/token" | jq -r .access_token)
echo "== calling (waits up to 60 s for deployment)"
for i in $(seq 1 12); do
  for u in "/jamii/product-test/0123456789/balance" "/jamii/product-test/1/0123456789/balance"; do
    out=$(curl -sk -w ' HTTP %{http_code}' -H "Authorization: Bearer $PT" "$GW$u")
    code=${out##* }
    [[ $code != 404 ]] && FOUND=1
    [[ $code != 404 || $i == 12 ]] && echo "   $u -> $out" | cut -c1-220
  done
  [[ -n ${FOUND:-} ]] && break; sleep 5
done
[[ -z ${FOUND:-} ]] && echo "   still 404 on both URLs"
echo "== cleaning up"
[[ -n $SUB && $SUB != null ]] && curl -sk "${H[@]}" -X DELETE "$DEV/subscriptions/$SUB" >/dev/null
sleep 3
curl -sk "${H[@]}" -X DELETE "$PUB/api-products/$PID/deployments?revisionId=$REV" >/dev/null 2>&1
code=$(curl -sk -o /dev/null -w '%{http_code}' "${H[@]}" -X DELETE "$PUB/api-products/$PID")
echo "   test product deleted (HTTP $code)"