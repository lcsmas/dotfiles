---
name: mobile-club-env-db
description: Connect to, query, pull test data from, or look up a device/event/row in any Mobile Club deployed-environment DATABASE — WITHOUT MCP servers. Two sides — (1) the api-v2/admin/Loop POSTGRES envs (staging, sandbox, development, ephemeral-next, prod) on the shared staging RDS, and (2) the next-api SYMFONY int/int2 MySQL DBs whose names ROTATE and must be read live from each container's .env.local via the Portainer API. Use when the user wants to run a query against, inspect, or grab test data from a sandbox/development/ephemeral/int/int2/staging/prod database, or asks "which int uses which database / which api-v2".
---

# Mobile Club environments — resolve + query (MCP-free)

All DB access goes through one script: `scripts/mc-env.sh`. It needs no MCP servers and no
system psql/mysql client. Secrets come from the environment (sourced from `~/.zsh_secret`):
`MC_DB_STAGING_PASSWORD`, `MC_DB_PROD_USER`/`MC_DB_PROD_PASSWORD`, `PORTAINER_INT_TOKEN`,
`PORTAINER_INT2_TOKEN`. If a var is unset, re-source `~/.zsh_secret` (or decrypt `~/.zsh_secret.age`).

```
scripts/mc-env.sh envs                                    # cheat-sheet of all envs
scripts/mc-env.sh pg <env> "<SQL>"                        # postgres env query
scripts/mc-env.sh mysql <prod|local> "<SQL>"              # next-api MySQL, DIRECT connection (no container)
scripts/mc-env.sh int-map                                 # LIVE: which next-api project -> which DB + api-v2
scripts/mc-env.sh int-sql <int|int2> <project> "<SQL>"    # query an int/int2 next-api MySQL DB
scripts/mc-env.sh portainer <int|int2> <container> "<sh>" # raw exec on a container
```

## Two buckets of environment

### 1. POSTGRES — api-v2 / admin / Loop side
One **shared staging RDS** (`staging.mobileclub.internal`, user `mobileclub`), one DB per env.
Prod is a separate host/creds.

| env | database | domain |
|---|---|---|
| staging | `mobileclub` | (staging) |
| sandbox | `mobileclub_sandbox` | sandbox.mobileclub.io |
| development | `mobileclub_development` | development.mobileclub.io |
| ephemeral-next | `mobileclub_next` | next.mobileclub.io |
| prod | `mobileclub` @ production RDS | (prod) |

These are **manual CDK deploys** (`Deploy Environment` GitHub workflow, `workflow_dispatch`): the
deployed branch is chosen by "Use workflow from"; the `environment_name` input only picks the
config/secrets. So an env has a given feature only if someone dispatched a branch containing it.

Query: `scripts/mc-env.sh pg sandbox "select count(*) from stock_items"`
(runs a `uvx --with 'psycopg[binary]'` one-shot; prints TSV).

Repair-stock ids (prod-snapshot dumps): MON=1, TAM=6, BEA=25, ENV=95. A device only shows in the
admin "To qualify" list if the logged-in user has a `stock_users` row for that stock (see the
`local-e2e-stack` skill for the full qualify→push→render flow this feeds).

### 2. NEXT-API (Symfony) — int / int2
Two **separate Portainer hosts**, each managing its own Docker daemon (`local` endpoint, id 2):
- `int-portainer.nextmobiles.com`  (token `$PORTAINER_INT_TOKEN`)
- `int2-portainer.nextmobiles.com` (token `$PORTAINER_INT2_TOKEN`)
Both are behind Cloudflare — **only HTTPS/443 is reachable, no SSH**. So the ONLY automated path
is the Portainer Docker API over 443 (`/api/endpoints/2/docker/...`), which `mc-env.sh` wraps.

The next-api apps live at `/var/www/next-mobiles-docker/projects/<project>` inside the
`app_workspace82` container. **`next-mobiles-api` is the nginx-served live app on both hosts.**
`next-mobiles-api-2` is a **side checkout that exists only on the int host** (not a git repo, not
served) — it lets someone run a second branch/DB in parallel. int2 has no `-api-2`.

All three point `DATABASE_URL_NEXTMOBILES` at the SAME Azure MySQL server
(`nextmobile-int-mysqldb.mysql.database.azure.com`, user `nextmobile_int`) — they differ only by
**database name, and those names are DATED and ROTATE** when someone reseeds. So **never hardcode
the DB name — always resolve it live** with `int-map`.

Snapshot (2026-07-09 — re-run `int-map` to refresh; names WILL change):

| host / project | database | LOOP_BASE_URL (api-v2) |
|---|---|---|
| int / next-mobiles-api | `nextmobiles_int_240626` | api-v2.**sandbox**.mobileclub.io |
| int / next-mobiles-api-2 | `nextmobiles_int_050526` | api-v2.**next** (ephemeral) .mobileclub.io |
| int2 / next-mobiles-api | `nextmobiles_staging_050526` | api-v2.**staging**.mobile.club |

