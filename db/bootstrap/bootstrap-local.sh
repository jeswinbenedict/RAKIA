#!/usr/bin/env sh
# SPDX-License-Identifier: Apache-2.0
#
# Creates the local RAKIA development database and writes .env.
# Same steps as bootstrap-local.ps1 (see there), for Linux and macOS.
#
# Usage: sh db/bootstrap/bootstrap-local.sh [--superuser postgres]
#        [--host localhost] [--port 5432] [--env-file PATH]
# The superuser password is asked at a hidden prompt unless PGPASSWORD is
# already set. Nothing secret is printed; an existing .env is never
# overwritten.
set -eu

superuser=postgres
host=localhost
port=5432
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
env_file="$root/.env"

while [ $# -gt 0 ]; do
  case $1 in
    --superuser) superuser=$2; shift 2 ;;
    --host) host=$2; shift 2 ;;
    --port) port=$2; shift 2 ;;
    --env-file) env_file=$2; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -e "$env_file" ]; then
  echo "$env_file already exists and is never overwritten. Move it away first if you want new credentials." >&2
  exit 1
fi
command -v psql >/dev/null 2>&1 || {
  echo "psql was not found on PATH." >&2
  exit 1
}

new_password() {
  # 32 characters from [A-Za-z0-9], read from the kernel's CSPRNG.
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
}

run_psql() {
  # run_psql USER PASSWORD DATABASE [psql args...]; the password reaches
  # psql through its environment only.
  user=$1 pass=$2 db=$3
  shift 3
  PGPASSWORD=$pass psql -X -q -w -v ON_ERROR_STOP=1 -h "$host" -p "$port" \
    -U "$user" -d "$db" "$@"
}

if [ -n "${PGPASSWORD:-}" ]; then
  super_password=$PGPASSWORD
  unset PGPASSWORD
else
  printf "Password for PostgreSQL superuser '%s' on %s:%s: " "$superuser" "$host" "$port" >&2
  stty -echo 2>/dev/null || true
  IFS= read -r super_password
  stty echo 2>/dev/null || true
  printf '\n' >&2
fi

migrator_password=$(new_password)
api_password=$(new_password)

echo "Creating roles and database on $host:$port ..."
# psql resolves \i against its working directory, so it runs from here.
cd "$here"
printf "\\\\set migrator_password '%s'\n\\\\set api_password '%s'\n\\\\i bootstrap.sql\n" \
  "$migrator_password" "$api_password" |
  run_psql "$superuser" "$super_password" postgres >/dev/null
super_password=

echo "Checking both roles ..."
run_psql rakia_migrator "$migrator_password" rakia -t -A -f verify.sql
run_psql rakia_api "$api_password" rakia -t -A -f verify.sql

umask 077
tmp="$env_file.tmp.$$"
trap 'rm -f "$tmp"' EXIT
# Values reach awk through its environment, not its (visible) arguments.
H=$host P=$port AP=$api_password MP=$migrator_password awk '
  BEGIN {
    v["RAKIA_DB_HOST"] = ENVIRON["H"]; v["RAKIA_DB_PORT"] = ENVIRON["P"]
    v["RAKIA_DB_NAME"] = "rakia"; v["RAKIA_DB_USER"] = "rakia_api"
    v["RAKIA_DB_PASSWORD"] = ENVIRON["AP"]
    v["RAKIA_DB_MIGRATOR_USER"] = "rakia_migrator"
    v["RAKIA_DB_MIGRATOR_PASSWORD"] = ENVIRON["MP"]
  }
  {
    k = $0; sub(/=.*/, "", k)
    if ($0 ~ /^[A-Z0-9_]+=/ && (k in v)) print k "=" v[k]; else print
  }
' "$root/.env.example" >"$tmp"
mv "$tmp" "$env_file"
trap - EXIT
chmod 600 "$env_file"
echo "Wrote $env_file (mode 600). Passwords were not displayed."
