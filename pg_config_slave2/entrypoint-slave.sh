#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "[[[[ Starting Slave Initialization Script for $SLAVE_APP_NAME (Corrected v3 - app_name in primary_conninfo) ]]]]"

# --- 1. Environment Variable Validation ---
# ... (same as before) ...
if [ -z "$MASTER_HOST" ] || [ -z "$REPLICA_USER" ] || [ -z "$REPLICA_PASS" ] || [ -z "$SLAVE_APP_NAME" ]; then
    echo "ERROR: MASTER_HOST, REPLICA_USER, REPLICA_PASS, and SLAVE_APP_NAME environment variables must be set."
    exit 1
fi
echo "Slave Configuration: MASTER_HOST=$MASTER_HOST, REPLICA_USER=$REPLICA_USER, SLAVE_APP_NAME=$SLAVE_APP_NAME"


DATADIR="/var/lib/postgresql/data"

# --- 2. Determine if a fresh base backup is needed ---
# ... (same as before) ...
NEEDS_BASE_BACKUP=false
if [ ! -f "$DATADIR/standby.signal" ]; then
    echo "INFO: No standby.signal file found. A base backup is required."
    NEEDS_BASE_BACKUP=true
elif [ ! -s "$DATADIR/PG_VERSION" ]; then
    echo "INFO: standby.signal exists, but PG_VERSION is missing or empty. Data directory may be corrupt. A base backup is required."
    NEEDS_BASE_BACKUP=true
fi


