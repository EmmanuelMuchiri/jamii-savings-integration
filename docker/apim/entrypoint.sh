#!/usr/bin/env bash
# Starts API Manager. Admin credentials come from the environment ($env{...} in deployment.toml).
set -euo pipefail
: "${APIM_ADMIN_USER:?APIM_ADMIN_USER must be set}"
: "${APIM_ADMIN_PASSWORD:?APIM_ADMIN_PASSWORD must be set}"
export JAVA_OPTS="${JAVA_OPTS:-} -Xms512m -Xmx2048m"
exec "${APIM_HOME}/bin/api-manager.sh"
