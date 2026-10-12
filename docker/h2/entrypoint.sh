#!/usr/bin/env bash
# Builds the database from schema and seed, then starts the H2 TCP server and web console.
# The data is synthetic, so by default the database is recreated on every start
# (H2_RESET_ON_START=true). That also avoids "Wrong user name or password" when the
# credentials in .env change: H2 fixes credentials when it first creates a database.
set -euo pipefail
DB="${H2_DB_NAME:-jamii}"
URL="jdbc:h2:/data/${DB}"
: "${H2_USER:?H2_USER must be set}"
: "${H2_PASSWORD:?H2_PASSWORD must be set}"

if [[ "${H2_RESET_ON_START:-true}" == "true" ]]; then
  echo "h2: H2_RESET_ON_START=true, removing existing database files for ${DB}"
  rm -f "/data/${DB}.mv.db" "/data/${DB}.trace.db" "/data/${DB}.lock.db"
fi

for script in schema.sql seed.sql; do
  echo "h2: running ${script}"
  java -cp /opt/h2/h2.jar org.h2.tools.RunScript -url "${URL}" -user "${H2_USER}" -password "${H2_PASSWORD}" -script "/opt/h2/scripts/${script}"
done
echo "h2: starting TCP server on 9092 (database ${DB})"
exec java -cp /opt/h2/h2.jar org.h2.tools.Server \
  -tcp -tcpAllowOthers -tcpPort 9092 \
  -web -webAllowOthers -webPort 8082 \
  -baseDir /data -ifExists
