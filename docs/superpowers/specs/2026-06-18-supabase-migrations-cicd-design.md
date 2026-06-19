# Supabase Schema-as-Code Migrations + Web Deploy — Design

**Date:** 2026-06-18
**Status:** Approved (design); implementation plan pending

## Problem

The project (Flutter app + hosted Supabase) has no representation of its database
schema in the repository. Schema changes are made ad hoc against the cloud project
(dashboard / MCP). There is no way to:

- review a schema change in a pull request,
- reproduce the schema from scratch, or
- apply a schema change automatically as part of deployment.

Goal: manage the Postgres schema as versioned code in the repo, and apply pending
migrations in CI/CD **before** the app is deployed.

## Decisions (from brainstorming)

| Decision | Choice |
|----------|--------|
| Approach | Supabase CLI migrations committed to the repo (Option A) |
| Environments | Single production project (no staging, no preview branches) |
| App deploy target | Flutter **web** → GitHub Pages |
| Local testing | Full local stack via Docker (`supabase start` / `db reset`) |
| CI auth | `supabase link` using `SUPABASE_ACCESS_TOKEN` + `SUPABASE_DB_PASSWORD` secrets |
| Deploy ordering | `migrate` job gates `deploy-web` via `needs:` |

Explicitly **out of scope** (YAGNI): staging environment, Supabase Branching /
per-PR preview databases, Play Store / Android release deploy. The structure must
not preclude adding a staging environment later.

## Current State (verified)

- Flutter app, single hosted Supabase project; URL + anon key live in `.env.json`
  (consumed via `--dart-define-from-file=.env.json`).
- Supabase client used from `lib/main.dart`, `lib/app.dart`, and several
  `lib/features/**/providers/*.dart` — **clients talk to Supabase directly**, so
  RLS is the only thing protecting data.
- CI: `.github/workflows/pr-checks.yml` runs analyze / test / build APK (debug) on
  PRs to `main`. No deploy pipeline exists.
- No `supabase/` directory yet.
- Tooling gaps: Supabase CLI **not installed**; Docker installed but daemon **not
  running**.
- `.env.json` is **not** tracked by git but is **not** in `.gitignore` (risk of
  accidental commit). It holds only the publishable anon key + URL (low
  sensitivity), but should be ignored regardless.

## Architecture

### 1. Schema as code

```
supabase/
  config.toml                       # supabase init; project_id = <ref>
  migrations/
    <timestamp>_baseline.sql        # captured from existing cloud schema
  seed.sql                          # optional, local-only seed data
```

- `supabase init` scaffolds `supabase/`.
- `supabase link --project-ref <ref>` links to the existing project.
- `supabase db pull baseline` captures the **current** cloud schema as the first
  migration, so the repo describes production reality.
- **Acceptance check:** after pulling the baseline, `supabase db diff` against the
  linked project must report **no differences** before the baseline is trusted /
  committed. If diff is non-empty, reconcile until empty.

### 2. Local development workflow (Docker)

One-time setup:
- Install the Supabase CLI.
- Ensure the Docker daemon is running.

Per schema change:
1. `supabase start` — boots local Postgres + Auth + the stack.
2. `supabase migration new <descriptive_name>` — creates an empty timestamped SQL
   file. Never hand-name migration files.
3. Write the SQL (DDL + RLS, see §5).
4. `supabase db reset` — drops and replays **all** migrations from scratch plus
   `seed.sql`, proving the migration applies cleanly on an empty database.
5. Commit the migration file.

This guarantees every migration is proven against real Postgres before it reaches
a PR.

### 3. CI/CD pipelines

**PR checks — extend `.github/workflows/pr-checks.yml`:**
Add a `db-validate` job (existing analyze/test/build jobs unchanged):
- Set up the Supabase CLI.
- `supabase start` / `supabase db reset` in CI to prove migrations apply from
  scratch.
- `supabase db lint` to catch schema issues (including RLS lint findings).

