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
  (for `scripts/web-shot.mjs`, which signs in and can run a click-driven flow
  from `scripts/web-flows/`; coordinate clicks work in headless Chromium). Installs run in parallel to fit the ~5 minute cache budget, it
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

`.github/workflows/deploy.yml` (the GitHub Pages web app) and
`.github/workflows/deploy-ios.yml` (TestFlight) are the only workflows that
build a real deployed app, so they're also the only ones that pass
`SENTRY_DSN` — as a `SENTRY_DSN` repository secret holding the **Nomorex**
(production) project's DSN. `pr-checks.yml` never deploys anywhere real, so it
intentionally leaves `SENTRY_DSN` unset; an empty DSN just disables the Sentry
SDK for that build, same as an unset Supabase secret leaves it unable to
connect.

## iOS: TestFlight deploys

`.github/workflows/deploy-ios.yml` builds a signed release IPA on every push to
`main` (same idea as the web deploy, with its own `paths-ignore`) and uploads it
to App Store Connect, where it shows up in TestFlight. Run it by hand from the
Actions tab (`workflow_dispatch`) to retry or force a build. It runs on a
GitHub-hosted `macos-26` runner, which is free because the repo is public.

**Versioning.** It uses the same `version.yml` outputs as the web deploy:
`CFBundleShortVersionString` is GitVersion's MajorMinorPatch and
`CFBundleVersion` is the commit count. Many builds share one version (e.g.
1.4.2 builds 312, 313, ...), which TestFlight accepts because the build number
always goes up.

**Signing is cloud-managed.** No certificate or provisioning profile is stored
anywhere. `xcodebuild archive`/`-exportArchive` run with
`-allowProvisioningUpdates` and an App Store Connect API key, so Xcode uses the
team's cloud-managed distribution certificate and creates/refreshes the App
Store profile itself. `ios/ExportOptions.plist` sets `destination=upload`, so
the export step also does the upload. `flutter build ipa` isn't used because it
can't pass the API-key flags through to xcodebuild. Instead
`flutter build ios --config-only` bakes the dart-defines and version into the
Xcode config first.

**Export compliance.** `Info.plist` declares `ITSAppUsesNonExemptEncryption =
false` (the app only uses HTTPS/TLS, which is exempt), so App Store Connect
doesn't ask the encryption question on every build.

### One-time Apple setup

Already done for this repo (Nov 2026): the app record exists (App Store Connect
Apple ID `6829556503`) and the three `APP_STORE_CONNECT_*` secrets are set.
These steps are the reference for redoing it, e.g. on a new Apple account or
after rotating the key.

1. **Paid Apple Developer Program membership** for team `K6AJD8M75Q` (the
   `DEVELOPMENT_TEAM` in `ios/Runner.xcodeproj/project.pbxproj`). Check it at
   <https://developer.apple.com/account>. It renews yearly. App Store /
   TestFlight distribution needs a paid team. On a free or lapsed team, the
   export fails with `No signing certificate "iOS Distribution" found` or
   `does not have permission to create "iOS App Store" provisioning profiles`.

2. **App ID.** At <https://developer.apple.com/account/resources/identifiers/list>,
   click **+**, choose **App IDs**, then **App**, and register the explicit
   bundle ID `com.nomorex.app`. No extra capabilities are needed. Automatic
   signing can create it on the first CI run, but registering it up front
   avoids a confusing signing failure.

3. **App record.** At <https://appstoreconnect.apple.com/apps>, click **+**
   and choose **New App**:
   - Platform: iOS
   - Name: must be unique across the whole App Store
   - Primary language: your choice
   - Bundle ID: `com.nomorex.app`
   - SKU: any string, e.g. `nomorex`

   The App Store Connect name is what the store shows. The name under the
   icon on a device comes from `CFBundleDisplayName` in `ios/Runner/Info.plist`
   (`NoMoreX`).

4. **App Store Connect API key** (CI uses it to sign and upload).
   - Open <https://appstoreconnect.apple.com/access/integrations/api>. To get
     there by clicking: **Users and Access**, then the **Integrations** tab,
     then **App Store Connect API** in the left sidebar.
   - Choose the **Team Keys** tab, **not** Individual Keys. Cloud-managed
     signing needs a team key.
   - The first time, the page shows a **Request Access** button instead of a
     keys list. Only the **Account Holder** can click it. Accept the terms and
     the Team Keys page appears immediately.
   - Click **Generate API Key** (or **+**). Name: anything, e.g.
     `GitHub Actions`. Access: **Admin**. Lower roles can't create the
     cloud-managed distribution certificate, and signing fails.
   - Collect three values from that page:
     - **Issuer ID**: the UUID shown above the keys table (it has a Copy link).
     - **Key ID**: in the new key's row.
     - **Private key**: the **Download** link in that row gives
       `AuthKey_<KEYID>.p8`. **It can only be downloaded once.** Keep it in a
       password manager or delete it after creating the secret. Never commit it.

5. **Repository secrets.** In GitHub, open nerdybeast/nomorex, then
   **Settings > Secrets and variables > Actions > New repository secret**:

   | Secret | Value |
   |---|---|
   | `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
   | `APP_STORE_CONNECT_KEY_ID` | Key ID |
   | `APP_STORE_CONNECT_API_KEY_P8` | base64 of the .p8 (see below) |

   ```bash
   base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy   # then paste as the secret value
   gh secret list | grep APP_STORE                        # confirm all three exist
   ```

   `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `SENTRY_DSN` are the same
   secrets the web deploy uses. The workflow's first step fails with a clear
   error if any required secret is missing, or if the .p8 secret doesn't decode
   to a private key.

6. **TestFlight testers.** After the first build finishes processing, open
   the app in App Store Connect and go to the **TestFlight** tab. Create an
   **Internal Testing** group, add yourself and any other testers (they must be
   users on the App Store Connect team), and turn on **automatic
   distribution** so every new build reaches them without manual steps.
   Testers install through Apple's TestFlight app. External testers (anyone
   outside the team) additionally need Beta App Review, test information and a
   feedback email.

### After a merge

The **Deploy iOS (TestFlight)** run's export step uploads the build. It then
appears under the app's TestFlight tab as *Processing* (usually 10–30 minutes)
and then *Ready to Test*. There's no export-compliance prompt, because of the
`ITSAppUsesNonExemptEncryption` key. Apple also emails the Account Holder when
processing finishes or fails.

### Troubleshooting and maintenance

- **Signing or upload failures.** Download the run's `xcodebuild-logs`
  artifact. The usual causes:
  - a lapsed membership (step 1)
  - an API key that isn't Admin, or is an Individual key (step 4)
  - a missing App ID or app record (steps 2–3)
- **"bundle version must be higher".** The build number is the commit count
  from `version.yml`. It only repeats if a run is re-triggered for a commit
  that already uploaded. Push a new commit instead.
- **Rotating or revoking the key.** Revoke it on the same Team Keys page,
  generate a new one (step 4) and replace the three secrets (step 5). Nothing
  in the repo changes.
- **Xcode/SDK requirements.** The workflow selects the runner's latest stable
  Xcode (`maxim-lobanov/setup-xcode`). If Apple starts rejecting uploads for an
  old SDK, bump `runs-on: macos-26` in both `deploy-ios.yml` and
  `pr-checks.yml`'s `build-ios` job.

### Local builds

`pr-checks.yml`'s `build-ios` job runs `flutter build ios --release
--no-codesign` on every PR. Locally, the same command needs no Apple account.
To install on your own device, use `flutter run` with a development
certificate, or `flutter build ipa --export-method development`.

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
