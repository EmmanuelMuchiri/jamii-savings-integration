#!/usr/bin/env bash
# Smoke test for the three MI APIs, called directly on MI (no APIM).
# Needs MI's port 8290 published:  docker compose -f docker-compose.yml -f docker-compose.debug.yml --profile core up -d
# Usage: scripts/mi-smoke.sh [base-url] [--with-slow]
set -uo pipefail
BASE="${1:-http://localhost:8290}"
SLOW="${2:-}"
pass=0; fail=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

check() { # name method path expected-status [json-body] [extra-header]
  local name=$1 method=$2 path=$3 expected=$4 body=${5:-} header=${6:-}
  local args=(-s -o "$tmp/body" -D "$tmp/headers" -w '%{http_code}' -X "$method" "$BASE$path" --max-time 30)
  [[ -n $body ]] && args+=(-H 'Content-Type: application/json' --data "$body")
  [[ -n $header ]] && args+=(-H "$header")
  local code; code=$(curl "${args[@]}")
  local problems=""
  [[ $code == "$expected" ]] || problems+=" status=$code(expected $expected)"
  grep -qi '^x-correlation-id:' "$tmp/headers" || problems+=" no-correlation-id"
  grep -qiE '^(x-powered-by|x-internal-[a-z]+):' "$tmp/headers" && problems+=" leaked-internal-header"
  grep -q 'soap:\|SOAP-ENV\|Exception' "$tmp/body" && problems+=" leaked-soap-or-stacktrace"
  if [[ $code -ge 400 ]]; then grep -q '"error"' "$tmp/body" || problems+=" non-standard-error-body"; fi
  if [[ -z $problems ]]; then echo "PASS  $name ($code)"; pass=$((pass+1));
  else echo "FAIL  $name:$problems"; echo "      body: $(head -c 300 "$tmp/body")"; fail=$((fail+1)); fi
}

loan() { printf '{"customerId":"%s","monthlyIncome":%s,"existingMonthlyDebt":%s,"requestedMonthlyInstalment":%s}' "$1" "$2" "$3" "$4"; }

echo "== Balance API =="
check "ACTIVE account"        GET /accounts/0123456789/balance 200
check "DORMANT account"       GET /accounts/1234567890/balance 200
check "CLOSED account"        GET /accounts/2345678901/balance 200
check "unknown account"       GET /accounts/9999999999/balance 404
check "malformed account"     GET /accounts/abc/balance 400

echo "== Customer API =="
check "customer 1001"         GET /customers/1001 200
check "caller correlation ID" GET /customers/1002 200 "" "X-Correlation-ID: smoke-0001"
grep -qi '^x-correlation-id: smoke-0001' "$tmp/headers" && echo "PASS  correlation ID echoed" || { echo "FAIL  correlation ID not echoed"; fail=$((fail+1)); }
check "unknown customer"      GET /customers/9999 404
check "malformed customer"    GET /customers/abc 400
check "backend 500"           GET /customers/5000 502

echo "== Loan Eligibility API =="
check "eligible (33%)"        POST /loans/eligibility 200 "$(loan 1001 120000 15000 25000)"
grep -q '"decision":"ELIGIBLE"' "$tmp/body" || { echo "FAIL  expected ELIGIBLE"; fail=$((fail+1)); }
check "not eligible (50%)"    POST /loans/eligibility 200 "$(loan 1002 50000 15000 10000)"
check "income 0 (soap:Client)" POST /loans/eligibility 422 "$(loan 1001 0 15000 25000)"
check "blacklisted 6000"      POST /loans/eligibility 422 "$(loan 6000 120000 15000 25000)"
check "engine fault 5000"     POST /loans/eligibility 502 "$(loan 5000 120000 15000 25000)"
check "missing field"         POST /loans/eligibility 400 '{"customerId":"1001","monthlyIncome":120000}'
check "malformed JSON"        POST /loans/eligibility 400 '{"customerId": "1001", "monthlyIncome": '

if [[ $SLOW == "--with-slow" ]]; then
  echo "== Timeouts (slow) =="
  check "customer timeout 5004" GET /customers/5004 504
  check "credit timeout 5004"   POST /loans/eligibility 504 "$(loan 5004 120000 15000 25000)"
fi

echo; echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
