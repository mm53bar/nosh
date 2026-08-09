# 20260809 — Secrets come from env vars, not Rails encrypted credentials

## Context

This repo is public. Rails' default encrypted-credentials workflow
(`config/credentials.yml.enc` + `config/master.key`) commits an encrypted file to the repo and
keeps the decryption key out of it — safe in principle, but it's one more thing for every clone
of a public repo to get right, and a committed `credentials.yml.enc` from the original author's
deployment would be a shared secret across every fork if anyone ever encrypted a real value into
it by mistake.

## Decision

Runtime configuration and secrets — `SECRET_KEY_BASE` at minimum — are read from environment
variables (`compose.yaml`), not Rails credentials. `config/master.key` and
`config/credentials.yml.enc` are deleted and git-ignored; nothing in the app calls
`Rails.application.credentials`. Rails 8.1 resolves `ENV["SECRET_KEY_BASE"]` before consulting
credentials, so this needs no extra code — just not generating the credentials file in the first
place.

An operator who prefers Rails' encrypted-credentials workflow can still bring their own
`config/master.key` + `config/credentials.yml.enc` locally; nothing prevents it, it's just not
required to boot, and the repo will never ship one.

## Consequences

- `docker run`/`compose.yaml` must set `SECRET_KEY_BASE` explicitly — there's no fallback baked
  into the image.
- Cloning the repo and running it requires no key material at all beyond that one env var.
- Anyone extending the app with a feature that wants a secret (an API token, say) should add it
  as an env var read via `ENV.fetch`, and — per
  `docs/adr/20260809-settings-in-database.md` — consider whether it's actually operator-editable
  runtime config that belongs in the `Setting` model instead.

## Alternatives considered

- **Rails encrypted credentials as the primary mechanism.** Rejected: heavier for a public repo
  with no real ops team behind it — every clone would need to either generate its own credentials
  file or rely on env vars anyway for the one secret Rails absolutely requires, so committing to
  env vars from the start is simpler and matches `blip`/`tsundoku`.
