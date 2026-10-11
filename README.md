# webapp-bootstrap

A [Claude Code](https://claude.com/claude-code) skill that takes a domain name and
ends with a live, production Rails 8 site — domain, DNS, email, payments,
analytics, error tracking, backups and deploy all wired up.

```
/webapp-bootstrap example.com
```

## What you get

A minimal SQLite + Tailwind Rails 8 app, deployed with Kamal to your own VPS:

- **Magic-link auth** — passwordless sign-in by email, no Devise
- **Transactional email** via Postmark (DKIM + return-path DNS configured automatically)
- **Newsletter signup** via sender.net, with a per-site subscriber group and confirmation email
- **One-off payments** via Stripe-hosted Checkout, with a verified webhook
- **Analytics** via PostHog (one project per site, or a shared key on the free tier)
- **Error tracking** via Sentry (optional, errors only to stay on the free tier)
- **Continuous SQLite backups** via Litestream to a per-site Cloudflare R2 bucket
- **Background jobs** via Solid Queue running inside Puma
- **TLS** via Let's Encrypt through kamal-proxy, then Cloudflare proxy in Full (strict) mode
- **Tests** for the auth flow, newsletter, Stripe webhooks and homepage, plus GitHub CI
- **Deliberately plain 1995 styling** — browser defaults, Tailwind utilities available, no preflight

## What the skill does

1. **Preflight** — loads your env file, checks tools and Tailscale connectivity
2. **Domain + DNS** — buys the domain via Cloudflare Registrar (or prompts you to), creates the zone, A records, SPF
3. **Postmark** — adds the sender domain, writes DKIM/return-path records, verifies them
4. **Per-site resources** — sender.net group, R2 bucket, PostHog project, Sentry project
5. **Generate the app** — `rails new`, gems, templates from `templates/`, local test + build verification
6. **GitHub** — creates a private repo and pushes
7. **Deploy** — bootstraps the VPS (Docker), `kamal setup`, boots the Litestream accessory
8. **Stripe** — creates the webhook endpoint and pushes its secret
9. **Cloudflare on** — flips records to proxied, sets Full (strict) + always-HTTPS
10. **Verify** — health-checks the homepage and runs an end-to-end email test that waits for Postmark to report `Sent`

See [`SKILL.md`](SKILL.md) for the full step-by-step instructions Claude follows.

## Requirements

**Infrastructure**

- A VPS (built for Hetzner, any Linux host with SSH + sudo works) reachable over
  [Tailscale](https://tailscale.com). The skill assumes SSH is tailnet-only and the
  public IP serves just 80/443.
- Accounts: Cloudflare, GitHub, Postmark, sender.net, Stripe, PostHog. Sentry is optional.

**Local tools**

Ruby 3.4+, Rails 8.x, `gh` (authenticated), `kamal`, `jq`, `docker`, `tailscale`.

## Install

```sh
git clone https://github.com/seenickcode/rails-startup-idea-bootstrap-claude-skill.git \
  ~/.claude/skills/webapp-bootstrap

mkdir -p ~/.config/webapp-bootstrap
cp ~/.claude/skills/webapp-bootstrap/templates/env.example ~/.config/webapp-bootstrap/.env
chmod 600 ~/.config/webapp-bootstrap/.env
```

Fill in `~/.config/webapp-bootstrap/.env`. Every value has inline instructions for
where to get it and exactly which permissions/scopes the token needs.

Then, in Claude Code:

```
/webapp-bootstrap yourdomain.com
```

## Layout

```
SKILL.md            Instructions Claude follows, step by step
scripts/            Thin API wrappers: Cloudflare, Postmark, sender.net, Stripe,
                    PostHog, Sentry, VPS bootstrap, health + email checks
templates/
  app/              Controllers, models, mailers, views, services copied into the new app
  config/           Initializers and routes
  test/             Test suite copied into the new app
  deploy.yml        Kamal config (placeholders like __DOMAIN__ are substituted)
  litestream.yml    Backup config
  env.example       Global credentials file template
```

## Secrets

- Global credentials live only in `~/.config/webapp-bootstrap/.env`, outside any repo.
- Per-site secrets (webhook secret, project keys, master key) live only in each
  generated app's gitignored `.kamal/secrets`.
- The skill creates real, billable resources (domains, Stripe objects, cloud
  projects) and uses a **live** Stripe key. Read `SKILL.md` before running it.