if [ "$NEEDS_BASE_BACKUP" = true ]; then
    # ... (2a. Wait for Master, 2b. Clean Data Directory, 2c. Perform Base Backup - all same as before) ...
    echo "INFO: Proceeding with pg_basebackup for $SLAVE_APP_NAME..."

    # --- 2a. Wait for Master Availability ---
    echo "Waiting for master ($MASTER_HOST) to be available..."
    MAX_RETRIES=12 # Approx 1 minute
    RETRY_COUNT=0
    until pg_isready -h "$MASTER_HOST" -p 5432 -U "$REPLICA_USER" -q || [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; do
      RETRY_COUNT=$((RETRY_COUNT+1))
      echo "Master ($MASTER_HOST) on port 5432 not ready yet (attempt $RETRY_COUNT/$MAX_RETRIES). Retrying in 5 seconds..."
      sleep 5
    done

    if ! pg_isready -h "$MASTER_HOST" -p 5432 -U "$REPLICA_USER" -q; then
        echo "ERROR: Master ($MASTER_HOST) did not become available after $MAX_RETRIES attempts. Aborting."
        exit 1
    fi
    echo "Master is ready."

    # --- 2b. Clean Data Directory ---
    echo "Cleaning data directory $DATADIR thoroughly before pg_basebackup..."
    rm -rf "${DATADIR:?}"/* 
    mkdir -p "$DATADIR"    
    chown postgres:postgres "$DATADIR"
    chmod 0700 "$DATADIR"

    # --- 2c. Perform Base Backup ---
    echo "Running pg_basebackup, attempting to create slot '$SLAVE_APP_NAME' on master..."
    export PGPASSWORD="$REPLICA_PASS"
    if pg_basebackup \
        -h "$MASTER_HOST" \
        -U "$REPLICA_USER" \
        -D "$DATADIR" \
        -Fp \
        -Xs \
        -P \
        -R \
        --slot="$SLAVE_APP_NAME" \
        --create-slot; then
        echo "pg_basebackup completed successfully."
    else
        echo "ERROR: pg_basebackup failed with exit code $?. Check messages above."
        echo "Contents of DATADIR ($DATADIR) after failed pg_basebackup:"
        ls -la "$DATADIR"
        exit 1
    fi
    unset PGPASSWORD

    # --- 2d. Modify primary_conninfo in postgresql.auto.conf to include application_name ---
    echo "Ensuring 'application_name=$SLAVE_APP_NAME' is in primary_conninfo of $DATADIR/postgresql.auto.conf"
    if [ -f "$DATADIR/postgresql.auto.conf" ]; then
        # Read the existing primary_conninfo
        PRIMARY_CONNINFO_LINE=$(grep "^primary_conninfo\s*=" "$DATADIR/postgresql.auto.conf")
        
        if [ -n "$PRIMARY_CONNINFO_LINE" ]; then
            # Extract the value part: primary_conninfo = 'value'
            CONNINFO_VALUE=$(echo "$PRIMARY_CONNINFO_LINE" | sed -e "s/^primary_conninfo\s*=\s*'//g" -e "s/'\s*$//g")

            # Remove existing application_name if present
            CONNINFO_VALUE_NO_APP_NAME=$(echo "$CONNINFO_VALUE" | sed -e "s/application_name=[^ ]*//g" -e "s/ \s\+/ /g" -e "s/^ //g" -e "s/ $//g")
            
            # Append new application_name
            NEW_CONNINFO_VALUE="$CONNINFO_VALUE_NO_APP_NAME application_name=$SLAVE_APP_NAME"
            # Trim leading/trailing whitespace again just in case
            NEW_CONNINFO_VALUE=$(echo "$NEW_CONNINFO_VALUE" | sed -e "s/^ //g" -e "s/ $//g")

            # Replace the old primary_conninfo line with the new one
            sed -i.bak "s|^primary_conninfo\s*=.*|primary_conninfo = '$NEW_CONNINFO_VALUE'|" "$DATADIR/postgresql.auto.conf"
            echo "primary_conninfo updated in $DATADIR/postgresql.auto.conf to include/update application_name."
            rm -f "$DATADIR/postgresql.auto.conf.bak" # Clean up backup file
        else
            echo "WARNING: primary_conninfo line not found in $DATADIR/postgresql.auto.conf. Manually adding."
            # This is a fallback, ideally pg_basebackup -R creates this.
            echo "primary_conninfo = 'host=$MASTER_HOST port=5432 user=$REPLICA_USER password=$REPLICA_PASS application_name=$SLAVE_APP_NAME'" >> "$DATADIR/postgresql.auto.conf"
            echo "primary_slot_name = '$SLAVE_APP_NAME'" >> "$DATADIR/postgresql.auto.conf" # Should also be set by -R
            echo "standby_mode = 'on'" >> "$DATADIR/postgresql.auto.conf" # Should be standby.signal file
        fi
        # Remove any standalone application_name = '...' line as it's now in primary_conninfo
        sed -i "/^application_name\s*=/d" "$DATADIR/postgresql.auto.conf"

    else
        echo "CRITICAL ERROR: $DATADIR/postgresql.auto.conf was not found after pg_basebackup -R. Cannot set primary_conninfo."
        exit 1
    fi

    # --- 2e. Append custom slave configuration include to postgresql.conf ---
    # ... (same as before) ...
    echo "Appending custom slave configuration include to $DATADIR/postgresql.conf..."
    if [ -f "$DATADIR/postgresql.conf" ]; then
        if [ -n "$(tail -c1 "$DATADIR/postgresql.conf")" ]; then
            echo "" >> "$DATADIR/postgresql.conf"
        fi
        echo "# Custom include for slave configuration" >> "$DATADIR/postgresql.conf"
        echo "include '/etc/postgresql/postgresql.custom.conf'" >> "$DATADIR/postgresql.conf"
        echo "Custom config included in $DATADIR/postgresql.conf."
    else
        echo "ERROR: $DATADIR/postgresql.conf not found after pg_basebackup! This is critical."
        exit 1
    fi

    # --- 2f. Set Final Permissions ---
    # ... (same as before) ...
    echo "Setting final ownership and permissions for $DATADIR..."
    chown -R postgres:postgres "$DATADIR"
    chmod 0700 "$DATADIR" 
    echo "Permissions set."

else
    # ... (same as before) ...
    echo "INFO: Data directory $DATADIR appears to be an existing standby setup (standby.signal and PG_VERSION found). Skipping pg_basebackup."
fi

echo "[[[[ Slave Initialization Script Finished for $SLAVE_APP_NAME ]]]]"
echo "Executing main PostgreSQL entrypoint to start standby server..."
exec docker-entrypoint.sh postgres