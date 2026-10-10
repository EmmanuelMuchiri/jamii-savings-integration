#!/usr/bin/env bash
# Publishes everything to API Manager, in dependency order, and is safe to re-run:
#   1. custom subscription tier LoanCheck10PerMin           (Admin REST API)
#   2. the three APIs, with policy, tile and dev endpoints   (apictl)
#   3. the Jamii Retail Banking API Product                  (Publisher REST API)
#   4. demo apps: jamii-mobile (individual APIs, API key) and jamii-channel (API Product)  (Developer Portal REST API)
# Writes the demo credentials to .apim-demo.env (gitignored) for gateway-check.sh and Postman.
#
# Needs: curl, jq, apictl 4.4 on PATH.   Usage: scripts/apim-bootstrap.sh [dev|prod]
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_NAME="${1:-dev}"
[[ -f .env ]] && set -a && . ./.env && set +a
: "${APIM_ADMIN_USER:?set APIM_ADMIN_USER in .env}"; : "${APIM_ADMIN_PASSWORD:?set APIM_ADMIN_PASSWORD in .env}"
APIM_URL="${APIM_URL:-https://localhost:9443}"
GATEWAY_URL="${GATEWAY_URL:-https://localhost:8243}"
PUBLIC_APIM_URL="${PUBLIC_APIM_URL:-$APIM_URL}"          # what the host should use (differs inside Docker)
PUBLIC_GATEWAY_URL="${PUBLIC_GATEWAY_URL:-$GATEWAY_URL}"
for tool in curl jq apictl; do command -v $tool >/dev/null || { echo "ERROR: $tool not found on PATH"; exit 1; }; done

step() { echo; echo "== $*"; }
ok()   { echo "   OK   $*"; }
warn() { echo "   WARN $*"; }

