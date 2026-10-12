#!/usr/bin/env bash
# Verifies a WSO2 zip against checksums.txt and unpacks it to a fixed path, with clear errors.
# Usage: verify-unpack.sh <zip-name> <target-dir>     (run inside the folder holding both files)
set -euo pipefail
ZIP="$1"; TARGET="$2"
[[ -f "$ZIP" ]] || { echo "ERROR: $ZIP not found in dist/. Files present:"; ls -la; exit 1; }
[[ -f checksums.txt ]] || { echo "ERROR: dist/checksums.txt not found. Run: cd dist && sha256sum *.zip > checksums.txt"; exit 1; }
LINE=$(grep -E "[[:space:]]\*?(\./)?${ZIP//./\\.}$" checksums.txt || true)
if [[ -z "$LINE" ]]; then
  echo "ERROR: no checksum line for $ZIP in dist/checksums.txt. It contains:"; cat checksums.txt
  echo "Fix: cd dist && sha256sum *.zip > checksums.txt"; exit 1
fi
EXPECTED=$(echo "$LINE" | awk '{print $1}')
ACTUAL=$(sha256sum "$ZIP" | awk '{print $1}')
if [[ "$EXPECTED" != "$ACTUAL" ]]; then
  echo "ERROR: checksum mismatch for $ZIP"; echo "  expected $EXPECTED"; echo "  actual   $ACTUAL"
  echo "The download may be incomplete, or checksums.txt is stale."; exit 1
fi
echo "verify: $ZIP checksum OK"
# Unpack, then find the single top-level folder (no pipes: avoids SIGPIPE under pipefail)
rm -rf /tmp/unpack && mkdir -p /tmp/unpack
unzip -q "$ZIP" -d /tmp/unpack
shopt -s nullglob; DIRS=(/tmp/unpack/*/); shopt -u nullglob
if [[ ${#DIRS[@]} -ne 1 ]]; then echo "ERROR: expected one top folder in $ZIP, found ${#DIRS[@]}:"; ls /tmp/unpack; exit 1; fi
TOP=$(basename "${DIRS[0]}")
mv "/tmp/unpack/$TOP" "$TARGET"
chmod +x "$TARGET"/bin/*.sh
echo "verify: unpacked $TOP to $TARGET"
