---
name: local-e2e-stack
description: Bring up Mobile Club's FULL local cross-stack (api-v2/Loop, admin, vecna-front, next-api, hasura, minio, mysql, rabbitmq) for a real-browser end-to-end test, and apply the local-only dev patches a fresh worktree needs. Use when the user wants to "spin up the local stack", "run the full e2e locally", "bring up loop + admin + vecna", or test a cross-repo feature (like NMC-8 diagnosis pictures) in a real browser. Brings up services; documents (does not blindly auto-apply) the source/.env patches and test-data seeding.
---

# Local cross-stack E2E bringup (Mobile Club)

Brings up the full local stack so you can drive a real browser end-to-end across **api-v2 (Loop)**, **admin**, **vecna-front**, and **next-api**, backed by **hasura / minio / mysql / rabbitmq / postgres / redis** containers.

The goal is to make stack **bringup** one motion. The two things that genuinely cannot be committed — the local-only source/`.env` patches and the DB test-data seeding — are documented here as exact, copy-pasteable steps. Apply them deliberately per worktree; do NOT commit them to feature branches (they poison the PRs).

## Mental model: three buckets of setup

1. **Host-persistent (survives across worktrees, do nothing):** Docker volumes + the restored staging Postgres dump in `mobile-club-db`, MinIO data, the chrome-devtools MCP `--executablePath` fix, Node 22.22.0 installed via nvm. If these are gone, see "Cold host" below.
2. **Per-worktree dev patches (must re-apply on each fresh worktree, NEVER commit):** see "Local dev patches".
3. **DB test data (re-seed if the dump was reset):** see "Seed test data".

## Step 0 — locate the worktrees

The repos live in Orchestra worktrees. Find the current ones (names change per spawn):

```bash
ls -d /home/lmas/.orchestra/worktrees/*/ | grep -Ei 'workspace|next-api|vecna-front'
```

- **api-v2 + admin** live in the `workspace-*` monorepo under `packages/api-v2` and `packages/admin`.
- **next-api** is the `next-api-*` worktree (runs in the `symfony_app` Docker container).
- **vecna-front** is the `vecna-front-*` worktree.

Set shell vars to the chosen worktrees before running anything below:

```bash
WS=/home/lmas/.orchestra/worktrees/workspace-XXXX      # api-v2 + admin monorepo
NEXTAPI=/home/lmas/.orchestra/worktrees/next-api-XXXX
VECNA=/home/lmas/.orchestra/worktrees/vecna-front-XXXX
```

## Step 1 — containers

```bash
docker start mobile-club-db mobile-club-hasura-admin mobile-club-minio-s3 \
  mobile-club-redis mobile-club-redis-jobs mysql_db rabbitmq symfony_app
# next-api's own compose (mysql/rabbitmq/app) if not already up:
( cd "$NEXTAPI" && docker compose up -d )
```

Verify (all should report Up):

```bash
docker ps --format '{{.Names}}\t{{.Status}}'
```

## Step 2 — node services (run each in its own background shell)

PATH note: **vecna-front needs Node >= 22.22.0**; system node (22.17) is too old. api-v2 + admin are fine on system node.

```bash
# Loop / api-v2  -> :4444  (+ jobs/PUSH worker)
( cd "$WS/packages/api-v2" && pnpm start )      # :4444  (404 on / is normal)
( cd "$WS/packages/api-v2" && pnpm jobs )       # PUSH worker

# admin (Repairs UI -> Diagnostic & grading) -> :1234
( cd "$WS/packages/admin" && pnpm dev )

# vecna-front (Customer Service event view) -> :8282  -- NEEDS node 22.22
( cd "$VECNA" && PATH=~/.nvm/versions/node/v22.22.0/bin:$PATH pnpm run dev )
```

Run these with `run_in_background: true` so they keep running across turns.

