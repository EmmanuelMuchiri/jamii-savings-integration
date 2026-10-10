#!/usr/bin/env bash
# Build-time configuration of the unpacked MI distribution.
set -euo pipefail
MI="${1:-/opt/mi}"

# 1. Enforce endpoint timeouts precisely. Synapse checks for timed-out calls every
#    synapse.timeout_handler_interval ms (default 15000), so a 10 s timeout could fire late.
TOML="$MI/conf/deployment.toml"
LINE="'synapse.timeout_handler_interval' = 1000"
if grep -q '^\[synapse_properties\]' "$TOML"; then
  sed -i "/^\[synapse_properties\]/a $LINE" "$TOML"
else
  printf '\n[synapse_properties]\n%s\n' "$LINE" >> "$TOML"
fi
echo "configure: timeout handler interval set to 1000 ms"

# 2. Log-layout masking (defence in depth). MI's own components (data services, transport)
#    log request parameters and URLs, so mask any run of 10+ digits in every log message:
#    0123456789 -> ******6789. The regex avoids backslashes and braces on purpose
#    (.properties escaping and log4j2 option parsing).
LOG4J="$MI/conf/log4j2.properties"
REGEX='(?<![0-9])[0-9][0-9][0-9][0-9][0-9][0-9]+([0-9][0-9][0-9][0-9])(?![0-9])'
sed -i -E "/layout\.pattern/ {
  s/%m%ex/@@MEX@@/g
  s/%msg/@@M@@/g
  s/%m([^a-zA-Z]|$)/@@M@@\1/g
  s#@@MEX@@#%replace{%m%ex}{${REGEX}}{******\$1}#g
  s#@@M@@#%replace{%m}{${REGEX}}{******\$1}#g
}" "$LOG4J"
echo "configure: masked layout patterns:"
grep -c 'replace{%m' "$LOG4J"
