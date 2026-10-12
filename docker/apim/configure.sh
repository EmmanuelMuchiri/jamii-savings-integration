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

