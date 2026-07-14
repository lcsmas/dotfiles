#!/usr/bin/env bash
# mc-env.sh — Mobile Club environment resolver + DB query helper.
#
# Two subsystems:
#   1. postgres envs (api-v2/admin/Loop side)  -> query directly over the staging RDS host
#   2. next-api int/int2 (Symfony side)         -> resolve DB live from the container .env.local
#                                                  via the Portainer exec API, then query with PHP
#
# Secrets are read from the environment (sourced from ~/.zsh_secret): never hardcode creds here.
#   $MC_DB_STAGING_PASSWORD   (postgres: mobileclub + all mc-* envs; same RDS user 'mobileclub')
#   $PORTAINER_INT_TOKEN / $PORTAINER_INT2_TOKEN
#
# Usage:
#   mc-env.sh envs                         # list known environments + how each is reached
#   mc-env.sh pg <env> "<SQL>"             # query a postgres env (staging|sandbox|development|ephemeral-next|prod)
#   mc-env.sh int-map                      # LIVE resolve: which next-api (int/int2 project) -> which DB + api-v2
#   mc-env.sh int-sql <host> <project> "<SQL>"   # run SQL against a next-api DB (host=int|int2)
#   mc-env.sh portainer <host> <container> "<shell cmd>"  # raw exec on an int/int2 container
#
set -euo pipefail

# ---- postgres (api-v2 side) --------------------------------------------------
PG_HOST="staging.mobileclub.internal"   # same RDS instance for staging + all mc-* envs
PG_USER="mobileclub"
pg_db_for() {
  case "$1" in
    staging)        echo "mobileclub" ;;
    sandbox)        echo "mobileclub_sandbox" ;;
    development)    echo "mobileclub_development" ;;
    ephemeral-next) echo "mobileclub_next" ;;
    prod)           echo "__PROD__" ;;   # prod is a different host/creds; handled separately
    *) echo "UNKNOWN"; return 1 ;;
  esac
}
pg() {
  local env="$1" sql="$2" db host user pass; db="$(pg_db_for "$env")"
  if [ "$db" = "UNKNOWN" ]; then echo "unknown pg env: $env (staging|sandbox|development|ephemeral-next|prod)"; return 1; fi
  if [ "$env" = "prod" ]; then
    : "${MC_DB_PROD_USER:?set MC_DB_PROD_USER}"; : "${MC_DB_PROD_PASSWORD:?set MC_DB_PROD_PASSWORD}"
    host="production.mobileclub.internal"; user="$MC_DB_PROD_USER"; pass="$MC_DB_PROD_PASSWORD"; db="mobileclub"
  else
    : "${MC_DB_STAGING_PASSWORD:?set MC_DB_STAGING_PASSWORD (from ~/.zsh_secret)}"
    host="$PG_HOST"; user="$PG_USER"; pass="$MC_DB_STAGING_PASSWORD"
  fi
  # MCP-free: run a psycopg one-shot via uvx (no system install). Prints TSV (header + rows).
  MCPG_HOST="$host" MCPG_USER="$user" MCPG_PASS="$pass" MCPG_DB="$db" MCPG_SQL="$sql" \
  uvx --quiet --with 'psycopg[binary]' python3 - <<'PY'
import os, psycopg, sys
conn = psycopg.connect(host=os.environ["MCPG_HOST"], port=5432,
                       user=os.environ["MCPG_USER"], dbname=os.environ["MCPG_DB"],
                       password=os.environ["MCPG_PASS"])
cur = conn.execute(os.environ["MCPG_SQL"])
if cur.description:
    print("\t".join(c.name for c in cur.description))
    for row in cur.fetchall():
        print("\t".join("NULL" if v is None else str(v) for v in row))
else:
    print(f"OK rows_affected={cur.rowcount}")
conn.commit()
PY
}

# ---- Portainer exec (next-api int/int2 side) ---------------------------------
ptr_host_for()  { case "$1" in int) echo "int-portainer.nextmobiles.com";; int2) echo "int2-portainer.nextmobiles.com";; *) return 1;; esac; }
ptr_token_for() { case "$1" in int) echo "${PORTAINER_INT_TOKEN:?set PORTAINER_INT_TOKEN}";; int2) echo "${PORTAINER_INT2_TOKEN:?set PORTAINER_INT2_TOKEN}";; *) return 1;; esac; }

