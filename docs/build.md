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

### Claude Code on the web

Cloud sessions run the same local stack CI does, so a change can be proven end
to end from a phone. Provisioning is split in two:

- **`scripts/cloud-setup.sh`** is the heavy, slow-changing half: Flutter and the
  Supabase CLI at the versions pinned in `.github/workflows/pr-checks.yml` (read
  from there, so bump them in one place), the Linux desktop build deps and
  xvfb the E2E job uses, the Supabase Docker images, and Playwright's Chromium
  (for `scripts/web-shot.mjs`; rendering only, since Flutter's canvas makes taps
  unreliable). Installs run in parallel to fit the ~5 minute cache budget, it
  always exits 0, and it writes per-stage results to
  `/var/lib/nomorex-cloud-setup.status`.
- **`.claude/hooks/session-start.sh`** is the light, per-session half: `flutter
  pub get`, start Docker and `supabase start` (processes don't survive the
  environment snapshot), and write `.env.local.json` for that stack (never
  overwritten if present; `SENTRY_DSN` stays unset, which disables Sentry). If
  the toolchain isn't on disk it runs `cloud-setup.sh` itself, so it works
  with no setup script configured, only slower.

**One-time setup:** in claude.ai/code, open the environment, select **Setup
script**, paste the stub below once, and save. It is stored on the environment,
applies to every session (phone included), runs on the first session and is
then snapshotted. It reruns when you edit it or the allowed hosts, and when the
cache expires after about a week. Because the cache is a snapshot, a change to
`cloud-setup.sh` on `main` is not picked up until one of those happens (the
hook's fallback only fires when the toolchain is *missing*).

```bash
#!/bin/bash
script="$(find / -maxdepth 6 -path '*/scripts/cloud-setup.sh' \
  -not -path '/proc/*' -not -path '/sys/*' 2>/dev/null | head -n 1)"
if [ -n "$script" ]; then
  bash "$script" || true
else
  echo "cloud-setup.sh not found; the SessionStart hook will provision instead"
fi
```

`$CLAUDE_PROJECT_DIR` is not set when a setup script runs and the working
directory is not the repo (it was `/home/user`), so the stub locates the script
rather than assuming a path. It always exits 0, because a non-zero exit stops
the session from starting; a green "Ran setup script" check therefore does not
mean it worked, so read its output.

Run `./scripts/verify.sh` to prove a change: analyze, widget tests, `db reset`
+ `db lint`, E2E under xvfb, and a web build. `--no-e2e`, `--no-db` and
`--no-web` skip stages. Anything it could not run is printed as `SKIP`, never
as a pass.

**Network access.** The default **Trusted** level already allowlists what the
stack needs: `registry-1.docker.io`, `production.cloudflare.docker.com`,
`production.cloudfront.docker.com`, `ghcr.io` and `public.ecr.aws` (where the
Supabase images live), plus `pub.dev`, `storage.googleapis.com` (Flutter
artifacts), `github.com` (CLI download) and the Ubuntu mirrors. The one gap is
Playwright's Chromium download, which comes from hosts outside that list, so
screenshots need **Custom** (with "include default list" checked) plus the
Playwright CDN hosts. If `supabase start` is blocked the hook prints a warning
and carries on without the stack. A network access change reaches running
sessions within about a minute; no new session is needed. See
[Network access](https://code.claude.com/docs/en/cloud-environments#access-levels).

Cloud sessions must never `supabase link`, `db push`, or reset with `--linked`
or `--db-url`; `.claude/settings.json` denies those.

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
