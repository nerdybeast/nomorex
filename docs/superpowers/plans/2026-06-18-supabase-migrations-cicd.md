# Supabase Migrations + Web Deploy CI/CD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Manage the Postgres schema as versioned migration files in the repo, validate them on every PR, and apply pending migrations to the production Supabase project before deploying the Flutter web app — all via GitHub Actions.

**Architecture:** Adopt the Supabase CLI migration workflow (`supabase/` directory, timestamped SQL migrations) with a full local Docker stack for testing. A PR workflow proves migrations apply from scratch; a deploy workflow on `main` runs `supabase db push` then, gated on its success, builds and publishes Flutter web to GitHub Pages.

**Tech Stack:** Supabase CLI, Docker, Postgres, GitHub Actions, Flutter (web), GitHub Pages.

## Global Constraints

- Single production Supabase project — no staging, no preview branches.
- Migration files are **always** created with `supabase migration new <name>` — never hand-named.
- Every migration that creates a table in an exposed schema (`public`) MUST enable RLS and add ownership policies; `UPDATE` policies require both `USING` and `WITH CHECK`; use `TO authenticated` with an `auth.uid()` predicate, never the deprecated `auth.role()`.
- The web deploy job MUST be gated on the migrate job via `needs:` so schema changes apply before the app deploys.
- Supabase client config (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) reaches the web build via `--dart-define`, mirroring the local `--dart-define-from-file=.env.json` pattern.
- Secrets are never committed; `.env.json` must be gitignored.

## Prerequisites (have these ready before starting)

- The Supabase **project ref** (the `<ref>` in `https://<ref>.supabase.co`).
- The project **database password** (Supabase Dashboard → Project Settings → Database).
- A **personal access token** (Supabase Dashboard → Account → Access Tokens) for CI.
- Ability to log into the Supabase CLI interactively (`supabase login` opens a browser).
- Docker Desktop / daemon that the current user can start.

## File Structure

| File | Responsibility | Action |
|------|----------------|--------|
| `supabase/config.toml` | Local stack + project link config | Create (via `supabase init`) |
| `supabase/migrations/<ts>_baseline.sql` | Snapshot of current prod schema | Create (via `db pull`) |
| `supabase/.gitignore`, `supabase/seed.sql` | CLI scaffolding | Create (via `supabase init`) |
| `.gitignore` | Ignore `.env.json` | Modify |
| `.github/workflows/pr-checks.yml` | Add `db-validate` job | Modify |
| `.github/workflows/deploy.yml` | migrate → deploy-web pipeline | Create |
| `docs/build.md` | Document the migration workflow | Modify |

---

### Task 1: Install local tooling (Supabase CLI + Docker)

No code; this prepares the environment for every later task. Nothing to commit.

**Files:** none.

- [ ] **Step 1: Check current state**

Run:
```bash
supabase --version 2>/dev/null || echo "CLI missing"; docker info >/dev/null 2>&1 && echo "docker up" || echo "docker down"
```
Expected: likely `CLI missing` and `docker down`.

- [ ] **Step 2: Install the Supabase CLI**

The CLI is not distributed via global `npm install -g`. Use one of these (pick what fits the machine):
```bash
# Homebrew (mac/linuxbrew)
brew install supabase/tap/supabase
# OR: download the latest .deb from https://github.com/supabase/cli/releases and:
#   sudo dpkg -i supabase_<version>_linux_amd64.deb
```

- [ ] **Step 3: Start the Docker daemon**

Start Docker Desktop, or on Linux:
```bash
sudo systemctl start docker
```

- [ ] **Step 4: Verify both**

Run:
```bash
supabase --version && docker info >/dev/null 2>&1 && echo "ready"
```
Expected: a version string followed by `ready`.

---

### Task 2: Initialize Supabase, capture baseline schema, gitignore env

**Files:**
- Create: `supabase/config.toml`, `supabase/seed.sql`, `supabase/.gitignore`, `supabase/migrations/<timestamp>_baseline.sql`
- Modify: `.gitignore`

**Interfaces:**
- Produces: a `supabase/migrations/` directory whose replay reproduces the current production schema. Later CI tasks depend on `supabase db reset` succeeding against these files.

- [ ] **Step 1: Initialize the Supabase project scaffolding**

Run from repo root:
```bash
supabase init
```
Expected: creates `supabase/config.toml` and `supabase/.gitignore`. If it asks about generating VS Code settings, answer `n`.