Query: `scripts/mc-env.sh int-sql int next-mobiles-api "SELECT COUNT(*) FROM event"`
(reads that project's live `.env.local` creds and runs the SQL via PHP mysqli inside the
container over TLS — the int/int2 Azure DBs are only reachable from the int/int2 host, and there's
no mysql client there, so PHP is the query engine).

### 2b. NEXT-API MySQL reachable DIRECTLY — prod & local
Two next-api MySQL DBs connect straight from this machine, no container hop, so they use a simple
`uvx --with 'PyMySQL'` one-shot (the `mysql` command, mirroring `pg`) instead of the Portainer path:

| target | host | user | notes |
|---|---|---|---|
| prod | `nextmobile-prd-mysqldb.mysql.database.azure.com` | `nextmobile_ro` | Azure allows this IP; **read-only** user; TLS (no cert verify). App DB is `nextmobiles_prd` — no default DB, so **schema-qualify** (`nextmobiles_prd.event`). |
| local | `127.0.0.1` | `symfony` / `symfony` | local dev stack; DB `symfony_db`; no TLS |

Query: `scripts/mc-env.sh mysql prod "SELECT COUNT(*) FROM nextmobiles_prd.event"`
       `scripts/mc-env.sh mysql local "SELECT COUNT(*) FROM event"`
(These replaced the `mysql-nextmobile-prod` / `mysql-nextmobile-local` MCPs. The int Azure DB is
NOT directly reachable — that's why int/int2 go through Portainer above.) Needs
`$NEXTMOBILE_PROD_DB_PASSWORD` for prod (local creds are baked in).

## How the two sides connect (NMC-8 diagnosis-pictures feature)
A next-api instance's `LOOP_BASE_URL` says which api-v2 (Loop) env it talks to. To test the full
diagnosis-pictures push→render chain end to end in deployed envs, pair a next-api whose Loop points
at the env you qualified a device in — e.g. **int / next-mobiles-api → api-v2 sandbox**: qualify a
sandbox device (postgres `mobileclub_sandbox`), and int's next-api (MySQL `nextmobiles_int_240626`)
is the consumer that receives the push. Both sides must carry the uuid-only contract code for the
render to work.

## Notes / gotchas
- The Portainer exec stream is a multiplexed docker stream; the helper strips frame bytes, so you
  may see a stray leading char (e.g. `&`/`*`) on the first output line — cosmetic.
- The int containers print `Warning: Module "amqp" is already loaded` on every PHP run — the helper
  filters it; ignore it.
- `.env.local` on int2 contains **live plaintext DB passwords** (Azure, a WordPress RDS, etc.). Treat
  Portainer tokens as sensitive — anyone with them can read those. Never paste creds into files.
- Tokens are stored in `~/.zsh_secret` (`PORTAINER_INT_TOKEN`, `PORTAINER_INT2_TOKEN`). If you rotate
  them in Portainer (admin ▸ My account ▸ Access tokens), update that file and re-encrypt `.zsh_secret.age`.
- **int next-api logs do NOT ship to Datadog** — only `api-v2` / `api-v2-jobs` / `auth0` do (Datadog EU
  site, `app.datadoghq.eu`). To debug int next-api, read its container logs / run code via the Portainer
  exec path, not Datadog.

## Mixed-content / http:// URLs from next-api behind the proxy (diagnosis pictures & any absolute URL)
Symptom: on vecna (`https://int-back.nextmobiles.com`) the diagnosis photos are `(blocked:mixed-content)`
in the Network tab — the `/diagnosis` endpoint returns picture proxy URLs as `http://…` on an https page,
so the browser blocks them before sending. Data/push are fine; only the URL scheme is wrong.

Root cause: `ProductConditionSheetProvider` builds those URLs with `urlGenerator->generate(..., ABSOLUTE_URL)`,
whose scheme comes from the request's `RequestContext`. In deployed envs TLS terminates upstream
(Cloudflare → traefik → nginx → php-fpm over plain HTTP), so the true scheme is only in `X-Forwarded-Proto: https`.
next-api had **no `trusted_proxies`**, so Symfony ignored the forwarded header, saw `http`, and baked `http://`.

**NOT `DOWNLOAD_FILE_DEFAULT_SCHEME`** — that only affects CLI-context URL generation, not request-context
`ABSOLUTE_URL`. Setting it changes nothing for browser-facing URLs (verified).

Fix (belongs in committed `config/packages/framework.yaml`, not a live patch — a redeploy reverts a live edit):
```yaml
framework:
    trusted_proxies: '127.0.0.1,REMOTE_ADDR'   # or a specific CIDR / TRUSTED_PROXIES env for portability
    trusted_headers: ['x-forwarded-for','x-forwarded-host','x-forwarded-proto','x-forwarded-port']
```
Then `cache:clear --env=prod` + reload php-fpm (`kill -USR2 1` in the fpm container). Applies to ALL
absolute-URL generation (emails, downloads, webhooks), not just pictures. Verify live:
`curl -H "Authorization: Bearer <jwt>" https://int-api.nextmobiles.com/api/event/<uuid>/diagnosis`
→ `pictures[]` should be `https://…` and each `/pictures/N` should 200 with real image bytes.
(S3 may return `content-type: application/octet-stream` — cosmetic; browsers still render it.)