**GOTCHA — reload the hasura remote schema after (re)starting Loop :4444.** admin's Apollo sends most queries (incl. `logistic_computeEstheticGrade` and the other `logistic_*` fields) to **hasura :9090**, which stitches Loop via the `MobileClubAPI` remote schema (`NEST_API_GRAPHQL_ENDPOINT=http://host.docker.internal:4444/graphql`). Only multipart/`Upload` mutations go direct to :4444. If hasura was up while Loop :4444 was **down** (or Loop restarted), hasura keeps its **stale introspection** and the `logistic_*` fields silently vanish from `query_root` — queries 404 with `field "logistic_..." not found in type "query_root"`, even though calling Loop :4444/graphql directly works fine. Symptom in admin: the **Esthetic grade summary card** (Suggested/Final grade) flashes then disappears (the `computeEstheticGrade` query errors → `suggestedGrade` undefined → `EstheticGradeSection` renders null); photo-capture is unaffected. Fix — reload the remote schema (no restart needed):
```bash
curl -s -X POST http://localhost:9090/v1/metadata \
  -H 'x-hasura-admin-secret: kyhBJFNpMRPwoERdl0ypYX2dNjEVHoVD' \
  -H 'Content-Type: application/json' \
  -d '{"type":"reload_remote_schema","args":{"name":"MobileClubAPI"}}'
```
Then hard-reload admin (:1234, Cmd/Ctrl-Shift-R) to clear Apollo's cached schema. Do this **every time Loop :4444 restarts**.

## Step 3 — verify all ports

```bash
for p in 4444 1234 8282 8080 9090 9000 9001; do
  printf "%s: " "$p"; (ss -ltn 2>/dev/null | grep -q ":$p " && echo UP) || echo down
done
```

Expected: `4444` Loop, `1234` admin, `8282` vecna-front, `8080` next-api (host-published from container :80), `9090` hasura-admin, `9000` minio, `9001` minio console.

## Step 4 — drive the browser

- **admin** (do the real diagnosis): `http://localhost:1234` — Repairs → QualificationModal (serial mode). Login is the user's real Google/Auth0 (`lucas.mas@mobile.club`); admin Auth0 cache is in-memory so you cannot inject a token — the USER must complete the Google OAuth login.
- **vecna-front** (see the photos): `http://localhost:8282/#/dashboard/events/return-change/<event-uuid>` — HASH route. Login `qa@vecna.test` / `test1234` (works headless; JWT in localStorage `auth.JWT`, `isAuthenticated` = `!!auth.refreshToken`).
  - GOTCHA: the route is `#/dashboard/events/return-change/:id`, NOT `/dashboard/operations/events/...` (that 404s).
- chrome-devtools MCP drives its OWN Chromium with a dedicated profile — it is NOT the user's tab, and `take_screenshot` may return blank (headless paint artifact). Use the user for final visual confirmation.

## Step 5 — the FULL diagnosis-push E2E (admin diagnose → Loop → next-api → vecna)

This is the real cross-stack flow (NMC-8 diagnosis pictures). It is much more than "start the services" — the production path is a **PUSH**: on qualification Loop's `ReturnedDeviceEventHandler` calls `VecnaApi.sendReturnDiagnostic` → `POST {VECNA_API_URL}/orders/{orderItemId}-inbound/return-diagnostic`. Locally that target must be next-api, and next-api must be seeded to accept + map it. All of the following is local-only wiring (NEVER commit).

**1. Point Loop's push at next-api** — api-v2 `.env`: `VECNA_API_URL=http://localhost:8080/api` (default is `:7788`, nothing there). `VECNA_API_KEY` stays `push-test-key`. Restart Loop (`pnpm start`) + jobs after the change.

**2. next-api must run a messenger consumer** — the `return-diagnostic` endpoint returns 201 immediately and dispatches an async `SyncShipmentMessage` to the `event_messages` transport (RabbitMQ in dev, NOT `sync://`). In prod a daemon drains it; locally nothing does, so the push silently never persists. Start a long-lived worker (`run_in_background: true`):
```bash
docker exec symfony_app php bin/console messenger:consume event_messages --time-limit=3600 -v
```
Without it, you must `messenger:consume event_messages --limit=1` after every push. Failed messages land in the `failed` (doctrine) transport — `messenger:failed:show <id>` to inspect.

