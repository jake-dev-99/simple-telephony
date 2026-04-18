# Release flow

Three-branch promotion pipeline with pub.dev publishing gated on
`main`:

```
feature branch
     │  PR  ▼  (CI runs)
  develop
     │  PR  ▼  (CI runs)
  staging
     │  PR  ▼  (CI runs)
    main
     │  push to main ▼  (auto-tag bumps versions + tags commit)
     │  tag push ▼      (publish.yml runs OIDC pub.dev release)
    pub.dev
```

## Branch intent

| Branch | Role |
|---|---|
| `develop` | Default working branch. Feature branches PR here. |
| `staging` | Pre-release gate. Pre-release publishes (e.g. `0.5.0-dev.1`) can cut from here. |
| `main` | Production. Tag pushes trigger pub.dev publishing. |

CI runs on PRs to any of the three. CD runs on **tag push** —
merges to `main` don't auto-publish; tagging is the explicit
release gesture.

## Cutting a release

1. Land your work on `develop` via PRs.
2. `develop` -> `staging` PR. CI runs. Merge.
3. `staging` -> `main` PR. CI runs. Merge.
4. The push to `main` triggers
   [`auto-tag.yml`](../.github/workflows/auto-tag.yml). Per
   changed package it:
   - Reads the current `pubspec.yaml` version.
   - Finds the highest existing `<package>-v<semver>` tag.
   - Picks `max(pubspec_version, highest_tag + 0.0.1)`.
   - Rewrites the pubspec, commits with `[skip ci]`, tags,
     pushes.
5. The tag push fires
   [`publish.yml`](../.github/workflows/publish.yml), which
   verifies the tag version matches `pubspec.yaml` and runs
   `dart pub publish --force` via OIDC.

**Shipping a minor or major release** is just *"bump the
pubspec on the merge PR"*. The auto-tagger sees the pubspec is
past its patch-bump candidate and respects the manual intent.

## Tag patterns (one per federated package)

| Package | Tag prefix | Working dir |
|---|---|---|
| `simple_telephony_native` | `simple_telephony_native-v` | `simple_telephony_native` |
| `simple_telephony_platform_interface` | `simple_telephony_platform_interface-v` | `simple_telephony_platform_interface` |
| `simple_telephony_android` | `simple_telephony_android-v` | `simple_telephony_android` |

Each package's version advances independently.

## One-time pub.dev setup (per package)

Before the first tag-triggered release, each federated package
must be configured:

1. Visit `https://pub.dev/packages/<package>/admin`.
2. Enable **Automated publishing** -> *Publishing from GitHub Actions*.
3. Fill in:
   - **Repository**: `<owner>/simple-telephony`
   - **Tag pattern**: `<package>-v{{version}}`
4. Save.

Without this, `dart pub publish` from the workflow errors with
`missing OIDC authorization` and the release fails cleanly.

## Why this shape

- **CI on PR opened.** Catches breakage before merge.
- **CD on tag, not on merge.** A merge to `main` might be a
  doc fix or a revert — the tag is the intent-to-release signal.
- **Per-package tags.** pub.dev's automated-publishing contract
  ties one tag pattern to one package; per-package tagging
  sidesteps monorepo-publishing tooling we don't need.
- **OIDC (no stored tokens).** Current pub.dev recommendation;
  no long-lived credential in the repo.
