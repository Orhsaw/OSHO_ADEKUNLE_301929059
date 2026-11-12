#!/usr/bin/env bash
# replication_demo.sh — Portfolio 5: build a streaming read replica of the
# sweetcrust_p5 database on the same machine and DEMONSTRATE it, in one run.
#
#   PRIMARY  port 5432  (the Ubuntu cluster 16/main)
#   REPLICA  port 5433  (data dir /var/lib/postgresql/16/replica)
#
# Codespaces rules respected: sudo is root-only (use `sudo runuser -u postgres`),
# no systemd, Unix sockets only (no TCP passwords), no postgres_fdw, pg_hba
# lines inserted at the TOP of the file, replica gets its own conf/hba/ident.
#
# Run AFTER partitioning.sql (the replica copies whatever is in the cluster):
#   bash replication_demo.sh | tee replication_output.log
set -euo pipefail

PGBIN=/usr/lib/postgresql/16/bin
SOCK=/var/run/postgresql
CONF=/etc/postgresql/16/main
REPL=/var/lib/postgresql/16/replica
PG="sudo runuser -u postgres --"

step() { echo; echo "=== $* ==="; }
primary() { $PG psql -X -h "$SOCK" -p 5432 -d sweetcrust_p5 "$@"; }
replica() { $PG psql -X -h "$SOCK" -p 5433 -d sweetcrust_p5 "$@"; }

step "0. Clean slate (safe to re-run)"
if [ -d "$REPL" ]; then
  $PG "$PGBIN/pg_ctl" -D "$REPL" stop -m fast >/dev/null 2>&1 || true
  sudo rm -rf "$REPL"
fi
primary -qAt -c "SELECT pg_drop_replication_slot('sweetcrust_slot') FROM pg_replication_slots WHERE slot_name='sweetcrust_slot';" >/dev/null || true
sudo sed -i '/# P5 replication (added by replication_demo.sh)/,+3d' "$CONF/pg_hba.conf"

step "1. Replication role + pg_hba lines at the TOP of pg_hba.conf"
primary -qAt -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='repl') THEN CREATE ROLE repl WITH REPLICATION LOGIN PASSWORD 'replpass'; END IF; END \$\$;"
sudo sed -i '1i # P5 replication (added by replication_demo.sh)\nlocal   replication   repl                              trust\nhost    replication   repl      127.0.0.1/32            trust\nlocal   all           repl                              trust' "$CONF/pg_hba.conf"
primary -qAt -c "SELECT pg_reload_conf();" >/dev/null
sleep 1
sudo head -5 "$CONF/pg_hba.conf"

step "2. Base backup of the primary into the replica data directory"
sudo mkdir -p "$REPL"; sudo chown postgres:postgres "$REPL"; sudo chmod 700 "$REPL"
$PG env PGPASSWORD=replpass "$PGBIN/pg_basebackup" \
    -h "$SOCK" -p 5432 -U repl -D "$REPL" -X stream -R -C -S sweetcrust_slot -c fast
echo "base backup complete: $($PG du -sh "$REPL" | cut -f1)"

step "3. Give the replica its own config (Ubuntu keeps config in /etc, so the backup has none)"
sudo tee "$REPL/postgresql.conf" >/dev/null <<CFG
port = 5433
listen_addresses = ''
unix_socket_directories = '$SOCK'
hot_standby = on
max_connections = 200
shared_buffers = 128MB
wal_level = replica
max_wal_senders = 10
cluster_name = 'sweetcrust-replica'
CFG
sudo cp "$CONF/pg_hba.conf"  "$REPL/pg_hba.conf"
sudo cp "$CONF/pg_ident.conf" "$REPL/pg_ident.conf"
sudo chown postgres:postgres "$REPL"/postgresql.conf "$REPL"/pg_hba.conf "$REPL"/pg_ident.conf
sudo chmod 700 "$REPL"
echo "standby.signal present: $(sudo test -f "$REPL/standby.signal" && echo yes || echo NO)"
echo "primary_conninfo:      $(sudo grep -h primary_conninfo "$REPL/postgresql.auto.conf" | cut -c1-90)..."

step "4. Start the replica on port 5433"
$PG "$PGBIN/pg_ctl" -D "$REPL" -l /tmp/replica.log -w start >/dev/null
for i in $(seq 1 30); do replica -qAt -c "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done

step "5. Who is who? (each query is run on a different server)"
echo "--- PRIMARY (port 5432) ---"
primary -c "SELECT current_setting('port') AS port, pg_is_in_recovery() AS is_replica, current_database() AS db;"
echo "--- REPLICA (port 5433) ---"
replica -c "SELECT current_setting('port') AS port, pg_is_in_recovery() AS is_replica, current_database() AS db;"

step "6. Replication status on the PRIMARY (pg_stat_replication)"
for i in $(seq 1 20); do
  [ "$(primary -qAt -c "SELECT count(*) FROM pg_stat_replication WHERE state='streaming'")" = "1" ] && break; sleep 1; done
primary -x -c "SELECT application_name, state, sync_state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;"

step "7. Demo 1 - a write on the REPLICA is rejected"
replica -c "INSERT INTO branch(name, city, address) VALUES ('Should Fail','Lagos','replica write') ;" 2>&1 || echo "(rejected as expected)"

step "8. Demo 2 - a row written on the PRIMARY appears on the REPLICA"
echo "--- PRIMARY: insert ---"
primary -c "INSERT INTO branch(name, city, address) VALUES ('SweetCrust Test Replica','Lagos','replication demo') RETURNING branch_id, name;"
for i in $(seq 1 20); do
  [ "$(replica -qAt -c "SELECT count(*) FROM branch WHERE name='SweetCrust Test Replica'")" = "1" ] && break; sleep 0.5; done
echo "--- REPLICA: read ---"
replica -c "SELECT branch_id, name, city FROM branch WHERE name='SweetCrust Test Replica';"

step "9. Same data on both servers + replication lag"
echo "--- PRIMARY ---"
primary -c "SELECT count(*) AS cake_orders FROM cake_order;"
echo "--- REPLICA ---"
replica -c "SELECT count(*) AS cake_orders FROM cake_order;"
replica -c "SELECT pg_last_wal_receive_lsn() AS receive_lsn, pg_last_wal_replay_lsn() AS replay_lsn, round(extract(epoch FROM now() - pg_last_xact_replay_timestamp())::numeric, 3) AS lag_seconds;"

step "10. Clean up the demo row and stop the replica (so no WAL piles up on the primary)"
primary -c "DELETE FROM branch WHERE name='SweetCrust Test Replica';"
sleep 1
$PG "$PGBIN/pg_ctl" -D "$REPL" stop -m fast >/dev/null
primary -qAt -c "SELECT pg_drop_replication_slot('sweetcrust_slot');" >/dev/null
sudo sed -i '/# P5 replication (added by replication_demo.sh)/,+3d' "$CONF/pg_hba.conf"
primary -qAt -c "SELECT pg_reload_conf();" >/dev/null
sudo rm -rf "$REPL"
echo "replica stopped, slot dropped, pg_hba.conf restored."
echo
echo "replication demo finished OK"