**3. next-api seed for the push to authenticate + map** (MySQL `symfony_db`, via `docker exec -i mysql_db mysql -usymfony -psymfony symfony_db` — the `-i` is REQUIRED or the heredoc is silently a no-op):
- **`loop` user** for `API-KEY`/`API-LOGIN` auth: `ApiKeyAuthenticator` looks up `user` by `login`, verifies hashed `api_key`. Insert `user(login='loop', api_key=<bcrypt of push-test-key>)`. Generate the hash with the app's hasher: `docker exec symfony_app php -r 'require "/app/vendor/autoload.php"; echo (new Symfony\Component\PasswordHasher\Hasher\NativePasswordHasher(null,null,4))->hash("push-test-key");'`
- **`business-central` user** — the event-workflow transition needs a system user (`AuthenticationManager::BC_SYSTEM_USER_LOGIN='business-central'`) when run headless (no logged-in user in the consumer). Insert `user(login='business-central', password=<any bcrypt>)`.
- **`LOOP_ENABLED_EVENTS`** (next-api `.env.local`) must include the event type, e.g. `RESILIATION,RETURN_CHANGE` — `LoopShipmentProvider.supports()` gates on it; wrong/missing → "No provider found". `cache:clear` after editing.
- **Order graph** wired to a viewable event: `order(external_id='{orderItemId}-inbound', event_uuid=<event>, state='ORDER_SHIPPED')` (NOT `ORDER_TO_SHIP` → returns false; NOT `ORDER_DELIVERED` → "already synchronized"). Needs an `order_line`(type PRODUCT) whose `product_variation.sku` == the NM SKU Loop sends (qty must match), a `shipment` on the order, AND a **SUBSCRIPTION `order_line` + an `offer_product_variation`** for its PV (else `InvoiceUpfrontService::handleAdditionalFees` derefs a null offer PV). Reuse an existing `product_variation` id to satisfy its `state_id`→`state` FK (the `state` table may be empty but FKs enforce on insert).
- **CRITICAL — pre-create the `shipment` but NOT a `shipment_line`.** `syncShipment` does `shipmentRepository->findOneBy(['order'=>id])` and returns `false` if **no shipment exists**, so the shipment row IS required. BUT `LoopShipmentProvider::createShipmentLines` skips any order_line that already has a shipment_line (`if (!is_null($orderLine->getShipmentLine())) continue;`), and `createShipmentLine()` is the ONLY place a `product_condition_sheet` (with the pictures) is created. So if you pre-seed a `shipment_line` for the order_line, the push transitions the event but **silently never creates the pcs/pictures** — vecna renders the diagnosis block with empty states and no picture tiles. Leave the order_line with NO shipment_line; the push creates the line + pcs. (The read path `getDiagnosisPictures(returnOrderId)` then finds the pcs on that freshly-created line — it does NOT need a pre-existing shipment_line.)
- The `[SHIPMENT-LOOP] shipment line loop imei (...) different from order line imei ()` log is a **red herring** — it's in `validateShipmentLines` at INFO level and does NOT throw or skip. An empty `order_line.serial_number` does not block pcs creation; set it only to silence the log.
- **Event must be in a state the `DEVICE_RECEIVE` transition accepts** (`AWAITING_DEVICE_RETURN` for RETURN_CHANGE), not already `DEVICE_RECEIVED`.
- Clear any existing `product_condition_sheet` for the order first, or the push is skipped ("Diagnosis already synchronized"). NOTE: the "already synchronized" skip keys on an **existing pcs**, NOT on order state — `ORDER_DELIVERED` does NOT block the diagnosis push (verified live on int: an `ORDER_DELIVERED` return order with no pcs pushes fine and renders). Only a pre-existing pcs skips it.