**Deploy — new `.github/workflows/deploy.yml`, on push to `main`:**

```
job migrate:
  - setup supabase CLI
  - supabase link --project-ref $SUPABASE_PROJECT_REF
  - supabase db push            # applies only migrations the remote lacks

job deploy-web:
  needs: migrate                # GATE: runs only if migrate succeeds
  - setup flutter
  - flutter pub get
  - flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  - deploy build/web to GitHub Pages (actions/deploy-pages)
```

The `needs: migrate` dependency is what enforces "schema applied before app
deployed." If `db push` fails, the web deploy does not run.

### 4. Secrets & configuration

GitHub repository secrets:
- `SUPABASE_ACCESS_TOKEN` — personal access token for CLI auth.
- `SUPABASE_DB_PASSWORD` — project database password, used by `supabase db push`.
- `SUPABASE_PROJECT_REF` — project ref (alternatively committed in `config.toml`).
- `SUPABASE_URL` — passed to `flutter build web` via dart-define.
- `SUPABASE_ANON_KEY` — passed to `flutter build web` via dart-define.

Repo configuration:
- GitHub Pages source set to **GitHub Actions** (Settings → Pages).
- Add `.env.json` to `.gitignore`.

### 5. Safety / RLS rule (baked into the process)

Because Flutter clients talk to Supabase directly, every table reachable through
the Data API must be protected by RLS, or it is effectively public.

Rule for every migration that creates a table:
- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`
- Add policies that match the real access model. Default ownership pattern:
  ```sql
  create policy "owner_select" on <table> for select
    to authenticated using ((select auth.uid()) = user_id);
  create policy "owner_modify" on <table> for update
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
  ```
- `UPDATE` policies require both `USING` and `WITH CHECK`.
- Use `TO authenticated` (not the deprecated `auth.role()`), combined with an
  ownership predicate — role alone is not authorization.

This is enforced softly by `supabase db lint` in the PR `db-validate` job and
listed as a required reviewer checklist item.

## Components & Responsibilities

| Unit | Purpose | Depends on |
|------|---------|-----------|
| `supabase/migrations/*.sql` | Source of truth for schema | none (plain SQL) |
| `supabase/config.toml` | Local stack + project link config | project ref |
| `pr-checks.yml :: db-validate` | Prove migrations apply + lint on PRs | CLI, migrations |
| `deploy.yml :: migrate` | Apply pending migrations to prod | secrets, migrations |
| `deploy.yml :: deploy-web` | Build + publish web app, gated on migrate | migrate job, secrets |

## Error Handling

- **Baseline diff non-empty:** stop; reconcile the baseline migration with the live
  schema until `supabase db diff` is empty.
- **`db reset` fails in CI/local:** migration is invalid → fix before merge; PR
  cannot pass `db-validate`.
- **`db push` fails on deploy:** `deploy-web` is skipped (gate); production app
  keeps the previous build; investigate via job logs.
- **Migration applied but app build fails:** the schema change is live but the new
  app is not deployed. Accepted trade-off for a single-environment setup; mitigated
  by writing additive/backward-compatible migrations.

## Testing

- Local: `supabase db reset` replays all migrations + seed from scratch on every
  change.
- CI (PR): `db-validate` repeats the from-scratch apply + `supabase db lint`.
- Verification of CI itself: confirmed by a first PR that adds a trivial migration
  and observing `db-validate` pass and (on merge) `migrate` + `deploy-web` succeed.

## Implementation Order (high level)

1. Local tooling: install Supabase CLI; start Docker.
2. `supabase init` + `link`; capture baseline via `db pull`; verify empty diff.
3. Add `.env.json` to `.gitignore`.
4. Extend `pr-checks.yml` with `db-validate`.
5. Add `deploy.yml` (migrate → deploy-web), wire dart-define + Pages.
6. Create GitHub secrets; enable Pages (Actions source).
7. Validate end-to-end with a trivial test migration PR.
