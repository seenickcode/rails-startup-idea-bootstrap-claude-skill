---
name: webapp-bootstrap
description: Spin up a new production Rails 8 site on the shared Hetzner VPS — buys/configures the domain on Cloudflare, generates a minimal SQLite+Tailwind app with magic-link auth, Postmark email, sender.net newsletter, PostHog, Stripe one-off Checkout, deploys with Kamal, enables Litestream backups to R2, and health-checks the result. Usage - /webapp-bootstrap example.com
---

# /webapp-bootstrap <domain>

Creates and deploys a complete new site for `<domain>`. Everything runs from
`SKILL_DIR = ~/.claude/skills/webapp-bootstrap` (scripts/, templates/).

## 0. Preflight

1. `set -a; source ~/.config/webapp-bootstrap/.env; set +a` before every script. If the
   file is missing, copy `templates/env.example` to `~/.config/webapp-bootstrap/.env`,
   tell the user to fill it, and STOP.
2. Check required env vars are non-empty: VPS_SSH_HOST, VPS_SSH_USER,
   CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, R2_ACCOUNT_ID,
   R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, GITHUB_USER,
   GITHUB_TOKEN, POSTMARK_SERVER_TOKEN, POSTMARK_ACCOUNT_TOKEN, ADMIN_EMAIL,
   SENDER_API_TOKEN, STRIPE_SECRET_KEY (rk_live_ restricted key), and at least
   one of POSTHOG_PERSONAL_API_KEY / POSTHOG_SHARED_PROJECT_KEY. List any
   missing and STOP.
