# Build Process

## Compile-Time Environment Variables

This app uses Dart's `String.fromEnvironment()` in `lib/main.dart` to read configuration values at build time:

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
);

await SentryFlutter.init((options) {
  options.dsn = telemetryEnabledInThisBuild ? const String.fromEnvironment('SENTRY_DSN') : '';
  options.environment = telemetryEnvironmentInThisBuild.name;
}, appRunner: () => runApp(...));
```

`APP_ENV` (`local`, `beta` or `production`; unset means `local`) says which environment a build belongs to. Everything environment-specific derives from it (`lib/core/environment/app_environment.dart`): Sentry's environment tag and whether any telemetry is sent. An unknown value throws at startup rather than quietly behaving like `local`. See "Environments" below.

These are **compile-time constants**, not runtime environment variables. The values are baked into the binary during `flutter build` — they do not exist as named variables in the finished app. If they are not supplied at build time, they default to empty strings (no error, but the app will fail to connect to Supabase; an empty `SENTRY_DSN` just disables the Sentry SDK rather than erroring).

`SENTRY_DSN` is the one DSN of the single `nomorex` Sentry project, which separates environments by tag (`local`, `beta`, `production`) instead of by project. Only the `beta` define file carries it: local builds send nothing, so they need no DSN. A DSN is not a secret — see "A Note on the Publishable Key" below for why the same reasoning applies here.

## Environments

| Environment | Used for | Define file | Telemetry |
|---|---|---|---|
| `local` | developer machines, cloud agent sessions, CI builds | `.env.local.json` (local `supabase start` stack), `.env.device.json` | none |
| `beta` | everything deployed today: TestFlight, GitHub Pages | `.env.beta.json` | release builds send Sentry events and analytics |
| `production` | reserved for the official App Store, Google Play and website launch | none yet | release builds send them |

- **Debug and profile builds never send telemetry**, whatever `APP_ENV` is: running `flutter run` against the beta backend must not put half-finished code into beta's error and usage data. To check Sentry or analytics wiring from such a build, add `--dart-define=TELEMETRY_DEBUG=true`; those events are tagged `local`, not `beta`.
- **Release builds of `local` send nothing either.** Only `beta` and `production` builds collect.
- The deploy workflows build with `APP_ENV=beta` and read `SUPABASE_URL` (a variable) and the Supabase and Sentry secrets from the `beta` GitHub Environment. A new external dependency is set up per environment from the start (see CLAUDE.md, "Environments").

## Local Development

A define file at the project root supplies these values locally. They are gitignored (covered by the `.env*` pattern) and must be created manually on each machine. `.env.beta.json` points at the hosted **beta** project; the next section covers the local stack.

`.env.beta.json`:

```json
{
  "APP_ENV": "beta",
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_<your-publishable-key>",
  "SENTRY_DSN": "<nomorex project DSN>"
}
```

Pass the file to any `flutter` command using the `--dart-define-from-file` flag:

```bash
# Run the app (Android also needs --flavor, see "Android flavors" below)
flutter run --dart-define-from-file=.env.beta.json

# Build a debug APK
flutter build apk --debug --flavor beta --dart-define-from-file=.env.beta.json

