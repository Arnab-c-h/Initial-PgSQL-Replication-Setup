FROM postgres:16

# Copy custom configuration files into the image
COPY postgresql.custom.conf /etc/postgresql/postgresql.custom.conf
COPY pg_hba.custom.conf /etc/postgresql/pg_hba.custom.conf

# Scripts in /docker-entrypoint-initdb.d are executed when a container is started for the first time
# and the database needs to be initialized (i.e., PGDATA is empty).
COPY init-master.sh /docker-entrypoint-initdb.d/init-master.sh
RUN chmod +x /docker-entrypoint-initdb.d/init-master.sh