# --- REST helper: call METHOD URL [curl args...]; prints body; fails loudly on HTTP >= 400 ---
rest() {
  local method=$1 url=$2; shift 2
  local out code
  out=$(curl -sk -X "$method" "$url" -H "Authorization: Bearer $TOKEN" -w $'\n%{http_code}' "$@")
  code=${out##*$'\n'}; out=${out%$'\n'*}
  if [[ $code -ge 400 ]]; then echo "ERROR: $method $url -> HTTP $code" >&2; echo "$out" >&2; return 1; fi
  echo "$out"
}

# --- Search lookups retry: API Manager indexes newly imported APIs in the background,
#     so a search straight after an import can come back empty for a few seconds. ---
find_id() { # base-url name [version] -> prints id (waits up to 2 minutes for the index)
  local base=$1 n=$2 v=${3:-} id="" i
  for i in $(seq 1 24); do
    id=$(rest GET "$base/apis?query=name:$n&limit=50" | jq -r --arg n "$n" --arg v "$v" \
         '.list[] | select(.name==$n and ($v=="" or .version==$v)) | .id' | head -1)
    # Fallback: products are not always returned by a name search, so list everything and filter
    [[ -z $id ]] && id=$(rest GET "$base/apis?limit=500" | jq -r --arg n "$n" --arg v "$v" \
         '.list[] | select(.name==$n and ($v=="" or .version==$v)) | .id' | head -1)
    [[ -n $id ]] && { echo "$id"; return 0; }
    sleep 5
  done
  return 1
}

step "Waiting for API Manager at $APIM_URL"
for i in $(seq 1 120); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' "$APIM_URL/api/am/devportal/v3/apis" || true)
  [[ $code == 200 ]] && break; sleep 5
  [[ $i == 120 ]] && { echo "ERROR: API Manager not ready after 10 minutes"; exit 1; }
done; ok "API Manager is up"

step "Getting an admin token (dynamic client registration + password grant)"
DCR=$(curl -sk -u "$APIM_ADMIN_USER:$APIM_ADMIN_PASSWORD" -H 'Content-Type: application/json' \
  -d "{\"callbackUrl\":\"https://localhost\",\"clientName\":\"jamii_bootstrap\",\"owner\":\"$APIM_ADMIN_USER\",\"grantType\":\"password refresh_token client_credentials\",\"saasApp\":true}" \
  "$APIM_URL/client-registration/v0.17/register")
CID=$(echo "$DCR" | jq -r .clientId); CSEC=$(echo "$DCR" | jq -r .clientSecret)
[[ $CID != null && -n $CID ]] || { echo "ERROR: client registration failed: $DCR"; exit 1; }
SCOPES="apim:admin apim:tier_view apim:tier_manage apim:api_view apim:api_create apim:api_publish apim:api_manage apim:api_product_import_export apim:subscribe apim:app_manage apim:sub_manage apim:api_key"
TOKEN=$(curl -sk -u "$CID:$CSEC" -d "grant_type=password&username=$APIM_ADMIN_USER&password=$APIM_ADMIN_PASSWORD&scope=$SCOPES" \
  "$APIM_URL/oauth2/token" | jq -r .access_token)
[[ $TOKEN != null && -n $TOKEN ]] || { echo "ERROR: could not get an admin token"; exit 1; }
ok "token acquired"

step "1/4 Subscription tier LoanCheck10PerMin"
TIERS=$(rest GET "$APIM_URL/api/am/admin/v4/throttling/policies/subscription")
if echo "$TIERS" | jq -e '.list[] | select(.policyName=="LoanCheck10PerMin")' >/dev/null; then
  ok "already exists"
else
  rest POST "$APIM_URL/api/am/admin/v4/throttling/policies/subscription" -H 'Content-Type: application/json' \
    --data @apim/throttling/LoanCheck10PerMin.json >/dev/null
  ok "created (10 requests per minute)"
fi

step "2/4 APIs via apictl (environment: $ENV_NAME)"
apictl add env "$ENV_NAME" --apim "$APIM_URL" >/dev/null 2>&1 || true
apictl login "$ENV_NAME" -u "$APIM_ADMIN_USER" -p "$APIM_ADMIN_PASSWORD" -k >/dev/null
for project in JamiiAccountBalance-v1 JamiiCustomerProfile-v1 JamiiLoanEligibility-v1; do
  name=${project%-v1}
  apictl import api -f "apim/apis/$project" -e "$ENV_NAME" --params "apim/params/$ENV_NAME/$name.yaml" \
    --update --rotate-revision --preserve-provider=false -k
  ok "$name imported, deployed to the Default gateway and published"
done

step "3/4 API Product JamiiRetailBanking"
PUB="$APIM_URL/api/am/publisher/v4"
BODY=$(jq -c 'del(.apis)' apim/products/JamiiRetailBanking/product.json)
APIS_JSON="[]"
for row in $(jq -c '.apis[]' apim/products/JamiiRetailBanking/product.json); do
  n=$(echo "$row" | jq -r .name); v=$(echo "$row" | jq -r .version)
  id=$(find_id "$PUB" "$n" "$v") || { echo "ERROR: API $n $v not found in the Publisher after 2 minutes"; exit 1; }
  ok "found $n $v"
  APIS_JSON=$(echo "$APIS_JSON" | jq -c --arg id "$id" --argjson ops "$(echo "$row" | jq -c .operations)" '. + [{apiId:$id, operations:$ops}]')
done
BODY=$(echo "$BODY" | jq -c --argjson apis "$APIS_JSON" '. + {apis:$apis}')
# Look the product up in the full list, not the search index (which lags after changes),
# so an existing product is always updated rather than created twice.
PID=$(rest GET "$PUB/api-products?limit=200" | jq -r '.list[] | select(.name=="JamiiRetailBanking") | .id' | head -1)
# A product's version cannot be changed in place. If an older version exists (e.g. 1.0.0 from an
# earlier run, which is not served as the default version), remove its subscriptions and recreate it.
WANT_VERSION=$(jq -r .version apim/products/JamiiRetailBanking/product.json)
if [[ -n $PID ]]; then
  HAVE_VERSION=$(rest GET "$PUB/api-products/$PID" | jq -r .version)
  if [[ $HAVE_VERSION != "$WANT_VERSION" ]]; then
    warn "existing product is version $HAVE_VERSION, expected $WANT_VERSION: recreating it"
    DEVP="$APIM_URL/api/am/devportal/v3"
    for sid in $(rest GET "$DEVP/subscriptions?apiId=$PID&limit=100" | jq -r '.list[]?.subscriptionId'); do
      rest DELETE "$DEVP/subscriptions/$sid" >/dev/null && ok "  removed subscription $sid"
    done
    sleep 3
    rest DELETE "$PUB/api-products/$PID" >/dev/null && ok "  old product deleted"
    PID=""
  fi
fi
if [[ -n $PID ]]; then
  CURRENT=$(rest GET "$PUB/api-products/$PID")
  rest PUT "$PUB/api-products/$PID" -H 'Content-Type: application/json' --data "$(echo "$CURRENT" | jq -c --argjson b "$BODY" '. + $b')" >/dev/null
  ok "updated ($PID)"
else
  PID=$(rest POST "$PUB/api-products" -H 'Content-Type: application/json' --data "$BODY" | jq -r .id)
  ok "created ($PID)"
fi
rest PUT "$PUB/api-products/$PID/thumbnail" -F "file=@apim/products/JamiiRetailBanking/Image/icon.png" >/dev/null && ok "tile uploaded"
REVS=$(rest GET "$PUB/api-products/$PID/revisions")
if [[ $(echo "$REVS" | jq '.count // (.list|length)') -ge 5 ]]; then
  OLD=$(echo "$REVS" | jq -r '[.list[] | select((.deploymentInfo // []) | length == 0)] | sort_by(.createdTime) | .[0].id // empty')
  [[ -n $OLD ]] && rest DELETE "$PUB/api-products/$PID/revisions/$OLD" >/dev/null && ok "oldest undeployed revision removed"
fi
REV=$(rest POST "$PUB/api-products/$PID/revisions" -H 'Content-Type: application/json' --data '{"description":"bootstrap"}' | jq -r .id)
rest POST "$PUB/api-products/$PID/deploy-revision?revisionId=$REV" -H 'Content-Type: application/json' \
  --data '[{"name":"Default","vhost":"localhost","displayOnDevportal":true}]' >/dev/null
ok "revision $REV deployed to the Default gateway"
STATE=$(rest GET "$PUB/api-products/$PID" | jq -r '.state // .lifeCycleStatus // "unknown"')
if [[ $STATE != PUBLISHED ]]; then
  if rest POST "$PUB/api-products/change-lifecycle?action=Publish&apiProductId=$PID" >/dev/null 2>&1; then ok "published"
  else warn "state is $STATE; publish it from the Publisher (Lifecycle) if it is not visible in the Developer Portal"; fi
else ok "already published"; fi
PRODUCT_CONTEXT=$(rest GET "$PUB/api-products/$PID" | jq -r .context)

step "4/4 Demo applications"
DEV="$APIM_URL/api/am/devportal/v3"
# An application must use either the API Product or the individual APIs, not both: with both,
# the gateway cannot pick a subscription and fails with 900900. So there are two demo apps.
ensure_app() { # name description -> prints applicationId
  local name=$1 desc=$2 id
  id=$(rest GET "$DEV/applications?limit=100" | jq -r --arg n "$name" '.list[] | select(.name==$n) | .applicationId' | head -1)
  if [[ -z $id ]]; then
    id=$(rest POST "$DEV/applications" -H 'Content-Type: application/json' \
      --data "{\"name\":\"$name\",\"throttlingPolicy\":\"Unlimited\",\"description\":\"$desc\",\"tokenType\":\"JWT\"}" | jq -r .applicationId)
    ok "application $name created ($id)" >&2
  else ok "application $name exists ($id)" >&2; fi
  echo "$id"
}
subscribe() { # app-id api-name tier
  local app=$1 n=$2 tier=$3 id subs
  id=$(find_id "$DEV" "$n") || { warn "$n not visible in the Developer Portal after 2 minutes"; return 0; }
  subs=$(rest GET "$DEV/subscriptions?applicationId=$app&limit=100")
  if echo "$subs" | jq -e --arg id "$id" '.list[] | select(.apiId==$id)' >/dev/null; then ok "  already subscribed to $n"; return 0; fi
  if rest POST "$DEV/subscriptions" -H 'Content-Type: application/json' \
       --data "{\"applicationId\":\"$app\",\"apiId\":\"$id\",\"throttlingPolicy\":\"$tier\"}" >/dev/null; then ok "  subscribed to $n ($tier)"
  else warn "  could not subscribe to $n"; fi
}
unsubscribe() { # app-id api-name   (removes a subscription if present)
  local app=$1 n=$2 id sid
  id=$(find_id "$DEV" "$n") || return 0
  sid=$(rest GET "$DEV/subscriptions?applicationId=$app&limit=100" | jq -r --arg id "$id" '.list[] | select(.apiId==$id) | .subscriptionId' | head -1)
  [[ -n $sid ]] && rest DELETE "$DEV/subscriptions/$sid" >/dev/null && ok "  removed subscription to $n"
  return 0
}
app_keys() { # app-id -> prints "consumerKey consumerSecret"
  local app=$1 keys ck cs
  keys=$(rest GET "$DEV/applications/$app/oauth-keys")
  ck=$(echo "$keys" | jq -r '.list[] | select(.keyType=="PRODUCTION") | .consumerKey' | head -1)
  if [[ -z $ck || $ck == null ]]; then
    keys=$(rest POST "$DEV/applications/$app/generate-keys" -H 'Content-Type: application/json' \
      --data '{"keyType":"PRODUCTION","keyManager":"Resident Key Manager","grantTypesToBeSupported":["client_credentials","password","refresh_token"],"callbackUrl":"","scopes":["default"],"validityTime":3600,"additionalProperties":{}}')
    ck=$(echo "$keys" | jq -r .consumerKey); cs=$(echo "$keys" | jq -r .consumerSecret)
  else
    cs=$(echo "$keys" | jq -r '.list[] | select(.keyType=="PRODUCTION") | .consumerSecret' | head -1)
  fi
  echo "$ck $cs"
}

# jamii-mobile: individual APIs (partner-style access, API key, Loan tier)
APP=$(ensure_app jamii-mobile "Partner-style access to the individual Jamii APIs")
unsubscribe "$APP" JamiiRetailBanking
subscribe "$APP" JamiiAccountBalance Gold
subscribe "$APP" JamiiCustomerProfile Gold
subscribe "$APP" JamiiLoanEligibility LoanCheck10PerMin
read -r CK CS <<< "$(app_keys "$APP")"; ok "  OAuth keys ready"
APIKEY=$(rest POST "$DEV/applications/$APP/api-keys/PRODUCTION/generate" -H 'Content-Type: application/json' \
  --data '{"validityPeriod":-1,"additionalProperties":{}}' | jq -r .apikey)
ok "  API key generated"

# jamii-channel: the API Product only (one subscription, all three APIs)
CHAPP=$(ensure_app jamii-channel "Jamii channel app: Retail Banking product (one subscription, all three APIs)")
subscribe "$CHAPP" JamiiRetailBanking Gold
read -r PCK PCS <<< "$(app_keys "$CHAPP")"; ok "  OAuth keys ready"

cat > .apim-demo.env << ENVEOF
# Written by scripts/apim-bootstrap.sh. Demo credentials only; never commit.
GATEWAY_URL=$PUBLIC_GATEWAY_URL
TOKEN_URL=$PUBLIC_APIM_URL/oauth2/token
CONSUMER_KEY=$CK
CONSUMER_SECRET=$CS
API_KEY=$APIKEY
PRODUCT_CONTEXT=$PRODUCT_CONTEXT
PRODUCT_CONSUMER_KEY=$PCK
PRODUCT_CONSUMER_SECRET=$PCS
ENVEOF
# Ready-to-import Postman environment with the demo apps' real credentials (gitignored)
TEMPLATE=docs/postman/Jamii-dev-localhost.postman_environment.json
GENERATED=docs/postman/Jamii-dev-localhost.generated.postman_environment.json
if [[ -f $TEMPLATE ]]; then
  jq --arg ck "$CK" --arg cs "$CS" --arg ak "$APIKEY" --arg pck "$PCK" --arg pcs "$PCS" --arg tu "$PUBLIC_APIM_URL/oauth2/token" \
     --arg gw "$PUBLIC_GATEWAY_URL" --arg au "$APIM_ADMIN_USER" '
     .name = "Jamii - dev (localhost, generated)" |
     .values |= map(
       if   .key=="consumerKey"           then .value=$ck
       elif .key=="consumerSecret"        then .value=$cs
       elif .key=="apiKey"                then .value=$ak
       elif .key=="productConsumerKey"    then .value=$pck
       elif .key=="productConsumerSecret" then .value=$pcs
       elif .key=="tokenUrl"              then .value=$tu
       elif .key=="gatewayUrl"            then .value=$gw
       elif .key=="apimAdminUser"         then .value=$au
       else . end)' "$TEMPLATE" > "$GENERATED"
  ok "Postman environment written: $GENERATED"
fi

step "Done"
echo "   Developer Portal: $PUBLIC_APIM_URL/devportal"
echo "   Demo credentials:  .apim-demo.env  (used by scripts/gateway-check.sh)"