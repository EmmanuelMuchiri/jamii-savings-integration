#!/usr/bin/env bash
# End-to-end checks through the API Manager gateway, as a consumer app would call it.
# Uses the demo credentials written by scripts/apim-bootstrap.sh (.apim-demo.env).
#   401 without credentials, 200 with a token or API key, correlation ID, no leaked headers,
#   standard error bodies through the gateway, the API Product, and 429 on the Loan tier.
# Usage: scripts/gateway-check.sh        (exit code 0 only if every check passes)
set -uo pipefail
cd "$(dirname "$0")/.."
[[ -f .apim-demo.env ]] || { echo "ERROR: .apim-demo.env not found. Run scripts/apim-bootstrap.sh first."; exit 1; }
. ./.apim-demo.env
# Inside Docker (apim-init) the URLs differ from the host ones in .apim-demo.env, so allow overrides
GW="${GATEWAY_URL_OVERRIDE:-$GATEWAY_URL}"; TOKEN_URL="${TOKEN_URL_OVERRIDE:-$TOKEN_URL}"; pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

TOKEN=$(curl -sk -u "$CONSUMER_KEY:$CONSUMER_SECRET" -d grant_type=client_credentials "$TOKEN_URL" | jq -r .access_token)
[[ -n $TOKEN && $TOKEN != null ]] || { echo "ERROR: could not get an access token from $TOKEN_URL"; exit 1; }

call() { # method url [curl args...]  -> sets CODE, body in $tmp/body, headers in $tmp/headers
  local method=$1 url=$2; shift 2
  CODE=$(curl -sk -o "$tmp/body" -D "$tmp/headers" -w '%{http_code}' -X "$method" "$url" --max-time 30 "$@")
}
expect() { # name expected-code [extra checks...]
  local name=$1 expected=$2 problems=""
  [[ $CODE == "$expected" ]] || problems+=" status=$CODE(expected $expected)"
  if [[ $CODE != 401 && $CODE != 429 ]]; then
    grep -qi '^x-correlation-id:' "$tmp/headers" || problems+=" no-correlation-id"
    grep -qiE '^(x-powered-by|x-internal-[a-z]+):' "$tmp/headers" && problems+=" leaked-internal-header"
  fi
  if [[ $CODE -ge 400 && $CODE != 401 && $CODE != 429 ]]; then grep -q '"error"' "$tmp/body" || problems+=" non-standard-error-body"; fi
  if [[ -z $problems ]]; then echo "PASS  $name ($CODE)"; pass=$((pass+1))
  else echo "FAIL  $name:$problems"; echo "      body: $(head -c 300 "$tmp/body")"; fail=$((fail+1)); fi
}
AUTH=(-H "Authorization: Bearer $TOKEN")
JSON=(-H 'Content-Type: application/json')

echo "== Security"
call GET "$GW/jamii/accounts/v1/0123456789/balance";                    expect "Balance without token" 401
call GET "$GW/jamii/accounts/v1/0123456789/balance" "${AUTH[@]}";       expect "Balance with token" 200
call GET "$GW/jamii/customers/v1/1001";                                  expect "Customer without API key" 401
call GET "$GW/jamii/customers/v1/1001" -H "ApiKey: $API_KEY";            expect "Customer with API key" 200
call POST "$GW/jamii/loans/v1/eligibility" "${JSON[@]}" \
     --data '{"customerId":"1001","monthlyIncome":120000,"existingMonthlyDebt":15000,"requestedMonthlyInstalment":25000}'
expect "Loan without token" 401

echo "== Behaviour through the gateway"
call GET "$GW/jamii/accounts/v1/0123456789/balance" "${AUTH[@]}" -H "X-Correlation-ID: gw-check-0001"
expect "Balance with caller correlation ID" 200
grep -qi '^x-correlation-id: gw-check-0001' "$tmp/headers" && { echo "PASS  correlation ID echoed through gateway"; pass=$((pass+1)); } \
  || { echo "FAIL  correlation ID not echoed through gateway"; fail=$((fail+1)); }
call GET "$GW/jamii/accounts/v1/9999999999/balance" "${AUTH[@]}";       expect "Unknown account" 404
call GET "$GW/jamii/customers/v1/9999" -H "ApiKey: $API_KEY";            expect "Unknown customer" 404
call POST "$GW/jamii/loans/v1/eligibility" "${AUTH[@]}" "${JSON[@]}" \
     --data '{"customerId":"6000","monthlyIncome":120000,"existingMonthlyDebt":15000,"requestedMonthlyInstalment":25000}'
expect "Loan rejected by credit engine" 422

echo "== API Product (one subscription, all three APIs)"
found=""
for base in "$GW$PRODUCT_CONTEXT/1.0.0" "$GW$PRODUCT_CONTEXT"; do
  call GET "$base/0123456789/balance" "${AUTH[@]}"
  if [[ $CODE == 200 ]]; then found=$base; break; fi
done
if [[ -n $found ]]; then expect "Product: balance via $found" 200
  call GET "$found/1001" "${AUTH[@]}";  expect "Product: customer" 200
else echo "FAIL  Product: balance not reachable under $PRODUCT_CONTEXT (last status $CODE)"; fail=$((fail+1)); fi

echo "== Throttling (LoanCheck10PerMin)"
got429=""
for i in $(seq 1 12); do
  call POST "$GW/jamii/loans/v1/eligibility" "${AUTH[@]}" "${JSON[@]}" \
       --data '{"customerId":"1001","monthlyIncome":120000,"existingMonthlyDebt":15000,"requestedMonthlyInstalment":25000}'
  [[ $CODE == 429 ]] && { got429=$i; break; }
done
if [[ -n $got429 ]]; then echo "PASS  429 after $got429 calls in this run"; pass=$((pass+1))
else echo "FAIL  no 429 within 12 calls"; fail=$((fail+1)); fi

echo; echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
