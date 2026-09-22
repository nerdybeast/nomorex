# Build Process

## Compile-Time Environment Variables

This app uses Dart's `String.fromEnvironment()` in `lib/main.dart` to read configuration values at build time:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
);

await SentryFlutter.init((options) {
  options.dsn = const String.fromEnvironment('SENTRY_DSN');
}, appRunner: () => runApp(...));
```

These are **compile-time constants**, not runtime environment variables. The values are baked into the binary during `flutter build` — they do not exist as named variables in the finished app. If they are not supplied at build time, they default to empty strings (no error, but the app will fail to connect to Supabase; an empty `SENTRY_DSN` just disables the Sentry SDK rather than erroring).

`SENTRY_DSN` deliberately points at a **different Sentry project per environment**: `.env.json` (prod) carries the `Nomorex` project's DSN, `.env.local.json` carries the `Nomorex-test` project's DSN, so local debugging noise never lands in the production Sentry project. A DSN is not a secret — see "A Note on the Publishable Key" below for why the same reasoning applies here.

## Local Development

A `.env.json` file at the project root supplies these values locally. It is gitignored (covered by the `.env*` pattern) and must be created manually on each machine.

`.env.json`:

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_<your-publishable-key>",
  "SENTRY_DSN": "<Nomorex project DSN>"
}
```

Pass the file to any `flutter` command using the `--dart-define-from-file` flag:

```bash
# Run the app
flutter run --dart-define-from-file=.env.json

# Build a debug APK
flutter build apk --debug --dart-define-from-file=.env.json

# Build a release APK
flutter build apk --release --dart-define-from-file=.env.json
```

### Targeting the local Supabase stack

`.env.json` points at **production**. To develop against the local stack from
`supabase start`, use `.env.local.json` instead (also gitignored):

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_<local-key>",
  "SENTRY_DSN": "<Nomorex-test project DSN>"
}
```

```bash
flutter run --dart-define-from-file=.env.local.json
```

The local keys are fixed demo credentials — identical on every machine and not
secret. Run `supabase status` to print the current values. Note that Android
emulators reach the host at `10.0.2.2`, not `127.0.0.1`.

**In Claude Code on the web**, `.env.local.json` doesn't point at a real local
stack: the `SessionStart` hook (`.claude/hooks/session-start.sh`) writes it
pointing at a small dedicated cloud dev Supabase project (`nomorex-cloud-dev`,
ref `gjrxtxxxqqnjetzgjtwb`, in the "Playground" org) instead, because
`supabase start` needs Docker, and its image pulls land on CDN hosts (e.g.
Docker Hub's CloudFront-backed blob host) that fall outside this repo's cloud
environment's network access level. That same level also has to include
`*.supabase.co` for the hosted project to be reachable at all — see
[Network access](https://code.claude.com/docs/en/cloud-environments#access-levels)
to set the environment to **Custom** with `*.supabase.co` added, or **Full**.

A few things worth knowing before touching this again:

- **Changing an environment's network access does not affect sessions already
  running.** The policy is fixed when the container starts; a session open
  before the change keeps failing with the same proxy 403s after you save the
  new setting. Verify from a *new* session, not the one you were in when you
  changed it.
- **The Supabase MCP tools (`mcp__Supabase__*`) reach a project's Management
  API regardless of the session's own network access level** — they don't go
  through the session's sandboxed proxy the way `curl`/`psql`/the `supabase`
  CLI do. That's how this project's schema and seed data got applied from
  inside a Trusted-only session before network access was widened at all, and
  it's still the right tool for schema/data changes here, rather than trying
  to get `supabase db push`/`psql` working against it.
- **This project's schema is not kept in sync automatically.** Unlike
  production, which the Supabase GitHub integration migrates on every push to
  `main`, nothing re-applies `supabase/migrations/` to `nomorex-cloud-dev`.
  Adding a migration to the repo without also running it here (via
  `mcp__Supabase__apply_migration`, in order, or by pasting the new file into
  the project's SQL editor) leaves cloud sessions on a stale schema — a bug
  that won't reproduce locally since `supabase db reset` always replays
  everything.
- **Seed data is partial.** The project has the predefined exercises,
  `a@a.com` / `b@b.com` (password `123456`) test users, and the small
  Community-tab demo content from the end of `supabase/seed.sql`. The four
  large historical ZT programs (`supabase/seed.sql` lines ~137–2851) were
  deliberately left out — that much UUID-cross-referenced SQL has no safe way
  to reach this project's database from inside a sandboxed session other than
  retyping it by hand, which risks a silently broken foreign key. If you want
  that data too, paste those lines into the project's SQL editor in the
  Supabase dashboard directly.

Once network access allows it, the project behaves like the local stack for
everything except a real `supabase start`/`db reset` cycle.

Alternatively, you can pass values inline without the file:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<your-publishable-key>
```

