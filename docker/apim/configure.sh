#!/usr/bin/env bash
# Build-time configuration of the unpacked API Manager distribution.
# Usage: configure.sh <APIM_HOME> <branding-dir>
set -euo pipefail
APIM="$1"; BRAND="$2"
WEBAPPS="$APIM/repository/deployment/server/webapps"
TOML="$APIM/repository/conf/deployment.toml"

# 1. Admin credentials from the environment instead of admin/admin
sed -i '/^\[super_admin\]/,/^\[/ {
  s/^username *=.*/username = "$env{APIM_ADMIN_USER}"/
  s/^password *=.*/password = "$env{APIM_ADMIN_PASSWORD}"/
}' "$TOML"
echo "configure: super_admin section now reads:"; sed -n '/^\[super_admin\]/,/^$/p' "$TOML"

# 2. Branding
place() { # app, theme-file-name, target-dir (relative to webapp)
  local app=$1 file=$2 dir=$3
  local target="$WEBAPPS/$app/$dir"
  if [[ ! -d "$WEBAPPS/$app" ]]; then echo "configure: WARN $app webapp not found"; return; fi
  mkdir -p "$WEBAPPS/$app/site/public/images/custom"
  cp "$BRAND"/images/* "$WEBAPPS/$app/site/public/images/custom/"
  if [[ -f "$target/$file" ]]; then
    cp "$BRAND/$app/$file" "$target/$file"; echo "configure: $app theme applied ($dir/$file)"
  else
    mkdir -p "$target"; cp "$BRAND/$app/$file" "$target/$file"
    echo "configure: WARN $app: no default $dir/$file in this release; copied anyway. Files there:"; ls "$target" || true
  fi
  # favicons: replace PNG/ICO favicons in place (SVG ones are left as they are)
  while IFS= read -r fav; do
    case "$fav" in
      *.png) cp "$BRAND/images/favicon.png" "$fav"; echo "configure: $app favicon replaced: ${fav#$WEBAPPS/}";;
      *.ico) cp "$BRAND/images/favicon.ico" "$fav"; echo "configure: $app favicon replaced: ${fav#$WEBAPPS/}";;
    esac
  done < <(find "$WEBAPPS/$app/site/public" -iname 'favicon*' -type f 2>/dev/null)
}
place devportal userTheme.js site/public/theme
place publisher userCustomThemes.js site/public/conf
place admin userCustomThemes.js site/public/conf
