#!/usr/bin/env bash
# Starts API Manager. Admin credentials come from the environment ($env{...} in deployment.toml).
# Behind a reverse proxy (VPS), APIM_HOSTNAME / GATEWAY_HOSTNAME switch API Manager to its public names
# so sign-in redirects, the token URL and the gateway URL in the Developer Portal use them.
set -euo pipefail
: "${APIM_ADMIN_USER:?APIM_ADMIN_USER must be set}"
: "${APIM_ADMIN_PASSWORD:?APIM_ADMIN_PASSWORD must be set}"
APIM_HOSTNAME="${APIM_HOSTNAME:-localhost}"
GATEWAY_HOSTNAME="${GATEWAY_HOSTNAME:-localhost}"
TOML="$APIM_HOME/repository/conf/deployment.toml"
WEBAPPS="$APIM_HOME/repository/deployment/server/webapps"

if [[ $APIM_HOSTNAME != localhost ]] && ! grep -q "# jamii-public-hostnames" "$TOML"; then
  echo "apim: public names: portals https://$APIM_HOSTNAME, gateway https://$GATEWAY_HOSTNAME"
  sed -i "0,/^hostname = \"localhost\"/s//hostname = \"$APIM_HOSTNAME\"/" "$TOML"
  sed -i "s#^https_endpoint = \"https://localhost:\${https.nio.port}\"#https_endpoint = \"https://$GATEWAY_HOSTNAME\"#" "$TOML"
  sed -i "s#^http_endpoint = \"http://localhost:\${http.nio.port}\"#http_endpoint = \"http://$GATEWAY_HOSTNAME\"#" "$TOML"
  if grep -q '^\[transport.https.properties\]' "$TOML"; then
    sed -i '/^\[transport.https.properties\]/a proxyPort = 443' "$TOML"
  else
    printf '\n[transport.https.properties]\nproxyPort = 443\n' >> "$TOML"
  fi
  echo "# jamii-public-hostnames applied" >> "$TOML"
  # The portals check the origin they are served from
  find "$WEBAPPS/devportal/site/public" "$WEBAPPS/publisher/site/public" "$WEBAPPS/admin/site/public" \
       -name settings.json -exec sed -i "s#\"host\": *\"localhost\"#\"host\": \"$APIM_HOSTNAME\"#" {} +
  grep -E '^hostname|^https_endpoint|^http_endpoint|^proxyPort' "$TOML" | sed 's/^/apim:   /'
fi

export JAVA_OPTS="${JAVA_OPTS:-} -Xms512m -Xmx2048m"
exec "${APIM_HOME}/bin/api-manager.sh"