## CI / CD

For GitHub Actions (or any CI system), pass the values as secrets. Store `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as repository secrets in GitHub, then reference them in the workflow:

```yaml
- name: Build APK (debug)
  run: flutter build apk --debug
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}
```

> Note: Dart's `--dart-define` reads from the build command, not from OS environment variables. For CI, pass them explicitly via `--dart-define` flags or `--dart-define-from-file` pointed at a generated file.

`.github/workflows/deploy.yml` is the only workflow that builds a real deployed
environment (the GitHub Pages web app), so it's also the only one that passes
`SENTRY_DSN` — as a `SENTRY_DSN` repository secret holding the **Nomorex**
(production) project's DSN. `pr-checks.yml` never deploys anywhere real, so it
intentionally leaves `SENTRY_DSN` unset; an empty DSN just disables the Sentry
SDK for that build, same as an unset Supabase secret leaves it unable to
connect.

## iOS signing and `flutter build ipa`

`flutter build ipa` defaults to `--export-method app-store`, which requires an
"iOS Distribution" certificate and an App Store provisioning profile — both of
which require an active **paid** Apple Developer Program membership ($99/yr).
On a free/personal Apple team, that export always fails with errors like:

```
error: exportArchive No signing certificate "iOS Distribution" found
error: exportArchive Team "<name>" does not have permission to create "iOS App Store" provisioning profiles.
```

This is expected on a free team, not a misconfiguration. Apple restricts free
teams to **development** signing (install on devices registered with that
Apple ID via Xcode). To produce an installable IPA without a paid membership:

```bash
flutter build ipa --export-method development
```

Moving to `--export-method ad-hoc` or the `app-store` default later requires
enrolling in the paid Apple Developer Program — at that point,
`DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj/project.pbxproj` may also need to
point at the paid team's ID if it differs from the free team currently used.

## A Note on the Publishable Key

The Supabase publishable key (`sb_publishable_...`) is designed to be public — it is safe to ship inside an app binary. Security is enforced server-side via Row Level Security (RLS) policies on the database. Keeping it out of source control is good practice, but it is not a secret in the same way a secret API key (`sb_secret_...`) would be.

It replaces the older JWT-based anon key: `supabase_flutter` now takes it via the `publishableKey:` parameter, and `anonKey:` is deprecated. Publishable keys can also be rotated independently of the project's JWT secret.

A Sentry DSN (`SENTRY_DSN`) is public for the same reason: it only lets a client submit new events, it grants no read access to the project's data, and it can be rotated from the project's settings if it's ever abused.

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

   ```sql
   -- Example ownership policies for a table with a user_id column:
   alter table widgets enable row level security;

   create policy "owner_select" on widgets for select
     to authenticated using ((select auth.uid()) = user_id);

   create policy "owner_update" on widgets for update
     to authenticated
     using ((select auth.uid()) = user_id)
     with check ((select auth.uid()) = user_id);
   ```

4. `supabase db reset` — replays all migrations from scratch to verify.
5. Commit and open a PR. CI runs `db reset` + `db lint`.

### Deployment

Migrations are applied to production by the **Supabase GitHub integration**,
which watches `supabase/` and deploys on push to `main`. The `Deploy` workflow
in `.github/workflows/deploy.yml` only builds and publishes the web app; it no
longer runs `supabase db push`.

The two run independently, so a schema change and the app build that depends on
it are not ordered. Ship additive migrations ahead of the code that needs them.

## E2E tests

The `integration_test/` suite boots the real app against the local Supabase
stack, so it needs the same compile-time dart-defines as a normal run. Use the
runner rather than invoking `flutter test` directly:

```bash
./scripts/e2e.sh          # macOS desktop
./scripts/e2e.sh linux    # Linux desktop, how CI runs it
```

It starts the stack, runs `supabase db reset` (local only), and passes the
config through. Locally it reads `.env.local.json`; in CI, where that file
doesn't exist, it reads `API_URL` and `PUBLISHABLE_KEY` off the running stack
via `supabase status -o env`.

If the suite is ever pointed at an Android emulator, the URL must be
`http://10.0.2.2:54321` rather than `127.0.0.1`, for the same reason described
above.
