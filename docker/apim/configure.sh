#!/usr/bin/env bash
# Build-time configuration of the unpacked API Manager distribution.
# Usage: configure.sh <APIM_HOME>   (branding is applied by brand.py)
set -euo pipefail
APIM="$1"
WEBAPPS="$APIM/repository/deployment/server/webapps"
TOML="$APIM/repository/conf/deployment.toml"

# 1. Admin credentials from the environment instead of admin/admin
sed -i '/^\[super_admin\]/,/^\[/ {
  s/^username *=.*/username = "$env{APIM_ADMIN_USER}"/
  s/^password *=.*/password = "$env{APIM_ADMIN_PASSWORD}"/
}' "$TOML"
echo "configure: super_admin section now reads:"; sed -n '/^\[super_admin\]/,/^$/p' "$TOML"

# 2. Trust Let's Encrypt (ISRG Root X1) in WSO2's client trust store. On the VPS, API Manager
#    validates tokens by calling its own public URL through nginx, which uses a Let's Encrypt certificate.
TRUST="$APIM/repository/resources/security/client-truststore.jks"
if [[ -f /tmp/isrgrootx1.pem && -f $TRUST ]]; then
  if keytool -list -keystore "$TRUST" -storepass wso2carbon -alias letsencrypt-isrg-root-x1 >/dev/null 2>&1; then
    echo "configure: Let's Encrypt root already trusted"
  else
    keytool -importcert -noprompt -alias letsencrypt-isrg-root-x1 -file /tmp/isrgrootx1.pem \
      -keystore "$TRUST" -storepass wso2carbon >/dev/null
    echo "configure: Let's Encrypt root added to client-truststore.jks"
  fi
fi
