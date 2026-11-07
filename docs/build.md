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
  (for `scripts/web-shot.mjs`, which signs in, turns on Flutter's accessibility
  tree and can run a flow from `scripts/web-flows/` that clicks widgets by role
  and name). Installs run in parallel to fit the ~5 minute cache budget, it
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
+ `db lint` + `test db` (pgTAP), E2E under xvfb, and a web build. `--no-e2e`, `--no-db` and
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
and carries on without the stack. The warning only blames the network when the
Supabase images are actually missing. On a resumed session, Docker restarts the
old containers by itself and Postgres takes a few seconds to come up; the hook
waits for that (up to about two minutes) instead of running `supabase start`
over a database that's still booting, which used to fail with "container is not
ready: starting". A network access change reaches running
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

### Sentry environments, releases and symbols

Local development and deployed apps are kept apart in two ways:

- **Different projects.** Local runs use the `nomorex-test` DSN from
  `.env.local.json`. The deploy workflows use the `nomorex` (production) DSN.
- **Different environments.** `lib/main.dart` reads `SENTRY_ENVIRONMENT`,
  which defaults to `development`. Only `deploy.yml` and `deploy-ios.yml` pass
  `production`. A local build that happens to use `.env.json` still reports as
  `development`.

The deploy workflows also pass `SENTRY_RELEASE` (`nomorex@<version>+<build>`)
and `SENTRY_DIST` (`<build>`), from the same `version.yml` outputs as the app
version. Web and iOS builds from one commit therefore share a release, and
Sentry's platform tag tells them apart.

To make stack traces readable, the deploy workflows run `sentry_dart_plugin`
(configured under `sentry:` in `pubspec.yaml`):

- `deploy.yml` builds with `--source-maps`, then uploads the web source maps
  *before* publishing. The plugin injects debug IDs into the JS, so it has to
  run first. The `.map` files are deleted afterwards so Pages doesn't serve
  them.
- `deploy-ios.yml` archives into `build/ios/archive` and uploads the dSYMs
  (debug symbols) from there after the TestFlight upload. Apple still gets its
  own copy through `uploadSymbols` in `ios/ExportOptions.plist`.

**One-time setup:**
1. In Sentry (organization `michael-penrod`), go to **Settings → Auth Tokens**
   and create an organization token. It has the `org:ci` scope.
2. Add it as the `SENTRY_AUTH_TOKEN` repository secret.

Until that secret exists, both upload steps log a warning and skip, and
deploys still succeed. To check after a deploy, look at the step logs, then at
an event's release and stack trace in Sentry.

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
anywhere. `xcodebuild archive` builds an **unsigned** archive
(`CODE_SIGNING_ALLOWED=NO`), and `xcodebuild -exportArchive` runs with
`-allowProvisioningUpdates` and an App Store Connect API key, so Xcode signs
with the team's cloud-managed distribution certificate and creates/refreshes
the App Store profile itself. Keep the archive unsigned: signing it uses the
Release config's development identity, whose private key must live in the
local keychain, so every fresh runner would create a new Apple Development
certificate until the account hits Apple's certificate limit. `ios/ExportOptions.plist` sets `destination=upload`, so
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
  - "Your account has reached the maximum number of certificates": something
    signed with a development identity on a runner again (see "Signing is
    cloud-managed" above). Revoke the extra **Apple Development**
    certificates at
    <https://developer.apple.com/account/resources/certificates/list>
    (revoking development certs doesn't affect App Store builds)
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

### Project settings to keep

- **Minimum iOS is pinned at 17.0** (`IPHONEOS_DEPLOYMENT_TARGET` in
  `ios/Runner.xcodeproj/project.pbxproj`, on the project and both targets).
  Don't set it back to `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`. That value
  moves with the Xcode version, and CI always uses the latest stable Xcode, so
  a runner update could silently drop users on older iOS versions. Lowering
  the minimum later is safe; raising it strands users on their last installed
  version. Flutter's own floor is iOS 15.0.
- **iPhone is portrait-only; iPad supports all four orientations**
  (`Info.plist`). iPad multitasking requires all four. iPad support
  (`TARGETED_DEVICE_FAMILY = "1,2"`) can't be removed once the app is on the
  App Store.
- **`ios/Runner/PrivacyInfo.xcprivacy`** declares the data the app collects,
  and must agree with the App Store Connect privacy labels. Update both when
  the app starts collecting a new kind of data.
- **The launch screen background** is the `LaunchBackground` color in
  `Assets.xcassets`, which has light and dark variants matching the app's
  scaffold background (`bg0`). Keep the two in sync if the theme changes.

### Local builds

`pr-checks.yml`'s `build-ios` job runs `flutter build ios --release
--no-codesign` on every PR. Locally, the same command needs no Apple account.
To install on your own device, use `flutter run` with a development
certificate, or `flutter build ipa --export-method development`.

## App icon and splash screen

The icon is Option D ("Tally") from the NoMoreX App Icon design canvas: four
tally marks struck through by the `#c8470f` accent on `#121212`. The sources are
SVGs in `assets/icon/`; everything under `ios/`, `android/`, `macos/`,
`windows/` and `web/icons/` is generated from them, so never edit those PNGs by
hand.

| Source | Becomes |
| --- | --- |
| `icon.svg` | iOS, web, Windows, legacy (pre-8.0) Android icons |
| `foreground.svg` | Android adaptive icon foreground (background is `#121212`) |
| `monochrome.svg` | Android 13+ themed icon (single colour; the gap around the slash is real transparency) |
| `icon-dark.svg` / `icon-tinted.svg` | iOS 18 dark and tinted icons |
| `icon-macos.svg` | macOS Dock icon (rounded square with the standard margin) |
| `splash-light.svg` / `splash-dark.svg` | Launch screen mark on iOS, Android (pre-12) and web; 480px = 4x density, ~120pt on screen |
| `splash-android12-*.svg` | Android 12+ splash icon: 1152px canvas, artwork inside the 768px circle the system shows |

To change the icon or splash:

```bash
# 1. Edit the SVG(s), then render them to PNG at their own size (needs Node/npx)
./scripts/render-icons.sh
# 2. Regenerate every platform from the PNGs (config: `flutter_launcher_icons` in pubspec.yaml)
dart run flutter_launcher_icons
# 3. Regenerate the launch/splash screens (config: `flutter_native_splash` in pubspec.yaml)
dart run flutter_native_splash:create
```

After step 2, check `git diff ios/Runner.xcodeproj/project.pbxproj`.
flutter_launcher_icons 0.14.4 rewrites
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` to
`= AppIcon`; revert that hunk. It also leaves behind any iOS sizes it no longer
generates (e.g. the old `@1x` files), so delete PNGs in `AppIcon.appiconset`
that `Contents.json` no longer references.

The splash is the Tally mark on the app's own `bg-0` (`#FAFAFA` light,
`#121212` dark), so the hand-off to Flutter's first frame doesn't flash.
After step 3, check `git diff ios/Runner/Info.plist`: flutter_native_splash
2.4.8 re-indents the whole file to add `UIStatusBarHidden = false` (already the
default), so revert it. Its other rewrites (`LaunchScreen.storyboard`, the
splash `<style>`/`<picture>` in `web/index.html`) are its own and are
expected to change on each run.

`web/favicon.svg` is hand-maintained, not generated. It's a tight crop of
`icon.svg` so the tally still reads in a 16px browser tab, and `index.html`
lists it ahead of the generated `favicon.png` fallback. Update it by hand if
the artwork changes.

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
5. Commit and open a PR. CI runs `db reset` + `db lint` + `test db`.

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
