# Runbooks

Operational procedures for `simple_telephony`.

| Runbook | For |
| --- | --- |
| [../RELEASE.md](../RELEASE.md) | Release/publish procedure (kept at `docs/` root for now). |

Release + deploy are automated via `.github/workflows/release.yml` and
`.github/workflows/deploy.yml` (`main`-only, tag-driven). Add rollback / incident procedures
here as they're needed. For day-to-day build/test/verify commands, see
[`AGENTS.md`](../../AGENTS.md).
