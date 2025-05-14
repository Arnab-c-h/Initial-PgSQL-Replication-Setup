# pg_config_slave1/Dockerfile (also for slave2)
FROM postgres:16

# Environment variables that will be passed during 'docker run'
# MASTER_HOST (e.g., 192.168.56.10)
# REPLICA_USER (e.g., replicator)
# REPLICA_PASS (e.g., replicapass)
# SLAVE_APP_NAME (e.g., slave1_pg or slave2_pg)
# POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB (inherited from base, used by docker-entrypoint.sh if it were to initdb)

# Copy custom slave configuration
COPY postgresql.custom.conf /etc/postgresql/postgresql.custom.conf
COPY pg_hba.custom.conf /etc/postgresql/pg_hba.custom.conf

# Copy the entrypoint script for the slave
COPY entrypoint-slave.sh /usr/local/bin/entrypoint-slave.sh
RUN chmod +x /usr/local/bin/entrypoint-slave.sh

# Set the entrypoint script as the command to run
CMD ["/usr/local/bin/entrypoint-slave.sh"]