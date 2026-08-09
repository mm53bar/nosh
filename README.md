# nosh

A self-hosted Rails app for a household's recipes, weekly meal planning, and the shopping list
that falls out of it.

> *Nosh*: informal slang for food — short, plain, no metaphor required.

## Status

Active rebuild of an earlier Node/Express app. Recipe CRUD (ingredients, steps, tags, ratings,
cuisine/meal-type, photos via Active Storage), a weekly meal-plan grid, and shopping-list
generation that scales ingredient quantities to planned servings. No login system — see
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
`settings`, `stats`. This is a normal Rails resourceful API, **not** byte-compatible with the old
app's `/api/*` paths — see
[`docs/adr/20260809-idiomatic-api-not-byte-compatible.md`](docs/adr/20260809-idiomatic-api-not-byte-compatible.md)
if you're porting an existing integration.