# Run a shell command inside a container on an int/int2 host via the Portainer Docker exec API.
# The exec stream is a multiplexed docker stream; we strip the frame headers with `strings`-like cleanup.
ptr_exec() {  # host_label container "cmd"
  local host token payload eid
  host="$(ptr_host_for "$1")"; token="$(ptr_token_for "$1")"
  payload="$(python3 -c 'import json,sys; print(json.dumps({"AttachStdout":True,"AttachStderr":True,"Cmd":["sh","-c",sys.argv[1]]}))' "$3")"
  eid="$(curl -s -H "X-API-Key: $token" -H "Content-Type: application/json" \
        -X POST "https://$host/api/endpoints/2/docker/containers/$2/exec" -d "$payload" \
        | python3 -c 'import sys,json;print(json.load(sys.stdin)["Id"])')"
  curl -s -H "X-API-Key: $token" -H "Content-Type: application/json" \
    -X POST "https://$host/api/endpoints/2/docker/exec/$eid/start" -d '{"Detach":false,"Tty":false}' --output - 2>/dev/null \
    | strings
}

# Live map: for each int/int2 project, print the active DB + Loop (api-v2) target.
int_map() {
  local base=/var/www/next-mobiles-docker/projects
  for host in int int2; do
    for proj in next-mobiles-api next-mobiles-api-2; do
      local out
      out="$(ptr_exec "$host" app_workspace82 "test -f $base/$proj/.env.local && { echo -n 'branch='; (cd $base/$proj && git rev-parse --abbrev-ref HEAD 2>/dev/null); grep -hE '^(DATABASE_URL_NEXTMOBILES=|LOOP_BASE_URL=|APP_ENV=)' $base/$proj/.env.local | sed -E 's#(mysql://[^:]+:)[^@]+@#\\1***@#g'; } || echo MISSING" 2>/dev/null)"
      echo "### $host / $proj"
      echo "$out" | sed 's/^/    /'
      echo
    done
  done
}

# Query a next-api DB: reads that project's live .env.local creds and runs SQL via PHP mysqli in-container.
int_sql() {  # host project "SQL"
  local host="$1" proj="$2" sql="$3" base=/var/www/next-mobiles-docker/projects
  local php b64
  # PHP program: parse .env.local DATABASE_URL_NEXTMOBILES, connect over TLS, run the SQL, print TSV.
  php="$(cat <<PHP
<?php
\$line=null; foreach(file(getcwd()."/.env.local") as \$l){ if(preg_match('/^DATABASE_URL_NEXTMOBILES=/',\$l)) \$line=\$l; }
if(!\$line){fwrite(STDERR,"no DATABASE_URL_NEXTMOBILES in .env.local\n");exit(2);}
\$url=preg_replace('/\?.*\$/','',trim(trim(explode('=',\$line,2)[1]),"\"' \n\r"));
\$u=parse_url(\$url); \$db=ltrim(\$u['path'],'/');
\$m=mysqli_init(); @mysqli_real_connect(\$m,\$u['host'],\$u['user'],\$u['pass'],\$db,(int)(\$u['port']??3306),null,MYSQLI_CLIENT_SSL);
if(mysqli_connect_errno()){fwrite(STDERR,"CONNFAIL:".mysqli_connect_error()."\n");exit(3);}
\$res=\$m->query(\$argv[1]);
if(\$res===false){fwrite(STDERR,"SQLERR:".\$m->error."\n");exit(4);}
if(\$res===true){echo "OK affected=".\$m->affected_rows."\n";exit;}
\$cols=array_map(fn(\$f)=>\$f->name,\$res->fetch_fields()); echo implode("\t",\$cols)."\n";
while(\$row=\$res->fetch_row()){ echo implode("\t",array_map(fn(\$v)=>\$v===null?'NULL':\$v,\$row))."\n"; }
PHP
)"
  b64="$(printf '%s' "$php" | base64 | tr -d '\n')"
  # SQL is passed as argv[1]; base64 it too to survive shell quoting.
  local sqlb64; sqlb64="$(printf '%s' "$sql" | base64 | tr -d '\n')"
  ptr_exec "$host" app_workspace82 \
    "cd $base/$proj && printf %s '$b64' | base64 -d > /tmp/mcq.php && printf %s '$sqlb64' | base64 -d > /tmp/mcq.sql && /usr/bin/php /tmp/mcq.php \"\$(cat /tmp/mcq.sql)\" 2>&1; rm -f /tmp/mcq.php /tmp/mcq.sql" \
    | grep -vE '^Warning: Module .* already loaded'
}

