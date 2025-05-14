#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "[[[[ Starting Master Initialization Script (Version: TRULY Final Includes Fix) ]]]]"

# Ensure PGDATA is set
if [ -z "$PGDATA" ]; then
    echo "FATAL: PGDATA environment variable is not set."
    exit 1
fi
echo "PGDATA is: $PGDATA"

# Check if the main config files exist
if [ ! -f "$PGDATA/postgresql.conf" ]; then
    echo "FATAL: $PGDATA/postgresql.conf not found before attempting modification."
    exit 1
fi
if [ ! -f "$PGDATA/pg_hba.conf" ]; then
    echo "FATAL: $PGDATA/pg_hba.conf not found before attempting modification."
    exit 1
fi

echo "--- Original $PGDATA/postgresql.conf (last 10 lines) ---"
tail -n 10 "$PGDATA/postgresql.conf"
echo "--- End Original postgresql.conf ---"

echo "--- Original $PGDATA/pg_hba.conf (last 10 lines) ---"
tail -n 10 "$PGDATA/pg_hba.conf"
echo "--- End Original pg_hba.conf ---"

# --- Modify postgresql.conf ---
echo "Modifying $PGDATA/postgresql.conf to include custom settings..."
# This writes: include_if_exists = '/etc/postgresql/postgresql.custom.conf'
# This syntax is correct for postgresql.conf and was working previously.
cat <<EOF_PG_CONF >> "$PGDATA/postgresql.conf"

# Custom include directive for postgresql.conf (Working Version)
include_if_exists = '/etc/postgresql/postgresql.custom.conf'
EOF_PG_CONF

# --- Modify pg_hba.conf ---
echo "Modifying $PGDATA/pg_hba.conf to include custom HBA rules..."
# This writes: include '/etc/postgresql/pg_hba.custom.conf'
# This is the correct syntax for an include directive in pg_hba.conf.
# The parser did NOT like "include_if_exists" as the first token for pg_hba.conf.
cat <<EOF_PG_HBA >> "$PGDATA/pg_hba.conf"

# Custom include directive for pg_hba.conf (Corrected to 'include' and quoted path)
include /etc/postgresql/pg_hba.custom.conf
EOF_PG_HBA

# --- Verification and Debugging Output ---
echo "--- $PGDATA/postgresql.conf after modification (last 15 lines) ---"
tail -n 15 "$PGDATA/postgresql.conf"
echo "--- End of postgresql.conf after modification ---"

echo "--- $PGDATA/pg_hba.conf after modification (last 15 lines) ---"
tail -n 15 "$PGDATA/pg_hba.conf"
echo "--- End of pg_hba.conf after modification ---"

echo "Verifying actual files copied by Dockerfile..."
if [ -f "/etc/postgresql/postgresql.custom.conf" ]; then
    echo "CHECK: /etc/postgresql/postgresql.custom.conf EXISTS."
else
    echo "CRITICAL WARNING: /etc/postgresql/postgresql.custom.conf DOES NOT EXIST. 'include_if_exists' in postgresql.conf will skip it."
fi
if [ -f "/etc/postgresql/pg_hba.custom.conf" ]; then
    echo "CHECK: /etc/postgresql/pg_hba.custom.conf EXISTS."
else
    echo "CRITICAL ERROR: /etc/postgresql/pg_hba.custom.conf DOES NOT EXIST. The 'include' directive in pg_hba.conf will cause PostgreSQL to FAIL."
fi

# --- Create Replication User ---
echo "Creating replication user '$REPLICA_USER'..."
if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_DB" ] || [ -z "$REPLICA_USER" ] || [ -z "$REPLICA_PASS" ]; then
    echo "FATAL: Required environment variables for replication user creation are not set (POSTGRES_USER, POSTGRES_DB, REPLICA_USER, REPLICA_PASS)."
    exit 1
fi
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $REPLICA_USER WITH REPLICATION LOGIN PASSWORD '$REPLICA_PASS';
EOSQL
echo "Replication user '$REPLICA_USER' created successfully."

echo "[[[[ Master Initialization Script Finished (Version: TRULY Final Includes Fix) ]]]]"