3. Tailscale is REQUIRED: SSH to the VPS is tailnet-only (public IP serves
   only 80/443 — this hardening is deliberate, don't work around it). Check
   `tailscale status` shows connected and
   `ssh -o ConnectTimeout=5 $VPS_SSH_USER@$VPS_SSH_HOST true` succeeds; if
   not, tell the user to run `sudo tailscale up` and STOP.
   Then resolve the public IP for DNS: use $VPS_PUBLIC_IP if set, else
   `ssh $VPS_SSH_USER@$VPS_SSH_HOST 'curl -4 -s ifconfig.me'` (sanity-check
   it's a routable IPv4, not a 100.x tailnet address) and use that wherever
   this document says $VPS_PUBLIC_IP.
4. Check tools: `ruby -v` (need 3.4+), `rails -v` (need 8.x), `gh auth status`,
   `kamal version` (else `gem install kamal`), `jq`, `docker` (needed locally
   only if not using remote builder). Offer install commands for anything missing.
5. Derive: `APP` = domain with `.` and `-` → `_` (e.g. `example_com`).
   Project dir: `~/code/<domain-without-tld>` (ask if it already exists).
6. Ask the user (one AskUserQuestion): use an existing STRIPE_PRICE_ID,
   create a sample product (default: `stripe.sh create-product "<domain> sample
   product" 500` → $5.00 price id), or skip (buy button hidden until set).

## 1. Domain + Cloudflare

Use `scripts/cloudflare.sh` (env already sourced).

1. `cloudflare.sh zone-id <domain>` — if a zone exists, skip to step 3.
2. Try `cloudflare.sh buy-domain <domain>`. Cloudflare Registrar's API does
   not support all TLDs/accounts — if the response is not success, tell the
   user to buy the domain in the Cloudflare dashboard (or elsewhere) and wait
   for their confirmation before continuing.
3. `cloudflare.sh create-zone <domain>` (idempotent-ish: 1061 = already
   exists, fine). If the domain was bought outside Cloudflare, print the
   nameservers (`cloudflare.sh nameservers <domain>`) and tell the user to set
   them at the registrar; poll zone status until `active`.
4. Create A records — **grey-cloud first** so kamal-proxy can pass the
   Let's Encrypt HTTP-01 challenge directly (orange-cloud + always-HTTPS
   breaks issuance). Create with `proxied:false` by editing the call, or
   create then PATCH: apex `@` and `www` → `$VPS_PUBLIC_IP`.
5. Postmark DNS (see step 2 output): DKIM TXT record, and
   `CNAME pm-bounces.<domain>` → `pm.mtasv.net` **DNS-only (grey cloud)**.
   SPF TXT on apex: `v=spf1 include:spf.mtasv.net ~all`
   (keep `~all`, not `-all` — a hard fail turns anything forgotten into a
   silent bounce). Add `include:sendersrv.com` too (sender.net campaigns).

## 2. Postmark domain

1. `postmark.sh add-domain <domain>` → note `ID`, `DKIMPendingHost`,
   `DKIMPendingTextValue`, `ReturnPathDomain`/`ReturnPathDomainCNAMEValue`.
2. Create those DNS records via `cloudflare.sh create-dns` (TXT/CNAME need a
   raw curl — same auth pattern; pm-bounces CNAME must be `proxied:false`).
3. Wait ~1 min, then `postmark.sh verify-dkim <id>` and
   `postmark.sh verify-return-path <id>`; retry a few times (DNS propagation).
   If still unverified after ~10 min, continue but WARN loudly: sign-in email
   will not work until verified — print the pending records.
4. From address for the site: `hello@<domain>`.

## 3. sender.net group

If `SENDER_GROUP_ID` is blank in the env: `sender.sh create-group <domain>` and
use the returned id for this site (do NOT write it back to the global .env —
it's per-site, pass it into Kamal secrets below).

## 3a. R2 bucket (one per site)

`cloudflare.sh create-bucket <domain-with-dots-as-hyphens>` (e.g.
`example-com`; error 10006 = already exists, fine). This name is the
`__R2_BUCKET__` substitution for litestream.yml.

## 3b. PostHog project (one per site)

If POSTHOG_PERSONAL_API_KEY is set: `posthog.sh create-project <domain>` →
the printed `phc_...` token is this site's POSTHOG_API_KEY. On ERROR (e.g.
free plan allows one project), fall back to POSTHOG_SHARED_PROJECT_KEY and
tell the user which happened. If only the shared key is set, use it directly.

## 3c. Sentry project (one per site)

If SENTRY_AUTH_TOKEN is set: `sentry.sh create-project <domain>` → prints the
slug, then `sentry.sh get-dsn <slug>` → the site's SENTRY_DSN. If the project
already exists, just get-dsn. On error, warn and continue without Sentry.

## 4. Generate the Rails app

```
rails new <dir> --database=sqlite3 --css=tailwind --skip-jbuilder \
  --skip-action-mailbox --skip-action-text --skip-active-storage \
  --skip-action-cable --skip-solid --skip-kamal
```
Then add back solid_queue only: `bundle add solid_queue`, run
`bin/rails solid_queue:install`, give production a multi-db block in
database.yml (primary + queue with `migrations_paths: db/queue_migrate`), and
CRITICALLY add to config/puma.rb:
`plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`
— without the plugin line no worker runs and every deliver_later email
silently sits in the queue forever. deploy.yml sets SOLID_QUEUE_IN_PUMA=true.
Note: `--skip-kamal` because we use our own deploy.yml; `gem "kamal"` still
goes in the Gemfile dev group.

Gems to add: `postmark-rails`, `posthog-ruby`, `stripe`, `sentry-ruby`,
`sentry-rails`, and in development: `letter_opener_web`. No custom fonts anywhere — Tailwind defaults only; do not
add font links or @theme font overrides.

Copy template files from `SKILL_DIR/templates/`:
- `app/**` → same paths in the project (migration goes to
  `db/migrate/<timestamp>_create_users.rb`).
- `config/initializers/{mail,posthog,stripe,required_env}.rb`
- `config/initializers/sentry.rb` (inactive when SENTRY_DSN is unset —
  monitoring is optional)
- `config/routes.rb` (replace generated one)
- `config/litestream.yml` and `config/deploy.yml` — substitute `__APP__`,
  `__DOMAIN__`, `__VPS_SSH_HOST__, __VPS_SSH_USER__`, `__GH_USER__`, `__ARCH__` (from
  `ssh $VPS_SSH_USER@$VPS_SSH_HOST uname -m`: x86_64→amd64, aarch64→arm64),
  `__R2_BUCKET__`, `__R2_ACCOUNT_ID__`, `__POSTMARK_FROM_EMAIL__`
  (hello@<domain>), `__ADMIN_EMAIL__`, `__POSTHOG_HOST__`.
- `deploy.sh` → project root, keep it executable. Later deploys are
  `./deploy.sh` on the VPS checkout (rbenv PATH, `git pull`, `kamal deploy`).

Wire-up edits in the generated app:
- development.rb: `delivery_method = :letter_opener_web`,
  `perform_deliveries = true`, `default_url_options = { host: "localhost", port: 3000 }`.
- production.rb: `config.hosts << "<domain>" << "www.<domain>"` and
  `config.host_authorization = { exclude: ->(r) { r.path == "/up" } }`.
  CRITICAL: every proxy host in deploy.yml must also be in config.hosts —
  /up is excluded so a missing entry still passes the healthcheck while the
  site is blocked.
- Layout `application.html.erb`: render `shared/_posthog` before `</head>`,
  and replace the generated `<body>` with zero-CSS 1995 chrome (no classes):
  ```erb
  <body>
    <nav>
      <%= link_to "Home", root_path %> |
      <% if signed_in? %>
        <%= button_to "Sign out", signout_path, method: :delete %>
      <% else %>
        <%= link_to "Sign in", signin_path %>
      <% end %>
    </nav>
    <hr>
    <main><%= yield %></main>
    <hr>
    <footer><small>&copy; <year> <domain></small></footer>
  </body>
  ```
- `app/assets/tailwind/application.css`: overwrite with the template's
  version (utilities only, NO preflight) — the site renders with pure
  browser defaults (Times New Roman, native buttons) while Tailwind
  utilities stay available. Never re-add `@import "tailwindcss"` wholesale.
- Webhook CSRF: `Webhooks::StripeController` is ActionController::API — no
  change needed.
- `db/seeds.rb`: leave empty.
- Dockerfile: add a GIT_REVISION build arg written to a REVISION file (for
  Sentry release attribution), failing the build if missing:
  `ARG GIT_REVISION` / `RUN test -n "$GIT_REVISION" && echo "$GIT_REVISION" > REVISION`
  (deploy.yml passes it via builder args).

Copy the test suite from `SKILL_DIR/templates/test/` → `test/` (replaces
test_helper.rb; covers auth flow, newsletter incl. subscriber confirmation,
Stripe webhooks, homepage, plus a real-browser smoke test in test/system/). Run `bin/rails test` — all must pass.
Rails' generated `.github/workflows/ci.yml` runs rubocop + brakeman + tests
(+ a `system-test` job). KEEP the system-test job: the template ships
`test/application_system_test_case.rb` + `test/system/smoke_test.rb` (headless
Chrome; fails on console errors, broken assets/JS). Chrome isn't installed
locally, so system tests run in CI only — verify via the CI gate below.
CI runs on every push: run `bin/rubocop -a` before committing, and keep the Gemfile
on a Rails version brakeman considers maintained (its EOL check fails CI).

Local verification before deploying (fix anything that fails):
```
bin/rails db:prepare && bin/rails test:prepare 2>/dev/null; bin/rails runner "puts User.count"
bin/rails tailwindcss:build && SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
```
Boot `bin/rails s` briefly and curl `localhost:3000` — expect "hello".

## 5. GitHub repo

```
git init && git add -A && git commit -m "Initial commit"
gh repo create <GITHUB_USER>/<APP> --private --source . --push
```
Ensure `.gitignore` covers `config/master.key` and `.kamal/secrets`.

## 6. Kamal secrets

Write `.kamal/secrets` (gitignored):
```
KAMAL_REGISTRY_PASSWORD=$GITHUB_TOKEN
RAILS_MASTER_KEY=<contents of config/master.key>
POSTMARK_API_TOKEN=$POSTMARK_SERVER_TOKEN
SENDER_API_TOKEN=...
SENDER_GROUP_ID=<per-site id from step 3>
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=<from step 8 — placeholder "pending" for first deploy>
STRIPE_PRICE_ID=<from preflight, or empty>
POSTHOG_API_KEY=<per-site phc_ key from step 3b>
SENTRY_DSN=<per-site DSN from step 3c; omit line if Sentry skipped>
LITESTREAM_ACCESS_KEY_ID=$R2_ACCESS_KEY_ID
LITESTREAM_SECRET_ACCESS_KEY=$R2_SECRET_ACCESS_KEY
```

## 7. VPS bootstrap + deploy

1. `scripts/bootstrap-vps.sh $VPS_SSH_USER@$VPS_SSH_HOST` — idempotent (Docker,
   ports 80/443). Expect `BOOTSTRAP_OK`.
2. `docker login ghcr.io -u $GITHUB_USER -p $GITHUB_TOKEN` (and the same on
   the VPS if pulls fail).
3. `kamal setup` (first time; later deploys are `./deploy.sh`). If the shared
   VPS already runs kamal-proxy for other apps, setup coexists fine — the
   proxy routes by host.
4. `kamal accessory boot litestream` — `kamal deploy` ignores accessories, so
   this is a required explicit step.
5. Verify certificate issuance: `curl -sSI https://<domain>` from the VPS or
   locally (still grey-cloud, so this hits kamal-proxy directly).

## 8. Stripe webhook

`stripe.sh create-webhook <domain>` → whsec_... Put it in `.kamal/secrets` as
STRIPE_WEBHOOK_SECRET and `kamal env push && kamal app boot` (or redeploy).

## 9. Flip Cloudflare on

Only after the origin serves valid TLS (step 7.5):
1. PATCH both A records to `proxied:true`.
2. `cloudflare.sh configure-ssl <zone_id>` — Full (strict) + always-HTTPS.

## 10. Health check + report

`scripts/health-check.sh <domain>` (expects HEALTH_OK / "hello").

End-to-end email smoke test — proves the whole chain (form → CSRF → job
queue → Postmark → Sent), not just an app-side ack:
1. Fetch `https://<domain>/signin`, extract the `authenticity_token` and
   cookie, POST the form to `/auth` with ADMIN_EMAIL (expect 302).
2. `scripts/verify-email.sh $ADMIN_EMAIL` — polls the Postmark outbound API
   until the message status is literally `Sent` (EMAIL_OK). EMAIL_FAIL means
   the queue worker or Postmark is broken even though the site looks healthy.

CI gate (required before reporting live): after the last push, run
`gh run watch $(gh run list -b main -w CI -L1 --json databaseId -q '.[0].databaseId') --exit-status`.
If it fails, `gh run view <id> --log-failed`, fix, push, and re-watch. Never
report the project as live while CI on the default branch is red; if you
can't fix it, say so explicitly in the report. Dependabot PRs opened before a
CI fix will stay red until rebased; mention them rather than counting them.

Final report to the user (include CI status and test count): URL, repo URL, Postmark verification status,
sender.net group id, Stripe webhook id, backup location
(`s3://<domain-bucket>/<domain>/production`), letter_opener at
`http://localhost:3000/letter_opener` in dev, and how to restore:
`litestream restore -config config/litestream.yml /rails/storage/production.sqlite3`.

## Environment notes

- Ruby may not be on PATH in Claude's shell: `export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" RBENV_VERSION=3.4.2`.
- `--skip-kamal` means no `bin/kamal`: use `bundle exec kamal`.
- `bootstrap-vps.sh` fails on `sudo systemctl` without passwordless sudo; if Docker and kamal-proxy already run on the VPS, that's fine to skip.
- Domains at another registrar (e.g. Hover): create the zone, set the registrar's nameservers to Cloudflare's, and delete imported parking A records before adding ours.

## Failure handling

- Any Cloudflare/Postmark/Stripe API error: show the raw JSON, don't guess.
- DNS propagation steps: poll with backoff up to ~10 min, then surface what's
  pending and continue where safe (Postmark verify), stop where not (zone
  not active).
- Never store new secrets in the repo; per-site secrets live only in
  `.kamal/secrets`.