# Build a release APK
flutter build apk --release --flavor beta --dart-define-from-file=.env.beta.json
```

### Platform flavors (Android, iOS, macOS)

Android, iOS and macOS each have one flavor per environment, so the three install side by side and each carries its own Firebase config. All three use the same application id, display name and flavor names:

| Flavor | Application id | Launcher name | Firebase config |
|---|---|---|---|
| `local` | `com.nomorex.app.local` | NoMoreX (Local) | none |
| `beta` | `com.nomorex.app.beta` | NoMoreX (Beta) | Android: `android/app/src/beta/google-services.json`; iOS and macOS: `config/beta/GoogleService-Info.plist` under `ios/` and `macos/` |
| `production` | `com.nomorex.app` | NoMoreX | none yet (its Firebase project doesn't exist) |

Always pass `--flavor` and the define file of the same environment, e.g. `flutter run --flavor local --dart-define-from-file=.env.local.json`. There is no default flavor, so a mobile or macOS build without `--flavor` fails, and `lib/main.dart` throws at startup if the flavor and `APP_ENV` disagree (`assertFlavorMatchesEnvironment`). The flavor is deliberately not named `test` (Gradle reserves it). Web, Windows and Linux have no flavor, so `APP_ENV` alone decides there.

**Apple projects.** Each of `ios/Runner.xcodeproj` and `macos/Runner.xcodeproj` has a scheme per flavor (`local`, `beta`, `production`) and a build configuration per mode and flavor (`Debug-local`, `Release-beta`, `Profile-production`, ...); the old `Runner` scheme and unflavored configurations are gone. Each configuration's xcconfig includes an `Environment-<flavor>.xcconfig` (in `ios/Flutter/` and `macos/Runner/Configs/`) that sets `PRODUCT_BUNDLE_IDENTIFIER`, `APP_DISPLAY_NAME` (which `CFBundleDisplayName` reads) and `APP_ENV_NAME`. `PRODUCT_NAME` stays `Runner` on iOS (the ad-ID check and CI look for `Runner.app`) and `nomorex` on macOS. A **Copy Firebase config** build phase copies `config/<APP_ENV_NAME>/GoogleService-Info.plist` into the app when that folder exists, so only beta carries one; nothing Firebase-related is a bundled resource any more. To add a setting per environment, add it to the three `Environment-*.xcconfig` files. `test/core/environment_identity_test.dart` checks that Android, iOS and macOS agree on ids and names.

The Google services Gradle plugin ignores a flavor with no `google-services.json` (`missingGoogleServicesStrategy` in `android/app/build.gradle.kts`), which is what lets `local` and `production` build. That also means a deleted beta file would build silently without Firebase, so `test/analytics/firebase_environment_test.dart` checks it exists and matches `lib/firebase_options.dart`. Never put a `google-services.json` at the `android/app` root: the plugin falls back to it for every flavor.
### Targeting the local Supabase stack

`.env.beta.json` points at the hosted **beta** project. To develop against the
local stack from `supabase start`, use `.env.local.json` instead (also
gitignored). It has no `SENTRY_DSN`: local sends no telemetry.

```json
{
  "APP_ENV": "local",
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_<local-key>"
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

- **`scripts/cloud-setup.sh`** is the heavy, slow-changing half: Flutter, the
  Supabase CLI and Deno at the versions pinned in the composite actions under
  `.github/actions/` (`setup-flutter`, `setup-supabase`, `setup-deno`; read from
  there, so bump them in one place), the Linux desktop build deps and
  xvfb the E2E job uses, the Supabase Docker images, and Playwright's Chromium
  (for `scripts/web-shot.mjs`, which signs in, turns on Flutter's accessibility
  tree and can run a flow from `scripts/web-flows/` that clicks widgets by role
  and name). It also prebuilds the Dart MCP server (see "Dart MCP server for
  Claude Code" below). Installs run in parallel to fit the ~5 minute cache budget, it
  always exits 0, and it writes per-stage results to
  `/var/lib/nomorex-cloud-setup.status`.
- **`.claude/hooks/session-start.sh`** is the light, per-session half: `flutter
  pub get`, start Docker and `supabase start` (processes don't survive the
  environment snapshot), and write `.env.local.json` for that stack (never
  overwritten if present; `APP_ENV` is `local` and `SENTRY_DSN` stays unset, so nothing is sent). If
  the toolchain isn't on disk it runs `cloud-setup.sh` itself, so it works
  with no setup script configured, only slower. It also installs Deno on its
  own when that's the only thing missing (a snapshot from before Deno was
  added), which takes a few seconds, and builds the Dart MCP server in the
  background when a snapshot from before that was added lacks it.

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

**Firebase in cloud sessions needs no setup.** Linux skips Firebase entirely (it isn't supported there), and debug web builds don't load it, so the E2E run, `verify.sh` and `web-shot.mjs` work as before with no extra hosts. To check events from a web build in a cloud session (`--dart-define=TELEMETRY_DEBUG=true`), the network must also allow `www.gstatic.com` and `www.googletagmanager.com`. Don't run `flutterfire configure` in a cloud session: it needs an interactive `firebase login`, and the generated config is committed, so nothing needs regenerating there.

Cloud sessions must never `supabase link`, `db push`, or reset with `--linked`
or `--db-url`; `.claude/settings.json` denies those.

Alternatively, you can pass values inline without the file:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_<your-publishable-key>
```

### Dart MCP server for Claude Code

`.mcp.json` gives Claude Code the Dart and Flutter MCP server (`dart mcp-server`,
part of the Dart SDK's tooling, so there's nothing to add to `pubspec.yaml`). It
adds:

- `lsp` and `analyze_files`: find references and definitions, and run the analyzer
  on specific files.
- `pub` and `pub_dev_search`: manage and look up packages.
- `hot_reload`, `widget_inspector` and `get_runtime_errors`: work with a running
  debug app.

It starts through `scripts/dart-mcp.sh`, which finds `dart` on `PATH`, in
`$FLUTTER_ROOT` or in `/opt/flutter`. An MCP server's `PATH` isn't guaranteed, and
in cloud sessions Flutter is only added to `PATH` for Bash commands.

- **Cloud sessions** load the repo's `.mcp.json` servers without asking.
- **Locally**, `enabledMcpjsonServers` in `.claude/settings.json` approves it once
  you've trusted the folder. Until then Claude Code asks the first time. Turn it off
  for yourself with `"disabledMcpjsonServers": ["dart"]` in
  `.claude/settings.local.json`.

To check it by hand, `./scripts/dart-mcp.sh` should wait silently for MCP messages
on stdin. Anything it prints to stdout corrupts the protocol, so the script's own
messages go to stderr.

**The first launch on a machine is slow.** The server isn't a prebuilt snapshot in
the SDK: the first `dart mcp-server` downloads the `dart_mcp_server` package from
pub.dev and AOT-compiles it into
`${XDG_STATE_HOME:-~/.local/state}/Dart/install/app-bundles/dart_mcp_server`. That
takes about 10s on an idle machine and more at session start, which is longer than
Claude Code's 30s MCP connect timeout allows, so a cold cloud container used to
report `dart (CONNECT_TIMEOUT)`. After that it starts in well under a second.

- **Cloud:** `cloud-setup.sh` prebuilds it into the environment snapshot
  (`build_dart_mcp` in `scripts/lib/cloud.sh`; the setup summary shows a
  `Dart MCP server` line). A snapshot made before that change lacks it. The
  SessionStart hook then builds it in the background, but it runs at the same time
  as Claude Code's first connect, so that session still times out: run `/mcp` and
  reconnect `dart` about a minute later. Rebuilding the environment cache (see
  "One-time setup" above) fixes it for good.
- **Locally:** the first launch builds it once per SDK. If that times out, run
  `./scripts/dart-mcp.sh </dev/null` once to build it, then reconnect with `/mcp`.
- **Diagnosing a timeout:** Claude Code logs each connection attempt to
  `~/.cache/claude-cli-nodejs/<project>/mcp-logs-dart/`. The server's stderr there
  (the "running flutter as root" banner is harmless) and a missing
  `app-bundles/dart_mcp_server` directory point at the cold build.

## CI / CD

For GitHub Actions (or any CI system), pass the values as secrets. Store `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as repository secrets in GitHub, then reference them in the workflow:

```yaml
- name: Build APK (debug)
  run: flutter build apk --debug --flavor local --dart-define=APP_ENV=local
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_PUBLISHABLE_KEY: ${{ secrets.SUPABASE_PUBLISHABLE_KEY }}
```

> Note: Dart's `--dart-define` reads from the build command, not from OS environment variables. For CI, pass them explicitly via `--dart-define` flags or `--dart-define-from-file` pointed at a generated file.

`.github/workflows/deploy.yml` (the GitHub Pages web app) and
`.github/workflows/deploy-ios.yml` (TestFlight) are the only workflows that
build a real deployed app, so they're also the only ones that pass
`SENTRY_DSN` and `APP_ENV=beta`. Both run in the `beta` GitHub Environment: the
`SENTRY_DSN` and `SUPABASE_PUBLISHABLE_KEY` secrets and the `SUPABASE_URL`
variable come from there (a job only sees an environment's values when it
declares the environment, so `deploy.yml` builds in a `beta` job and publishes
from a separate `github-pages` job). `pr-checks.yml` never deploys anywhere
real, so it builds as `local` and leaves `SENTRY_DSN` unset; an empty DSN just
disables the Sentry SDK for that build, same as an unset Supabase value leaves
it unable to connect.

### Sentry environments, releases and symbols

Local development and deployed apps are kept apart by environment, inside
the one `nomorex` Sentry project:

- **`local` sends nothing.** No local define file carries a DSN, and
  `lib/main.dart` drops the DSN for any build that doesn't collect telemetry
  (`collectsTelemetry`): every debug or profile build unless it opts in with
  `TELEMETRY_DEBUG=true`, and every `local` release build.
- **Deployed builds are tagged by `APP_ENV`.** `lib/main.dart` sets Sentry's
  environment from it. `deploy.yml` and `deploy-ios.yml` pass `beta`, so
  today's TestFlight and Pages builds report as `beta`; `production` is
  reserved for the store launch. A debug build that opted in reports as
  `local`, never `beta`. Alert rules and dashboards should filter on the
  environment tag.

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

## Firebase (Google Analytics)

Usage analytics go to Google Analytics for Firebase. Each environment has its own Firebase project (`firebaseOptionsFor()` in `lib/features/analytics/firebase_environment.dart` picks it from `APP_ENV`): **beta** is `nomorex-13bd9308`, **local** starts no Firebase at all, and **production** has none yet, so a production build runs without analytics until its project is created and its options are added there. Sentry stays the place for errors and crashes. The code lives in `lib/features/analytics/`.

- **Config is generated, not hand-written.** `flutterfire configure` wrote `lib/firebase_options.dart`, `android/app/src/beta/google-services.json` (the beta flavor's; `firebase apps:sdkconfig ANDROID <app id>` regenerates it), `ios/config/beta/GoogleService-Info.plist`, `macos/config/beta/GoogleService-Info.plist` (from `firebase apps:sdkconfig IOS <app id>`) and `firebase.json`. The API keys in them identify the Firebase project and aren't secrets (the same reasoning as the publishable key below), so they're committed. To regenerate, for example after adding a platform: `flutterfire configure -p nomorex-13bd9308 --platforms=android,ios,macos,web,windows -i com.nomorex.app -m com.nomorex.app --android-package-name=com.nomorex.app`. It needs the Firebase CLI, logged in.
- **App IDs:** Android, iOS and macOS are each registered as `com.nomorex.app.beta` (the beta flavor); macOS shares the iOS Firebase app. The older Firebase apps for `com.nomorex.app` (Android, iOS) were deleted from the beta project once testers had moved to the beta app (Nov 2026); production will register `com.nomorex.app` again in its own Firebase project at launch.
- **Platforms:** Firebase is initialized on Android, iOS, macOS and web only (`analyticsPlatformSupported`). Linux and Windows run without it, which is how CI's Linux E2E run stays off Firebase.
- **Debug builds send nothing.** Only release builds of `beta` and `production` collect (`analyticsCollectsInThisBuild`, from `APP_ENV`; a `local` release build sends nothing either), unless a debug build opts in with `TELEMETRY_DEBUG=true`. On web, a build that doesn't collect skips Firebase entirely, so `flutter run -d chrome`, `verify.sh`'s web build, Playwright and cloud sessions never contact Google. Native debug builds still initialize it, because the native SDKs start on their own and have to be told to stop collecting.
- **Firebase never holds up startup.** On web, Firebase loads its SDK from `www.gstatic.com/firebasejs/` and never finishes if that's blocked (an ad blocker, a filtered network), which left the app on its splash screen. `initFirebase()` gives up after `firebaseInitTimeout` (5 s) and the app runs without analytics. A timeout isn't sent to Sentry. To see events in the Firebase console's DebugView, build with `--dart-define=TELEMETRY_DEBUG=true` and enable debug mode on the device (`adb shell setprop debug.firebase.analytics.app com.nomorex.app.beta` on Android, with the beta flavor; `-FIRDebugEnabled` as a launch argument in Xcode on iOS).
- **Opt-out:** Profile → "Share usage analytics", saved per device (`AnalyticsConsentNotifier`).
- **No advertising-ID SDKs on iOS.** `firebase_analytics` bundles Google's ad-ID SDKs (`GoogleAppMeasurementIdentitySupport`, `GoogleAdsOnDeviceConversion`) unless `FIREBASE_ANALYTICS_WITHOUT_ADID` is set while Swift Package Manager resolves packages. Both iOS jobs (`build-ios` in `pr-checks.yml`, `deploy-ios.yml`) set it and then run `./scripts/check-ios-no-adid.sh`, which fails if either framework is in the app; the deploy checks the archive before anything is uploaded. **The variable only works with cold SwiftPM caches:** SwiftPM caches resolved manifests and ignores the variable once one is cached, so it can silently do nothing. CI runners start cold. Local builds don't ship, so they don't need it, but to reproduce the shipped app locally, clear this project's caches first: `rm -rf build/ios`, the `~/Library/Developer/Xcode/DerivedData/Runner-*` folder whose `info.plist` `WorkspacePath` is this repo's `ios/Runner.xcworkspace`, and `~/Library/Caches/org.swift.swiftpm/manifests`. Then run `FIREBASE_ANALYTICS_WITHOUT_ADID=true flutter build ios --release --no-codesign && ./scripts/check-ios-no-adid.sh`. `Package.resolved` is the same either way. macOS has no such switch, but macOS isn't shipped.
- **Advertising is off.** The Android manifest removes the `AD_ID` permission and turns off ad-ID collection and ad personalization; `ios/Runner/Info.plist` turns off ad personalization. The app never calls `setUserId`, so events aren't linked to accounts. The privacy policy and store disclosures rely on all of this. In the Google Analytics property, keep Google signals off, keep ads personalization off, and keep event data retention at 14 months or less, which is what the privacy policy states.

## iOS: TestFlight deploys

`.github/workflows/deploy-ios.yml` builds a signed release IPA on every push to
`main` (same idea as the web deploy, with its own `paths-ignore`) and uploads it
to App Store Connect, where it shows up in TestFlight. Run it by hand from the
Actions tab (`workflow_dispatch`) to retry or force a build. It runs on a
GitHub-hosted `macos-26` runner, which is free because the repo is public.

It builds the **beta** flavor (`flutter build ios --flavor beta`, then
`xcodebuild archive -scheme beta -configuration Release-beta`), so it uploads to
the `com.nomorex.app.beta` app record ("NoMoreX (Beta)" in TestFlight). The
original `com.nomorex.app` record gets no builds; it is reserved for the
production listing at launch, and its last TestFlight build simply expires.
Production will get its own deploy workflow rather than reusing this one.

**Versioning.** It uses the same `version.yml` outputs as the web deploy:
`CFBundleShortVersionString` is GitVersion's MajorMinorPatch and
`CFBundleVersion` is the commit count. Many builds share one version (e.g.
1.4.2 builds 312, 313, ...), which TestFlight accepts because the build number
always goes up.

**Signing uses two certificates.** Both `xcodebuild archive` and
`xcodebuild -exportArchive` run with `-allowProvisioningUpdates` and an App
Store Connect API key, so Xcode creates/refreshes provisioning profiles itself
and no profile is stored.

- **Archive** signs with one long-lived **Apple Development** certificate,
  imported from the `IOS_DEV_CERT_P12` secret into a temporary keychain.
  Development certificates aren't cloud-managed (the private key must be in
  the local keychain), so without it Xcode creates a new "Created via API"
  certificate on every fresh runner until the account hits Apple's
  certificate limit. The archive step fails if that ever happens again.
- **Export** re-signs with the team's **cloud-managed distribution
  certificate** (its private key stays at Apple, nothing stored).

Don't make the archive unsigned (`CODE_SIGNING_ALLOWED=NO`) to avoid the
development certificate. That was tried: Sentry ships a static framework,
Xcode embeds it as a generated stub binary that only the archive's CodeSign
step signs, and export then fails with "Invalid Signature … Sentry.framework".

`ios/ExportOptions.plist` sets `destination=upload`, so
the export step also does the upload. `flutter build ipa` isn't used because it
can't pass the API-key flags through to xcodebuild. Instead
`flutter build ios --config-only` bakes the dart-defines and version into the
Xcode config first.

**Export compliance.** `Info.plist` declares `ITSAppUsesNonExemptEncryption =
false` (the app only uses HTTPS/TLS, which is exempt), so App Store Connect
doesn't ask the encryption question on every build.

### One-time Apple setup

Already done for this repo (Nov 2026): the beta app record `com.nomorex.app.beta`
exists, the App IDs for `com.nomorex.app`, `.beta` and `.local` are registered
(the original `com.nomorex.app` record, Apple ID `6829556503`, is reserved for
production), and the three `APP_STORE_CONNECT_*` secrets are set. A `local`
build is never uploaded, so it needs an App ID (for signing on a device) but no
app record.
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
   bundle ID of each environment: `com.nomorex.app.beta` (what the deploy
   uses), `com.nomorex.app.local` and `com.nomorex.app`. No extra capabilities
   are needed. Automatic signing can create them on the first CI run, but
   registering them up front avoids a confusing signing failure.

3. **App record.** At <https://appstoreconnect.apple.com/apps>, click **+**
   and choose **New App**:
   - Platform: iOS
   - Name: must be unique across the whole App Store
   - Primary language: your choice
   - Bundle ID: `com.nomorex.app.beta` (the deploy builds beta)
   - SKU: any string, e.g. `com.nomorex.app.beta`

   The App Store Connect name is what testers see in the TestFlight app. The
   name under the icon on a device comes from `CFBundleDisplayName`, which each
   flavor sets through `APP_DISPLAY_NAME` (`NoMoreX (Beta)` for beta; see
   "Platform flavors").

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
   | `IOS_DEV_CERT_P12` | base64 of an Apple Development certificate + private key, as .p12 (see below) |
   | `IOS_DEV_CERT_PASSWORD` | the password set when exporting that .p12 |

   ```bash
   base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy   # then paste as the secret value
   gh secret list | grep APP_STORE                        # confirm all three exist
   ```

   For the .p12: in **Keychain Access**, open **My Certificates**, find
   **Apple Development: <name> (<team>)**, expand it to check it has a private
   key, right-click the certificate and **Export** as `.p12` with a password.
   Then:

   ```bash
   base64 -i ~/Downloads/dev-cert.p12 | gh secret set IOS_DEV_CERT_P12
   gh secret set IOS_DEV_CERT_PASSWORD   # prompts for the password
   rm ~/Downloads/dev-cert.p12
   ```

   Development certificates expire after a year. When it does, the archive
   step fails (instead of quietly creating a new certificate). Export a fresh
   one and replace both secrets.

   `SUPABASE_URL` (a variable), `SUPABASE_PUBLISHABLE_KEY` and `SENTRY_DSN`
   (secrets) are the same `beta` environment values the web deploy uses; the
   job declares `environment: beta` to see them. The workflow's first step fails with a clear
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
  - "Your account has reached the maximum number of certificates", or the
    archive step's "Xcode created a new development certificate" error: the
    `IOS_DEV_CERT_P12` certificate wasn't usable (expired, revoked or
    missing its private key) so Xcode minted new ones (see "Signing uses two
    certificates" above). Replace the secret, then revoke the extra
    "Created via API" **Apple Development** certificates at
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

Migrations are applied to the hosted project by the **Supabase GitHub
integration**, which watches `supabase/` and deploys on push to `main`. The
hosted project is **beta** today; it is the only one the integration is linked
to. The `Deploy` workflow in `.github/workflows/deploy.yml` only builds and
publishes the web app; it no longer runs `supabase db push`. The integration
also deploys the `ai-import-cleanup` function (declared in `config.toml`), but
not the `ai` edge function; see "AI backend" below.

The two run independently, so a schema change and the app build that depends on
it are not ordered. Ship additive migrations ahead of the code that needs them.

### Per-environment Supabase settings

Each environment has its own Supabase project, and nothing here is shared
between them. `local` is the `supabase start` stack; `beta` is the hosted
project the deploys use today; `production` gets its own project at launch.

| What | Where it lives | Used by |
| --- | --- | --- |
| Project URL | `SUPABASE_URL` variable in the environment's GitHub Environment (`beta`) | the app builds (`deploy.yml`, `deploy-ios.yml`), `ai-import-cleanup.yml`, `deploy-functions.yml` (which takes the CLI's project ref from its host) |
| Publishable key | `SUPABASE_PUBLISHABLE_KEY` secret in the same environment | the app builds |
| Cleanup secret | `AI_IMPORT_CLEANUP_SECRET`: a secret in the GitHub Environment **and** a function secret on that project's Supabase, the same value in both and a different value per project | `ai-import-cleanup.yml` and the `ai-import-cleanup` function |
| Anthropic key | `ANTHROPIC_API_KEY` function secret on that project (see "AI backend") | the `ai` function |
| Migrations and the cleanup function | the Supabase GitHub integration, linked to one project | every push to `main` |

A workflow only sees a GitHub Environment's values when its job declares
`environment: <name>`, which is why `ai-import-cleanup.yml` and
`deploy-functions.yml` say `environment: beta`.

**Adding `production`:** create the project, create a `production` GitHub
Environment with its own `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
`SENTRY_DSN` and `AI_IMPORT_CLEANUP_SECRET`, set the function secrets on the new
project, give it its own Supabase GitHub integration link, run the official
exercise catalog SQL (see "Official exercise catalog"), and create its first
admin by hand. Then add `production` jobs to the workflows rather than reusing
`beta`'s.

### Admins

Roles are rows in `public.user_roles`. They can only be changed by an existing
admin, through the `admin_grant_role` / `admin_revoke_role` functions, and every
change is written to `public.admin_audit_log`. Locally, `seed.sql` makes
`a@a.com` an admin.

A new project has no admin, so create the first one by hand, once, in the
Supabase dashboard's SQL editor (the migration must have landed first):

```sql
insert into public.user_roles (user_id, role)
select id, 'admin' from auth.users where email = '<your email>';
```

Check it with
`select u.email, r.role from public.user_roles r join auth.users u on u.id = r.user_id;`.
Every admin after that is added from the app. No email belongs in a migration
or in `seed.sql`, because the repo is public.

### Official exercise catalog

Official exercises (`is_predefined = true`) are edited in the database, and
`supabase/catalog/official_exercises.sql` keeps a copy in the repo so the
catalog survives a database wipe. The file is an upsert keyed on each
exercise's `slug`, so it is safe to run any number of times:

- `supabase db reset` loads it automatically, before `seed.sql`.
- After wiping a hosted project, open its SQL editor and run the file once.
  It creates every exercise it lists and updates any with the same slug. It
  never deletes anything.

Edit the catalog in the app at Profile → Admin → Exercises, then use its
**Export catalog** button: it shows this file's exact contents with a Copy
button. Paste that over the file and commit it. A slug is permanent: changing
one in the file adds a second exercise rather than renaming the first. If a
run stops with `duplicate: "…" already uses one of these names or aliases`,
an exercise already in the database answers to a name the file gives a
different slug. Retire or rename that row, then run the file again.

## AI backend (Genkit edge function)

AI features run in one Supabase Edge Function, `supabase/functions/ai`, built
with Genkit JS and the Anthropic plugin. The Anthropic API key lives only there,
as a function secret. It never ships in the app.

### Secrets

| Where          | How                                                                                     |
| -------------- | --------------------------------------------------------------------------------------- |
| Local          | `supabase/functions/.env` containing `ANTHROPIC_API_KEY=sk-ant-...` (gitignored by `.env`) |
| Beta           | `supabase secrets set ANTHROPIC_API_KEY=sk-ant-... --project-ref <beta ref>`, or Dashboard → Edge Functions → Secrets |
| Production     | the same, on the production project, with its own key and spend limit (not created yet) |

Each Supabase project has its own key; never reuse one across environments.

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are injected by the edge runtime; don't
set them. The function deliberately never uses the service-role/secret key.

How a key problem shows up in the app's "Test AI connection":

- **Key missing:** the Anthropic plugin throws at startup, so the worker fails to
  boot. The gateway answers `503 BOOT_ERROR`, which the app shows as "The AI
  request failed (HTTP 503)".
- **Key wrong, or the account is out of credit:** the function boots, and every
  flow that calls the model returns `503 UNAVAILABLE` ("The AI service is
  unavailable right now…").

Either way the real error is in the function logs: `supabase functions serve`
output locally (or `docker logs supabase_edge_runtime_nomorex`), Dashboard →
Edge Functions → Logs on the hosted project.

The worker also fails to boot with `BOOT_ERROR` if a `deno.lock` turns up in
`supabase/functions/ai`. `deno.json` sets `"lock": false` so local `deno`
runs don't write one; delete any that appears.

### Running locally

```bash
supabase start
supabase functions serve ai          # http://127.0.0.1:54321/functions/v1/ai/<flow>
flutter run -d chrome --dart-define-from-file=.env.local.json
```

In a debug build, Profile → Developer → **Test AI connection** runs the
`smokeTest` flow. It checks your session, an RLS-scoped database read and a
Claude call in one go. Or use curl with a real session:

```bash
TOKEN=$(curl -s "http://127.0.0.1:54321/auth/v1/token?grant_type=password" \
  -H "apikey: <publishable key>" -H 'Content-Type: application/json' \
  -d '{"email":"a@a.com","password":"123456"}' | jq -r .access_token)
curl -X POST http://127.0.0.1:54321/functions/v1/ai/smokeTest \
  -H "apikey: <publishable key>" -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"data":{}}'