# ---- direct MySQL (next-api prod + local) ------------------------------------
# Unlike int/int2 (Azure DB only reachable from inside the container -> Portainer exec),
# prod-Azure allows this machine's IP and local is 127.0.0.1, so both connect DIRECTLY.
# MCP-free: uvx one-shot with PyMySQL. Prints TSV.
mysql_direct() {  # <prod|local> "<SQL>"
  local target="$1" sql="$2" host user pass db port ssl
  case "$target" in
    prod)
      : "${NEXTMOBILE_PROD_DB_PASSWORD:?set NEXTMOBILE_PROD_DB_PASSWORD (from ~/.zsh_secret)}"
      host="nextmobile-prd-mysqldb.mysql.database.azure.com"; user="nextmobile_ro"
      pass="$NEXTMOBILE_PROD_DB_PASSWORD"; db=""; port=3306; ssl=1 ;;
    local)
      host="127.0.0.1"; user="symfony"; pass="symfony"; db="symfony_db"; port=3306; ssl=0 ;;
    *) echo "unknown mysql target: $target (prod|local)"; return 1 ;;
  esac
  MCMY_HOST="$host" MCMY_USER="$user" MCMY_PASS="$pass" MCMY_DB="$db" \
  MCMY_PORT="$port" MCMY_SSL="$ssl" MCMY_SQL="$sql" \
  uvx --quiet --with 'PyMySQL' python3 - <<'PY'
import os, sys, pymysql
kw = dict(host=os.environ["MCMY_HOST"], port=int(os.environ["MCMY_PORT"]),
          user=os.environ["MCMY_USER"], password=os.environ["MCMY_PASS"])
if os.environ.get("MCMY_DB"): kw["database"] = os.environ["MCMY_DB"]
if os.environ.get("MCMY_SSL") == "1": kw["ssl"] = {"ssl": {}}  # TLS, no cert verify (Azure)
conn = pymysql.connect(**kw)
cur = conn.cursor()
cur.execute(os.environ["MCMY_SQL"])
if cur.description:
    print("\t".join(c[0] for c in cur.description))
    for row in cur.fetchall():
        print("\t".join("NULL" if v is None else str(v) for v in row))
else:
    print(f"OK rows_affected={cur.rowcount}")
conn.commit()
PY
}

envs() {
  cat <<'TXT'
POSTGRES (api-v2 / admin / Loop side) — same staging RDS host, different DB per env:
  staging          -> mobileclub               staging.mobileclub.internal
  sandbox          -> mobileclub_sandbox        sandbox.mobileclub.io
  development      -> mobileclub_development     development.mobileclub.io
  ephemeral-next   -> mobileclub_next            next.mobileclub.io
  prod             -> mobileclub @ production.mobileclub.internal (separate creds)
  Query:  mc-env.sh pg <env> "SQL"   (uvx+psycopg one-shot; no MCP, no system psql needed)

NEXT-API (Symfony side) — dated DBs on Azure MySQL 'nextmobile-int-mysqldb', DB name ROTATES:
  Resolve live (never assume): mc-env.sh int-map
  Query:  mc-env.sh int-sql <int|int2> <next-mobiles-api|next-mobiles-api-2> "SQL"
  Only 'next-mobiles-api' is nginx-served (the live app). '-api-2' exists only on int as a side checkout.

NEXT-API MySQL reachable DIRECTLY (no container hop) — uvx+PyMySQL one-shot:
  prod   -> nextmobile-prd-mysqldb.mysql.database.azure.com (user nextmobile_ro, read-only)
  local  -> 127.0.0.1 symfony_db (user symfony)
  Query:  mc-env.sh mysql <prod|local> "SQL"
TXT
}

cmd="${1:-envs}"; shift || true
case "$cmd" in
  envs)      envs ;;
  pg)        pg "$@" ;;
  mysql)     mysql_direct "$@" ;;
  int-map)   int_map ;;
  int-sql)   int_sql "$@" ;;
  portainer) ptr_exec "$@" ;;
  *) echo "unknown command: $cmd"; envs; exit 1 ;;
esac
