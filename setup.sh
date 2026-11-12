#!/usr/bin/env bash
# setup.sh — Provision PostgreSQL 16 and MongoDB 8 in a GitHub Codespaces
# (Ubuntu) environment for the MIT 8103 Advanced Database Systems portfolio.
#
# Usage in a Codespace terminal:
#   bash setup.sh
#
# Codespaces rules respected:
#   * sudo works only as root -> use `sudo runuser -u postgres -- ...`
#   * there is no systemd -> PostgreSQL via pg_ctlcluster, MongoDB via mongod --fork
#   * connect over the Unix socket, NOT TCP (TCP needs a password)
#   * remove yarn.list before apt-get update (expired key breaks apt)
#   * do NOT use postgres_fdw
#
set -euo pipefail

CODENAME="$(lsb_release -cs)"

echo "==> [1/7] Removing yarn.list (Codespaces apt quirk)"
sudo rm -f /etc/apt/sources.list.d/yarn.list

echo "==> [2/7] PostgreSQL 16 + Python database driver"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates gnupg lsb-release unzip git python3-psycopg2
if ! apt-cache policy postgresql-16 | grep -q 'Candidate: [0-9]'; then
  echo "    postgresql-16 not in the default repo for $CODENAME: adding the PostgreSQL apt repo"
  sudo install -d /usr/share/postgresql-common/pgdg
  sudo curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $CODENAME-pgdg main" \
    | sudo tee /etc/apt/sources.list.d/pgdg.list >/dev/null
  sudo apt-get update -y
fi
sudo apt-get install -y postgresql-16 postgresql-client-16

echo "==> [3/7] Start the PostgreSQL 16 cluster (no systemd, so pg_ctlcluster)"
sudo pg_ctlcluster 16 main start || true
for i in $(seq 1 20); do sudo runuser -u postgres -- psql -qAt -c "SELECT 1" >/dev/null 2>&1 && break; sleep 1; done

echo "==> [4/7] Create the application databases (drops them if already present)"
for db in sweetcrust sweetcrust_p5; do
  sudo runuser -u postgres -- psql -c "DROP DATABASE IF EXISTS $db;"
  sudo runuser -u postgres -- psql -c "CREATE DATABASE $db;"
done

echo "==> [5/7] Enable btree_gist (needed by the decorator EXCLUDE constraint) in both databases"
for db in sweetcrust sweetcrust_p5; do
  sudo runuser -u postgres -- psql -d "$db" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;"
done

echo "==> [6/7] Install MongoDB 8 (official MongoDB apt repo)"
if ! command -v mongod >/dev/null 2>&1; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
  MONGO_CODENAME="$CODENAME"; case "$CODENAME" in jammy|noble) ;; *) MONGO_CODENAME=jammy ;; esac
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $MONGO_CODENAME/mongodb-org/8.0 multiverse" \
    | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y mongodb-org
fi

echo "==> [7/7] Start MongoDB (daemon, no auth, localhost only)"
mkdir -p "$HOME/mongo-data"
pgrep -x mongod >/dev/null || mongod --fork --dbpath "$HOME/mongo-data" --logpath "$HOME/mongod.log" --bind_ip 127.0.0.1
sleep 3
mongosh --quiet --eval 'db.runCommand({ ping: 1 })'

echo
echo "==> Setup complete."
echo "    PostgreSQL 16  -> socket /var/run/postgresql  dbs: sweetcrust, sweetcrust_p5"
echo "    MongoDB 8      -> mongodb://127.0.0.1:27017/sweetcrust_designs"
echo
echo "Connect with:  sudo runuser -u postgres -- psql -d sweetcrust"
echo "Mongo shell:   mongosh sweetcrust_designs"