**4. Verify each hop** (don't trust "handled successfully" alone — the pcs is a NEW row each sync):
```bash
# a) Loop emits BARE picture UUIDs (the NMC-8 uuid-only contract; api-v2 PR #12165):
curl -s -H "x-api-key: test-vecna-api-key-for-tests" "http://localhost:4444/next-mobiles/diagnoses?from=<ISO>&to=<ISO>&serialNumber=<serial>"
#   -> pictures: ["<uuid>", ...]  (bare uuid, no path, no host)
#   next-api builds the resolver URL itself: LOOP_BASE_URL + '/next-mobiles/diagnoses/pictures/' + uuid
#   (LoopApiClient::resolvePictureUrl + DIAGNOSIS_PICTURES_PATH). The pcs.pictures column stores the bare uuids.
# b) event view returns proxy URLs (needs a vecna JWT):
TOKEN=$(curl -s -X POST localhost:8080/api/login -H 'Content-Type: application/json' -d '{"login":"qa@vecna.test","password":"test1234"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/event/<uuid>/diagnosis
# c) each picture resolves to real bytes (proxy -> Loop+LOOP_BASE_URL -> MinIO):
curl -sL -H "Authorization: Bearer $TOKEN" -o /dev/null -w '%{http_code} %{content_type} %{size_download}\n' localhost:8080/api/event/<uuid>/diagnosis/pictures/0
```

## Making the sync AUTO-transition to DEVICE_RECEIVED (zero manual steps)

The `return-diagnostic` sync is supposed to auto-run `applyDeviceReceivedTransition` → event `DEVICE_RECEIVED` (which the UI needs). Locally it silently rolls back (message "handled successfully" but state stays `AWAITING_DEVICE_RETURN`) because the compliant-device path in `LoopShipmentProvider::handleReturnOrder` → `InvoiceUpfrontService::handleAdditionalFees` hits several missing local prerequisites, each aborting the whole transaction. Fix ALL of these (local-only) so it completes on its own:

1. **Pricing API stub.** `handleAdditionalFees` unconditionally calls `PricingApiClient::getAdditionalFeeMatrix` (→ `matrix/calculate`) and it THROWS on any non-2xx. Locally `NXT_PRICING_BASE_URL` is unreachable. Stand up a tiny stub returning 200 `{}` for `/matrix/calculate` and `{"invoice_type":"COMPLIANT","regular_amount":0}` for `/upfront/observed`, e.g. a node http server on :7799. Point next-api at it: `.env.local` `NXT_PRICING_BASE_URL=http://host.docker.internal:7799/` (**must** end in `/` — the client concatenates `baseUrl.endpoint` with no separator, so no slash → `localhostmatrix/calculate`). **Restart the messenger consumer after** — env is read at process start; `cache:clear` alone doesn't reload a running consumer.
2. **Event data:** `expected_product_state` (e.g. `GOOD`) and the product's `category` (e.g. `SMARTPHONE`) must be non-null (MatrixInputDto requires them).
3. **Offer PV chain + CORRECT return-order shape (this is the crux — get it right and the REAL single-line push auto-transitions with ZERO manual steps).** VERIFIED against next-api PROD (`nextmobiles_prd`, via the mysql-nextmobile-prod MCP): **every** RETURN_ORDER that reaches `DEVICE_RECEIVED` has EXACTLY ONE order_line, and it is a **SUBSCRIPTION** line whose `product_variation.sku` IS the device SKU (e.g. `APPLIP16OUTR128`), `quantity=1`, and that PV has exactly one `offer_product_variation`. Shape distribution in prod: 100% `0 PRODUCT / 1 SUBSCRIPTION / 1 total` (37k+ orders, zero exceptions). So seed the return order as ONE subscription line carrying the device sku with an offer_product_variation — do NOT add a separate PRODUCT device line, and do NOT give the subscription a distinct `SUBSCRIPTION-*` sku. `handleReturnOrder` reads `getSubscriptionOrderLine()?.getProductVariation()->getOfferProductVariations()->first()`; with the single line being SUBSCRIPTION+device-sku, Loop's real one-line push (`no = device sku`) covers it → `isAllLinesShipped=true` → `handleAllLineShipped` → transition fires. (The earlier "add a distinct-sku subscription line beside the device product line" advice was WRONG — it produced a 2-line order the single-line push could never fully ship, which is what created the phantom "single-line-push limitation" below.)
4. **offer_product_variation deductible fields must be non-null floats.** For a `Conforme`/compliant return the code enters `determineReturnProductState` → builds `ProductDataInputDto` whose `deductibleRestoration/Break/Break2/Theft/Theft2` come from `offer_product_variation.restoration_costs / franchise_breakage / franchise_breakage_extra / franchise_theft / non_recovery_fee`. These are typed non-nullable `float`; a null throws `Argument #8 ($deductibleRestoration) must be of type float, null given` at `LoopShipmentProvider.php:~382`. Prod values (verified): `restoration_costs=0, franchise_breakage=0, franchise_breakage_extra=0, franchise_theft=45, non_recovery_fee=0`. Seed those.
5. **Audit lookup tables (Gedmo LoggableOverrideListener) — the transition's history write needs them:** seed `type_group(code='log_action')` + three `type_entry(type_group_id, name/code ∈ CREATE/UPDATE/REMOVE)`. Without these, every entity change during the commit throws "getTypeGroupCodeLogAction/getTypeEntryLogAction ... null returned".
6. **`state` FK:** creating any `product_variation` needs a `state` row (the table may be empty but the FK enforces on insert) — `INSERT INTO state(id,code,name) VALUES(1,'ACTIVE','active')` or reuse an existing PV.
7. **Event contract fields** (needed for the vecna event LIST to even render, `EventContractFactory` non-nullable ctor args): the `event` row must have non-null `reference` (e.g. `EVT-NMC8-002`), `incident_date`, and `return_product_locked` (0). A seed that omits any of these makes `GET /api/event/list` 500 (`Argument #N must be of type string/DateTimeInterface, null given`) and the whole "Gestion des évènements" screen shows a red server-error banner with an EMPTY list.

**~~all-lines-shipped caveat~~ (RESOLVED — was a seed-shape artifact, NOT a real limitation):** the real single-line `sendReturnDiagnostic` push DOES auto-transition a correctly-shaped return order (one SUBSCRIPTION line = device sku, per #3 above). Proven E2E: reshaped local order to the prod shape, fired the genuine one-line push (device sku only), event went `AWAITING_DEVICE_RETURN → DEVICE_RECEIVED` on its own, pcs + 3 pictures persisted, all three `/diagnosis/pictures/N` resolved to real 1920×1080 `image/jpeg`. The prior "must re-push BOTH lines" workaround was only necessary because the order had been mis-seeded with two lines.

## Making qualification photos upload as image/jpeg (no re-stamp)

Root cause of the `application/octet-stream` tiles: `FileService::attach` (api-v2 `src/modules/file/file.service.ts`) computes the mime for the DB row but calls `s3Service.upload(key, buffer)` **without** passing `ContentType`, so MinIO stores octet-stream. Local fix (this file is NOT in the NMC-8 PR diff, safe to patch locally, NEVER commit): pass it —
```ts
await this.s3Service.upload(file.s3key, fileInput.buffer, { ContentType: computedMimeType });
```
Restart Loop + jobs after. New qualifications then upload as `image/jpeg`; only pre-fix objects need the `aws s3 cp --content-type image/jpeg --metadata-directive REPLACE` re-stamp.

## Why the vecna diagnosis-pictures section shows NOTHING (even with data present)

Symptom: `GET /api/event/{uuid}/diagnosis` returns 200 with `pictures[]`, but the UI renders no diagnosis block at all. Causes, in order of likelihood:

1. **Event state gate (most common).** `Diagnosis.vue` wraps the ENTIRE block (values + `event-diagnosis-files` → pictures) in `v-if="showBlock"`, and `showBlock` requires `event.state ∈ {DEVICE_RECEIVED, DEVICE_LOCKED, AWAITING_UNLOCK, ADDITIONAL_FEES, CLOSED, DEVICE_UNLOCKED}`. A synced event stuck in `AWAITING_DEVICE_RETURN` shows nothing. Fix: `UPDATE event SET state='DEVICE_RECEIVED' WHERE uuid=...`. (The real sync's `applyDeviceReceivedTransition` does this; if it didn't stick, set it manually.)
2. **`v-if="pictures.length"`** in `DiagnosisFiles.vue` — needs the diagnosis endpoint to actually return a non-empty `pictures[]` (i.e. the pcs must be persisted — see Step 5).
3. **Tab**: `event-diagnosis` renders on the **Détails** tab of ReturnChange, not Logistique.

## Verifying the images actually render (headless caveat)

The chrome-devtools MCP drives its OWN headless Chromium (NOT your real Chrome — `list_pages` shows only its tabs; it cannot read a normally-launched Chrome unless that Chrome was started with `--remote-debugging-port` and the MCP pointed at it). To log in there: it's localStorage auth (`auth.JWT` + `auth.refreshToken`), but injecting tokens by hand fights the store's init/refresh — **just fill the login form and click Connexion** (creds pre-filled `qa@vecna.test`/`test1234`), then SPA-navigate via `location.hash = '#/dashboard/events/return-change/<uuid>'` (a full reload re-inits the store and can clear the injected session).

In headless Chromium, `<img>`/`q-img` blobs often stay `naturalWidth=0, complete=false` — a **paint artifact, NOT a failure**. To prove the images are genuinely valid, fetch each blob and `createImageBitmap(blob)`; real dimensions (e.g. 1920×1080) confirm they'll render in the user's real browser. Screenshot tiles may be blank for the same reason.

## Making a device diagnosable in admin (stock rights + state)

The Repairs "To qualify" list is a Hasura query gated by the user's assigned stocks. `useUserStocks` reads `users[].stockUsers[].stock` filtered to `REPAIR_STOCK_CODES` (MON/TAM/BEA + ENV when `allowReturnsToEnviro`); if empty → `userStockIds=[]` → the query is SKIPPED (`skip: userStockIds.length === 0`) → empty list. To fix (local postgres `postgres` DB, user is trust):
- **Assign the admin user to the repair stocks:** `INSERT INTO stock_users(stock_id,user_id,created_at,updated_at) SELECT s.id, <userId>, now(), now() FROM stocks s WHERE s.code IN ('MON','TAM','BEA','ENV')`. The dev JWT's `x-hasura-user-id` (67 = `lucas.mas@mobile.club`) is the user id.
- **Device must be in one of those stocks:** `stock_items.location_type='stocks'`, `location_id IN (repair stock ids)`, `item.item_type='Device'`, and `current_state.name='to_qualify'`.
- To reset a device to `to_qualify`: insert a `stock_item_states(name='to_qualify', resource_id=<stock_item_id>, from_id=<current_state_id>)` and point `stock_items.current_state_id` at the new row.
- Repair stock ids (this dump): MON=1, TAM=6, BEA=25, ENV=95.
- **Device `condition` must be `Refurbished`, NOT `New`.** In `QualificationForm.tsx` the entire Esthetic-condition block (the Screen/Border/Back photo-capture cards + `EstheticGradeSection`) is wrapped in `<div className={selectedCondition === DeviceCondition.New ? 'hidden' : ''}>` — a `New` device (blister-pack, direct storage) is intended to SKIP grading, so the whole grade+photo step collapses. Every prod device that qualified with photos is `Refurbished`. Seed/fix: `UPDATE stock_items SET condition='Refurbished' WHERE id=<stock_item_id>`. (Distinct from the hasura-remote-schema gotcha above: `New` hides the WHOLE esthetic block permanently; the stale remote schema hides only the grade SUMMARY card. Both present as "grade area not usable".)
- **The Esthetic grade summary card is empty until all 3 components are graded — this is BY DESIGN, not a bug.** `EstheticGradeSection` returns null when `!loading && !suggestedGrade`; `suggestedGrade` is only computed by `useSuggestedGrade` once `screenBlock` + `border` + `back` are all set (it then fires `logistic_computeEstheticGrade`, a pure computation — no DB/seed dependency). So the correct operator flow is: pick a grade radio + Take photo for EACH of Screen/Border/Back → the grade card then populates and stays → pick Final grade → Submit. If the card still won't populate after all 3 are graded, THEN suspect the stale hasura remote schema (above).

## Cross-stack MCP gotcha: which DATABASE the ephemeral/services read

The `postgres-staging` MCP reads DB `mobileclub`; PR-ephemeral envs + some services read **`mobileclub_next`** (same RDS host, different DB — see `HASURA_GRAPHQL_DATABASE_URL` SSM param). Test data that qualifies in one DB may be unmapped in the other. Read the DB the target actually uses (psql the URL from SSM). SSM keys read with `aws ssm get-parameter --with-decryption` (authed as `user/lucas`); the api key is 64 chars — don't truncate.

## Local dev patches (per-worktree, NEVER commit)

Every blocker in local dev is a config artifact, not a feature bug — prod uses real domains on :443 and a real S3 bucket. Re-apply these to a fresh worktree; keep them OUT of the feature branch diff.

- **api-v2 `src/utils/aws-signature.ts`** — patch `generatePresignedUrl` to PATH-STYLE: prepend `/{bucket}` to canonicalUri + signed URL when host isn't bucket-qualified (browser can't resolve `*.localhost` vhost style).
- **api-v2 `.env`** — `S3_ENDPOINT=http://localhost:9000`.
- **admin `src/utils/apollo-client.tsx`** — in dev, `authLink` sends `x-hasura-admin-secret`; add a `VITE_DEV_API_JWT` Bearer override (user's staging Auth0 is `readonly`-only and can't pass api-v2's logistic guards or see `stock_items`).
- **admin `.env`** — `VITE_DEV_API_JWT=<HS256 jwt>` (signed with api-v2 test secret `secretsecretsecretsecretsecretsecret`; claims `x-hasura-default-role:admin`, `x-hasura-user-id:67`, exp `1893450000`). Point admin at hasura `:9090`.
- **next-api `docker/nginx.conf`** — PHP location: `fastcgi_param HTTP_HOST localhost:8080;` + `SERVER_PORT 8080;` (else proxy URLs build port-less `http://localhost/...` → dead → broken tiles). After editing: `docker cp docker/nginx.conf symfony_app:/etc/nginx/nginx.conf && docker compose exec -T app nginx -s reload`.
- **next-api `config/packages/routing.yaml`** — `when@dev default_uri: http://localhost:8080` (belt-and-suspenders for CLI URL generation).
- **next-api `docker-compose.override.yaml`** — `extra_hosts: ["host.docker.internal:host-gateway"]`.
- **next-api `.env.local`** — dummy env keys so the container boots; `LOOP_BASE_URL=http://host.docker.internal:4444`, `LOOP_API_KEY=test-vecna-api-key-for-tests`. For the diagnosis push E2E also: `LOOP_ENABLED_EVENTS=RESILIATION,RETURN_CHANGE` (the event type must be listed or the sync throws "No provider found").
- **api-v2 `.env`** — for the diagnosis PUSH E2E: `VECNA_API_URL=http://localhost:8080/api` (default `:7788` has nothing behind it). See "Step 5".
- **vecna-front `.env`** — `VITE_API_BASEURL=http://localhost:8080/api`, `VITE_FEAT_EVENTS=true`.

**Fresh-worktree dep drift:** a branch may add deps (e.g. admin `auth0-js`) that this worktree never installed → Vite "Failed to resolve import". Fix: `pnpm install --filter <pkg>` (or root `pnpm install`), then restart that dev server. Check `package.json` vs `node_modules` before assuming a code bug.

When you finish: leave these uncommitted, and strip any leftover debug logging before any commit (e.g. any temporary `file_put_contents` trace added to `SyncShipmentMessageHandler` to surface a wrapped exception). `git status` may show `schema.gql` modified — that's codegen drift, ignore.

## Seed test data (only if the dump was reset)

The full path needs a real qualified device whose diagnosis surfaces via Loop PULL. To create one:

1. Find / use a NM-mapped device in state `to_qualify` (most are `assigned`/`rented`). Qualify it through the admin screen — that runs `logistic_qualifyDevice` → uploads 3 component photos (screenBlock/border/back) to MinIO under `stock_item_tests/<test_id>/`.
2. **PULL filter:** a diagnosis only surfaces if it has a `postingDate` = MAX(`carrier_shipped_at`) over the ORDER's parcels (`DiagnosesTypeOrm.loadPostingDates`). If the device has no parcel, insert one: `parcels` row `from_type='orders'`, `from_id=<order_id>`, `carrier_shipped_at` set, plus a `parcel_stock_item` link to the stock_item.
3. **Content-type fix:** `qualifyDevice` uploads with no content-type → `application/octet-stream` → browser won't decode. Fix each object: `aws s3 cp s3://<bucket>/<key> s3://<bucket>/<key> --content-type image/jpeg --metadata-directive REPLACE --endpoint-url http://localhost:9000`.

## Cold host (volumes / dump / MCP gone)

- **Postgres dump:** restore the staging dump into `mobile-club-db` (dumps were at `<orchestrator>/db/db.dump.staging-fresh`). Schema must be current and contain photo-bearing tests.
- **chrome-devtools MCP blank/Chrome-not-found:** `/home/lmas/dotfiles/.claude/bin/chrome-devtools-mcp-headed-wrapper.sh` must pass `--executablePath=/usr/lib64/chromium-browser/chromium-browser` (it otherwise defaults to Google Chrome at `/opt/google/chrome/chrome`, not installed). Override env: `CHROME_DEVTOOLS_MCP_EXECUTABLE`.
- **Node 22.22:** `nvm install 22.22.0` if missing.

## Credentials (local only)

- vecna-front: `qa@vecna.test` / `test1234`
- admin: user's Google/Auth0 (`lucas.mas@mobile.club`) — user drives login
- MinIO console (`:9001`): `minioadmin` / `minioadmin`
- Loop API key header: `x-api-key: test-vecna-api-key-for-tests`
- hasura-admin secret: `kyhBJFNpMRPwoERdl0ypYX2dNjEVHoVD`
- mysql: `symfony` / `symfony` (root `root`); postgres: `postgres` no password (trust)