- [ ] **Step 2: Log in and link to the production project**

Run (interactive — opens a browser for `login`):
```bash
supabase login
supabase link --project-ref <REF>
```
Replace `<REF>` with the real project ref. `link` will prompt for the database password.
Expected: `Finished supabase link.`

- [ ] **Step 3: Capture the current cloud schema as the baseline migration**

Run:
```bash
supabase db pull baseline
```
Expected: creates `supabase/migrations/<timestamp>_baseline.sql` containing the live schema.

- [ ] **Step 4: Verify the baseline matches production exactly (acceptance gate)**

Run:
```bash
supabase db diff --linked
```
Expected: **no schema differences reported** (empty diff). If the diff is non-empty, the baseline is incomplete — re-run `supabase db pull` / reconcile until the diff is empty. Do not proceed until this is clean.

- [ ] **Step 5: Verify the baseline replays cleanly on a fresh local DB**

Run:
```bash
supabase start
supabase db reset
```
Expected: `supabase start` boots the local stack; `db reset` applies the baseline migration with no errors and prints `Finished supabase db reset.`

- [ ] **Step 6: Ignore `.env.json`**

Add this line to `.gitignore` (under a suitable section, e.g. near other env entries):
```
.env.json
```

- [ ] **Step 7: Confirm `.env.json` is now ignored and not staged**

Run:
```bash
git check-ignore .env.json && git status --porcelain .env.json
```
Expected: prints `.env.json` (it is ignored) and the status line is empty (not staged).

- [ ] **Step 8: Commit**

```bash
git add supabase .gitignore
git commit -m "feat: initialize supabase migrations with baseline schema"
```

---

### Task 3: Add a `db-validate` job to the PR workflow

**Files:**
- Modify: `.github/workflows/pr-checks.yml`

**Interfaces:**
- Consumes: the `supabase/migrations/` directory from Task 2.
- Produces: a PR check that fails if any migration does not apply from scratch or fails lint.

- [ ] **Step 1: Add the `db-validate` job**

Append this job under `jobs:` in `.github/workflows/pr-checks.yml` (sibling to the existing `checks` job; the existing job is unchanged):

```yaml
  db-validate:
    name: Validate DB migrations
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Start local Supabase stack
        run: supabase start

      - name: Apply migrations from scratch
        run: supabase db reset

      - name: Lint database
        run: supabase db lint
```

- [ ] **Step 2: Validate the workflow YAML locally**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/pr-checks.yml')); print('yaml ok')"
```
Expected: `yaml ok`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/pr-checks.yml
git commit -m "ci: validate supabase migrations on PRs"
```

- [ ] **Step 4: Verify on a real PR (deferred to Task 6)**

This job's live run is exercised by the end-to-end test in Task 6. No action now.

---

### Task 4: Add the deploy workflow (migrate → deploy-web)

**Files:**
- Create: `.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: GitHub secrets `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` (created in Task 5).
- Produces: production schema application + a GitHub Pages deployment of `build/web`.

- [ ] **Step 1: Create `.github/workflows/deploy.yml`**

```yaml
name: Deploy

on:
  push:
    branches: [main]

# Allow this workflow to publish to GitHub Pages
permissions:
  contents: read
  pages: write
  id-token: write

# Avoid overlapping deploys
concurrency:
  group: deploy-main
  cancel-in-progress: false

jobs:
  migrate:
    name: Apply DB migrations
    runs-on: ubuntu-latest
    env:
      SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
      SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
    steps:
      - uses: actions/checkout@v4

      - uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Link project
        run: supabase link --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}

      - name: Push migrations to production
        run: supabase db push

  deploy-web:
    name: Build & deploy web
    needs: migrate
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Build web
        run: |
          flutter build web --release \
            --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
            --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}

      - name: Setup Pages
        uses: actions/configure-pages@v5

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: build/web

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 2: Validate the workflow YAML**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml')); print('yaml ok')"
```
Expected: `yaml ok`.

- [ ] **Step 3: Confirm the deploy gate exists**

Run:
```bash
grep -n "needs: migrate" .github/workflows/deploy.yml
```
Expected: one match — proves `deploy-web` is gated on `migrate`.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: deploy web to GitHub Pages after applying migrations"
```

---

### Task 5: Configure GitHub secrets and enable Pages (manual)

These are repository settings, performed by the user in the GitHub UI / `gh` CLI. Nothing to commit.

**Files:** none.

