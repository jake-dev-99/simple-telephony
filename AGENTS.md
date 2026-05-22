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

Dart `^3.6.0`. Mirror CI (`.github/workflows/verify.yml`), a per-package
analyze + test matrix. Before any push, in each touched package:

```sh
flutter pub get
flutter analyze --no-fatal-warnings
flutter test
```

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
`.github/workflows/release.yml`; see [`docs/runbooks/`](docs/runbooks/).

## What NOT to do (binding rulings)

- **Don't break the platform-interface API without a major version bump** —
  downstream (Unify Messages+) depends on it.
- **Don't rename or drift EventChannel names** between the facade and the
  Android implementation — it breaks foreground event delivery in the
  consumer at runtime, silently at build time.
- **Don't push without the verify gate green** (`analyze
  --no-fatal-warnings` + `test`). CI is a backstop, not discovery.
- **Don't commit secrets.**
- **Don't add app-level concerns** here (GTM, brand, product roadmap) —
  this is a library.
