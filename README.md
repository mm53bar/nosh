# nosh

A self-hosted Rails app for a household's recipes, weekly meal planning, and the shopping list
that falls out of it.

> *Nosh*: informal slang for food — short, plain, no metaphor required.

## Status

Rebuilt from an earlier Node/Express app, and in daily use since August 2026. Recipe CRUD
(ingredients, steps, tags, ratings, cuisine/meal-type, photos via Active Storage), a weekly
meal-plan grid, a wall-screen mode for cooking from (see below), and a shopping list that scales
ingredient quantities to planned servings and publishes into a Home Assistant to-do list rather
than being read here — see
[`docs/adr/20260815-shopping-list-publishes-to-home-assistant.md`](docs/adr/20260815-shopping-list-publishes-to-home-assistant.md).
No login system — see
[`docs/adr/20260809-no-auth-needed.md`](docs/adr/20260809-no-auth-needed.md). See
[plan.md](plan.md) for the build plan and [docs/adr/](docs/adr/) for design records.

## Local development

```bash
# Install Ruby via mise (version pinned in .mise.toml)
mise install

# Install gems
bundle install

# Set up the database
bin/rails db:prepare

# Start the dev server (Rails + Tailwind watcher)
bin/dev
```

Visit `http://localhost:3000`.

Run the test suite:

```bash
bin/rails test
```

Run the same checks CI runs:

```bash
bin/brakeman --no-pager && bin/bundler-audit && bin/importmap audit && bin/rubocop
```

## Kitchen screen

`/kitchen` is a separate, chrome-free set of screens meant for a tablet or wall display in the
kitchen: a week-at-a-glance grid and a recipe view with ingredients and method side by side, in
larger type, with tap-to-track step progress. It's built to be embedded in a Home Assistant
dashboard, so `X-Frame-Options` is replaced by a CSP `frame-ancestors` policy — see
[`docs/adr/20260812-framed-by-home-assistant.md`](docs/adr/20260812-framed-by-home-assistant.md).

Two URL params, which ride along on every link so they survive navigation on a device with no
address bar:

| Param | Effect |
|---|---|
| `?theme=dark` / `?theme=light` | force a palette; anything else follows `prefers-color-scheme` |
| `?embed=1` | leave the top-left corner clear for a host's floating button |

The recipe screen carries a **Keep awake** switch, which holds two different things off depending
on where it's running: a Screen Wake Lock on an ordinary tablet, and — in a kiosk that returns to
its own home screen after a couple of idle minutes — a renewable lease requested from the page
framing nosh over `postMessage`. It shows itself only where one of those can actually work, so it's
absent rather than dead elsewhere. The contract, and why it isn't just a wake lock, is in
[`docs/adr/20260821-keep-awake-is-two-backends.md`](docs/adr/20260821-keep-awake-is-two-backends.md).
`test/harness/keep_awake_host.html` is a stand-in host page for exercising nosh's half of it
without the kiosk; serve it over loopback (the frame-ancestors policy allows `localhost` and
`127.0.0.1`, but not a `file://` page).

## Production deployment (Docker Compose)

nosh has no authentication — it must only run somewhere that isn't publicly reachable (a reverse
proxy resolving internally only, or a LAN-only bind). See
[`docs/adr/20260809-no-auth-needed.md`](docs/adr/20260809-no-auth-needed.md).

1. Copy `compose.yaml` into your stack (Arcane/Portainer or plain `docker compose`) and edit it
   for your host: the volume path, the `user:` UID:GID that owns it, and `SECRET_KEY_BASE`
   (generate with `openssl rand -hex 64`).
2. `docker compose up -d`.

Secrets are read from the environment — see
[`docs/adr/20260809-secrets-from-env.md`](docs/adr/20260809-secrets-from-env.md). Background jobs
run inside the web container via Solid Queue, so there's no separate worker to deploy.

The image is built by GitHub Actions and published to `ghcr.io/mm53bar/nosh:latest` (and
`:<short-sha>` for pinning). If you're running a fork, point the `image:` line in `compose.yaml`
at your own registry.

## JSON API

Every resource has a JSON representation alongside its HTML view (`Accept: application/json` or a
`.json` suffix) — `recipes`, `meal_plan_entries`, `shopping_list`, `shopping_list_items`,
`stats`. This is a normal Rails resourceful API, **not** byte-compatible with the old
app's `/api/*` paths — see
[`docs/adr/20260809-idiomatic-api-not-byte-compatible.md`](docs/adr/20260809-idiomatic-api-not-byte-compatible.md)
if you're porting an existing integration.
