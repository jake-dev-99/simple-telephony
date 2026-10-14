# AGENTS.md — working in `simple-telephony`

Canonical guide for any agent or contributor in this repo (Claude Code
reads it via [`CLAUDE.md`](CLAUDE.md), which `@`-imports this file).
Keep it short and true.

## What this is

**`simple_telephony_native`** — a **federated Flutter plugin** for telephony
/ calls (call state, dialer integration). It is a **Simple Zen Plugin** (a
library, not a consumer app), consumed by **Unify Messages+** as a path/pub
dependency. Governance: the Simple Zen SOP family in Notion (Documentation
Standard, Code Quality Standards, Toolchain Architecture). As `Type =
Plugin`, the App-only gates (Linear project, Figma, consumer Category,
GTM/brand) do **not** apply; code-quality, semver/API-stability, tests, and
docs do.

## Layout (federated)

```
simple_telephony_native              # facade package
simple_telephony_platform_interface  # the contract — the load-bearing API
simple_telephony_android             # Android implementation
tool/                                # repo tooling
```

There is **no root `pubspec.yaml`**; each package is its own pub package.
The **platform interface is the contract**; the facade dispatches to the
platform implementations.

## Build · test · verify

Dart `^3.6.0`; `simple_telephony_android` needs Dart `>=3.12.0` / Flutter
`>=3.44.0` (Built-in Kotlin). Mirror CI (`.github/workflows/verify.yml`), a
per-package analyze + test matrix. Before any push, in each touched package:

```sh
flutter pub get
flutter analyze --no-fatal-warnings
flutter test
```

**When you touch `simple_telephony_android/android/` (Kotlin), also run the
native gate.** `flutter test` is Dart-only — it never compiles or runs the
Robolectric tests under `simple_telephony_android/android/src/test/`. They
run through the *example app's* Gradle (a bare `:simple_telephony_android`
invocation can't configure on its own), so build once to inject the wrapper
+ `local.properties`, then test. The example resolves `simple-permissions`
and `simple-query` from sibling checkouts next to this repo, as CI lays them
out:

```sh
(cd simple_telephony_native/example && flutter build apk --debug)
(cd simple_telephony_native/example/android && ./gradlew :simple_telephony_android:testDebugUnitTest --console=plain)
```

CI runs the same gate on every PR that touches the native side
(`.github/workflows/verify-native.yml`, path-gated; UNFY-199).

## Conventions that have teeth

- **The platform-interface contract is versioned.** A breaking change to
  `simple_telephony_platform_interface` is a **major** bump, and the
  platform implementation(s) move with it in the same change.
- **The foreground EventChannel registration must stay in sync with the
  facade.** Drift here surfaces as `MissingPluginException` on
  `EventChannel.listen` at startup in the consumer (this has bitten
  Unify before) — keep channel names identical across the facade and the
  Android implementation.
- `analysis_options.yaml` is the lint baseline; analyze must be clean.
- See `docs/handoff-simple-query-calls-domain.md` for the calls-domain
  boundary with `simple-query`.

## Git workflow

`main`-only with git tags for releases (no `develop`/`staging`). One
short-lived branch per work item; PRs target `main`. Releases are cut via
`.github/workflows/release.yml`; see [UNFY-345 release procedure](https://linear.app/simple-zen/issue/UNFY-345/repair-plugin-dependency-floors-and-telephony-release-example).

Release batches select changed packages and affected dependents. After one manual
Cut Release dispatch, hourly scheduled runs resume only that frozen batch;
quota deadlines and completed publications survive runner restarts. Per-package
hosted validation precedes each dependency-ordered tag. Execution and recovery live in the Linear procedure linked above.

## What NOT to do (binding rulings)

- **Don't break the platform-interface API without a major version bump** —
  downstream (Unify Messages+) depends on it.
- **Don't rename or drift EventChannel names** between the facade and the
  Android implementation — it breaks foreground event delivery in the
  consumer at runtime, silently at build time.
- **Don't push without the verify gate green** (`analyze
  --no-fatal-warnings` + `test`, plus the native gate when you touch
  `simple_telephony_android/android/`). CI is a backstop, not discovery.
- **Don't commit secrets.**
- **Don't add app-level concerns** here (GTM, brand, product roadmap) —
  this is a library.

## Release tooling configuration

`tool/release-packages.json` defines package ownership; `release_coordinator.py`
coordinates frozen batches, dependency gates, and original tag-push Deploy runs.
The app credentials are `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY`;
`GITHUB_TOKEN` accesses draft journals and Actions recovery. Package tags follow
`<package>-v<version>`. `PUB_MAX_HTTP_RETRIES=1` leaves quota recovery to the
coordinator rather than SDK retries. Authored dependency overrides are rejected.
