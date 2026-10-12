# Release flow

`main`-only with tag-driven pub.dev publishing, per the Simple Zen
Toolchain Architecture SOP.

```text
feature branch
     │  PR  ▼  (CI runs)
    main
     │  release.yml workflow_dispatch ▼  (bumps + tags)
     │  tag push ▼                       (deploy.yml runs OIDC publication)
    pub.dev
```

## Cutting a release

1. Land the reviewed change through a PR to `main`.
2. Dispatch [`release.yml`](../.github/workflows/release.yml) on `main`,
   selecting one package and a `patch`, `minor`, or `major` increment.
   The workflow increments that package's current source version, prepends
   its CHANGELOG entry, commits, tags, and pushes. It does not rewrite
   dependency constraints. `dry_run=true` previews the version and notes;
   this workflow does not validate dependency resolution or analysis.
3. The tag triggers [`deploy.yml`](../.github/workflows/deploy.yml), which
   verifies ancestry and version before publishing via OIDC. The current
   publish step skips validation, so run resolution, analysis, tests, and
   `flutter pub publish --dry-run` locally before cutting.

## Current dependency release order

The source interface removes the published `isDefaultDialerApp` and
`requestDefaultDialerApp` methods and adds the call-log, device, SIM, and
background-delivery APIs. Per `AGENTS.md`, this contract change requires
coordinated major versions across the Telephony federation.

Leave source versions for Cut Release to increment; selecting `major` from
`0.1.1` produces `1.0.0`. Publish in dependency order, waiting for each
prerequisite to appear on pub.dev:

1. Publish `simple_query_android` and `simple_query` `0.3.0` and
   `simple_permissions_native` `1.6.4` with its platform prerequisites.
2. Cut `simple_telephony_platform_interface` with `major` (`1.0.0`).
3. Cut `simple_telephony_android` with `major` (`1.0.0`); its floors are
   `simple_query ^0.3.0` and `simple_telephony_platform_interface ^1.0.0`.
4. Cut `simple_telephony_native` with `major` (`1.0.0`); both Telephony
   dependency floors are `^1.0.0`. Its bundled example requires hosted
   `simple_permissions_native ^1.6.4`.

Do not select `all`: tag-triggered publish jobs run independently and can
start before their prerequisites are published. Keep dependent PRs draft
while those publications are unavailable. Development sibling overrides
prove source compatibility only; remove them in isolated copies for the
published dependency checks. For publication failures and manual retry
caveats, consult the recovery notes in [Deploy](../.github/workflows/deploy.yml)
before retrying.

## Tag patterns (one per federated package)

| Package | Tag prefix | Working dir |
|---|---|---|
| `simple_telephony_native` | `simple_telephony_native-v` | `simple_telephony_native` |
| `simple_telephony_platform_interface` | `simple_telephony_platform_interface-v` | `simple_telephony_platform_interface` |
| `simple_telephony_android` | `simple_telephony_android-v` | `simple_telephony_android` |

Each package's version advances independently.

## One-time pub.dev setup (per package)

Before the first tag-triggered release, each federated package must be
configured:

1. Visit `https://pub.dev/packages/<package>/admin`.
2. Enable **Automated publishing** → *Publishing from GitHub Actions*.
3. Fill in:
   - **Repository**: `<owner>/simple-telephony`
   - **Tag pattern**: `<package>-v{{version}}`
4. Save.

Without this, `dart pub publish` from the workflow errors with
`missing OIDC authorization` and the release fails cleanly.

## Why this shape

- **CI on PR opened.** Catches breakage before merge.
- **CD on tag, not on merge.** A merge to `main` might be a doc fix or
  a revert — the tag is the intent-to-release signal.
- **Per-package tags.** pub.dev's automated-publishing contract ties
  one tag pattern to one package; per-package tagging sidesteps
  monorepo-publishing tooling we don't need.
- **OIDC (no stored tokens).** Current pub.dev recommendation; no
  long-lived credential in the repo.