- [ ] **Step 1: Create repository secrets**

Via `gh` CLI (run locally; values are prompted, not echoed):
```bash
gh secret set SUPABASE_ACCESS_TOKEN
gh secret set SUPABASE_DB_PASSWORD
gh secret set SUPABASE_PROJECT_REF
gh secret set SUPABASE_URL
gh secret set SUPABASE_ANON_KEY
```
(Or GitHub UI → Settings → Secrets and variables → Actions → New repository secret.)

- [ ] **Step 2: Verify all five secrets exist**

Run:
```bash
gh secret list
```
Expected: all five names listed.

- [ ] **Step 3: Enable GitHub Pages with the Actions source**

GitHub UI → Settings → Pages → Build and deployment → Source = **GitHub Actions**.

---

### Task 6: End-to-end validation with a trivial migration

Proves the whole pipeline: PR validation, then production apply + web deploy on merge.

**Files:**
- Create: `supabase/migrations/<timestamp>_pipeline_smoke_test.sql` (temporary, may be reverted after)

- [ ] **Step 1: Create a branch and a harmless migration**

Run:
```bash
git checkout -b chore/pipeline-smoke-test
supabase migration new pipeline_smoke_test
```
Then put a no-op, idempotent statement in the new file (a comment-only file is treated as empty; use a real but harmless statement):
```sql
-- Pipeline smoke test: verifies migrations apply end-to-end.
create schema if not exists pipeline_smoke_test;
```

- [ ] **Step 2: Prove it applies locally**

Run:
```bash
supabase db reset
```
Expected: `Finished supabase db reset.` with no errors.

- [ ] **Step 3: Push the branch and open a PR**

```bash
git add supabase/migrations
git commit -m "chore: pipeline smoke test migration"
git push -u origin chore/pipeline-smoke-test
gh pr create --fill --base main
```

- [ ] **Step 4: Confirm the PR `db-validate` job passes**

Run:
```bash
gh pr checks --watch
```
Expected: `Validate DB migrations` (and existing checks) report success.

- [ ] **Step 5: Merge and confirm the deploy pipeline runs**

```bash
gh pr merge --squash --delete-branch
gh run watch
```
Expected: the `Deploy` workflow runs `migrate` then `deploy-web`; both succeed and a Pages URL is produced.

- [ ] **Step 6: Verify production picked up the change, then clean up**

Run:
```bash
supabase db diff --linked
```
Expected: empty diff (production now matches the repo). Optionally remove the smoke-test schema with a follow-up migration (`drop schema if exists pipeline_smoke_test;`) if you do not want it lingering in production.

---

### Task 7: Document the migration workflow

**Files:**
- Modify: `docs/build.md`

- [ ] **Step 1: Append a "Database migrations" section to `docs/build.md`**

Add:
```markdown
## Database migrations

Schema is managed as code under `supabase/migrations/`.

### One-time setup
- Install the Supabase CLI and start Docker.
- `supabase login` then `supabase link --project-ref <ref>`.

### Making a schema change
1. `supabase start` — boot the local stack.
2. `supabase migration new <name>` — never hand-name files.
3. Write SQL. Any new table in `public` MUST enable RLS and add ownership
   policies (`TO authenticated using ((select auth.uid()) = user_id)`;
   UPDATE needs both `USING` and `WITH CHECK`).
4. `supabase db reset` — replays all migrations from scratch to verify.
5. Commit and open a PR. CI runs `db reset` + `db lint`.

### Deployment
On merge to `main`, CI applies pending migrations to production
(`supabase db push`) and only then builds and deploys the web app to
GitHub Pages.
```

- [ ] **Step 2: Commit**

```bash
git add docs/build.md
git commit -m "docs: document supabase migration workflow"
```

---

## Self-Review Notes

- **Spec coverage:** §1 schema-as-code → Task 2; §2 local Docker workflow → Tasks 1–2, documented Task 7; §3 PR validation → Task 3, deploy pipeline → Task 4; §4 secrets/Pages → Task 5; §5 RLS rule → Global Constraints + Task 7 docs + `db lint` in Task 3; end-to-end testing (spec §Testing) → Task 6.
- **Placeholders:** `<REF>` and secret values are genuine user-supplied inputs, not unfilled plan placeholders; all commands and YAML are complete.
- **Type/name consistency:** secret names (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`) are identical across Tasks 4 and 5; job names (`migrate`, `deploy-web`, `db-validate`) consistent between definition and verification steps.
