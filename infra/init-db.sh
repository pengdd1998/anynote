#!/bin/bash
# Creates additional databases on first init.
# The primary database (POSTGRES_DB) is created automatically by the postgres image.
set -e

# Create anynote database if POSTGRES_DB is not 'anynote' (avoid duplicate).
if [ "${POSTGRES_DB}" != "anynote" ]; then
  echo "Creating database 'anynote'..."
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE anynote;
    GRANT ALL PRIVILEGES ON DATABASE anynote TO $POSTGRES_USER;
EOSQL
fi

# Create readpal database if POSTGRES_DB is not 'readpal'.
if [ "${POSTGRES_DB}" != "readpal" ]; then
  echo "Creating database 'readpal'..."
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE readpal;
    GRANT ALL PRIVILEGES ON DATABASE readpal TO $POSTGRES_USER;
EOSQL
fi

echo "Database initialization complete."
