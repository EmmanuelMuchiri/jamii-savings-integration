#!/usr/bin/env bash
# Passes backend URLs to MI as system properties (read in the APIs with get-property('system', ...)).
# H2_URL, H2_USER and H2_PASSWORD are read by the data service directly from the environment ($SYSTEM:).
set -euo pipefail
: "${CUSTOMER_BACKEND_URL:?CUSTOMER_BACKEND_URL must be set}"
: "${CREDIT_BACKEND_URL:?CREDIT_BACKEND_URL must be set}"
: "${H2_URL:?H2_URL must be set}"
export JAVA_OPTS="${JAVA_OPTS:-} -Dcustomer.backend.url=${CUSTOMER_BACKEND_URL} -Dcredit.backend.url=${CREDIT_BACKEND_URL}"
echo "mi: customer backend=${CUSTOMER_BACKEND_URL} credit backend=${CREDIT_BACKEND_URL} db=${H2_URL}"
exec "${MI_HOME}/bin/micro-integrator.sh"