```

Genkit traces: run the same handler under the Genkit CLI with
`supabase/functions/ai/dev.ts`. Instructions are in that file. Its `.env` also
needs `SUPABASE_URL`/`SUPABASE_ANON_KEY` for the local stack, because plain
`deno run` doesn't inject them.

### Checks

`deno task check` in `supabase/functions/ai` runs fmt, lint, type-check and the
unit tests (fake model, fake Supabase client: no network, no key). CI runs it in
the `functions` job; `scripts/verify.sh` runs it too, through Docker if Deno
isn't installed. Cloud sessions install Deno (see "Claude Code on the web"), so
they don't depend on pulling the `denoland/deno` image, which Docker Hub
rate-limits. Deno is pinned (`.github/actions/setup-deno`, currently 2.1.4) to match the edge runtime.

### Deployment

`.github/workflows/deploy-functions.yml` deploys the function on any push to
`main` that changes `supabase/functions/ai/**`. It can also be run by hand from
the Actions tab. After deploying, it confirms that a request with no session gets
a 401. Deploy the function ahead of any app build that calls a new flow, the same
rule as additive migrations.

**Don't declare `[functions.ai]` in `supabase/config.toml`.** The Supabase GitHub
integration deploys any function declared there, bundling it on Supabase's
servers, where the limit is 5 MB. It fails with `413 request entity too large`.
The CLI bundles locally with Docker, where the limit is 20 MB. The function is
about 18.7 MB, nearly all of it Genkit and its dependencies, so check the size
before adding npm dependencies. New flows barely change it.

Setup, once per project:

1. Set `ANTHROPIC_API_KEY` on the hosted project (see Secrets above).
2. Create a Supabase access token (Dashboard → Account → Access Tokens) and add
   it as the `SUPABASE_ACCESS_TOKEN` repository secret. A scoped token needs
   `edge_functions_write`, `edge_functions_read` and `projects_read`.

## E2E tests

The `integration_test/` suite boots the real app against the local Supabase
stack, so it needs the same compile-time dart-defines as a normal run. Use the
runner rather than invoking `flutter test` directly:

```bash
./scripts/e2e.sh          # macOS desktop, stack as it is
./scripts/e2e.sh linux    # Linux desktop, how CI runs it
./scripts/e2e.sh --reset  # reset the local DB to the seed first
./scripts/e2e.sh --file integration_test/app_test.dart   # one file
```

It starts the stack and builds and launches the app once to run every file in
`integration_test/all_tests.dart`. The suite signs in as its own seeded user
(`e2e@e2e.com`), so it doesn't need a fresh database and leaves `a@a.com`'s data
alone. `--reset` runs `supabase db reset` (local only); CI and `verify.sh` pass
it, and you need it once if your local stack was seeded before that user
existed. Locally it reads `.env.local.json`; in CI, where that file doesn't
exist, it reads `API_URL` and `PUBLISHABLE_KEY` off the running stack via
`supabase status -o env`.

If the suite is ever pointed at an Android emulator, the URL must be
`http://10.0.2.2:54321` rather than `127.0.0.1`, for the same reason described
above.
