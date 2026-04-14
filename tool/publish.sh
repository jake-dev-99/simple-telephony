#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Publish order matters: interface first, then platform packages, then app-facing.
PACKAGES=(
  simple_telephony_platform_interface
  simple_telephony_android
  simple_telephony
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  echo -e "${BOLD}Usage:${NC} tool/publish.sh [--live] [--help]"
  echo ""
  echo "Validate and publish all simple_telephony packages to pub.dev."
  echo ""
  echo "  (no args)   Dry run — analysis, tests, and pub publish --dry-run"
  echo "  --live      Publish to pub.dev (15 s pause between packages)"
  echo "  --help      Show publish order with current versions"
  echo ""
  echo -e "${BOLD}Publish order:${NC}"
  for pkg in "${PACKAGES[@]}"; do
    local version
    version=$(grep '^version:' "$ROOT_DIR/$pkg/pubspec.yaml" | awk '{print $2}')
    echo "  $pkg  v$version"
  done
}

log()  { echo -e "${GREEN}[publish]${NC} $*"; }
warn() { echo -e "${YELLOW}[publish]${NC} $*"; }
fail() { echo -e "${RED}[publish]${NC} $*" >&2; exit 1; }

LIVE=false

for arg in "$@"; do
  case "$arg" in
    --live) LIVE=true ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $arg" ;;
  esac
done

# --- Step 1: Verify clean git state ---
log "Checking git state..."
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  if $LIVE; then
    fail "Working tree is dirty. Commit or stash before publishing."
  else
    warn "Working tree is dirty (ok for dry run)."
  fi
fi

# --- Step 2: Validate each package ---
for pkg in "${PACKAGES[@]}"; do
  pkg_dir="$ROOT_DIR/$pkg"
  log "━━━ ${BOLD}$pkg${NC} ━━━"

  # Analysis — fail on errors, allow warnings during dev (path deps are expected).
  # --live publish uses --fatal-infos after path deps are replaced with versions.
  log "  Analyzing..."
  if $LIVE; then
    (cd "$pkg_dir" && dart analyze --fatal-infos) || fail "$pkg: Analysis failed."
  else
    (cd "$pkg_dir" && dart analyze --no-fatal-warnings) || fail "$pkg: Analysis found errors."
  fi

  # Flutter tests
  log "  Testing..."
  (cd "$pkg_dir" && flutter test) || fail "$pkg: Tests failed."

  # Android Gradle tests (only for android package)
  if [[ "$pkg" == "simple_telephony_android" && -n "${ANDROID_HOME:-}" ]]; then
    log "  Running Android unit tests..."
    FLUTTER_ROOT="${FLUTTER_ROOT:-$(dirname "$(which flutter)")/..}"
    export FLUTTER_ROOT
    (cd "$pkg_dir/android" && ./gradlew test) || fail "$pkg: Android tests failed."
  fi
done

# --- Step 3: Publish ---
for pkg in "${PACKAGES[@]}"; do
  pkg_dir="$ROOT_DIR/$pkg"

  if $LIVE; then
    log "Publishing $pkg..."
    (cd "$pkg_dir" && dart pub publish --force)
    log "Published $pkg. https://pub.dev/packages/$pkg"

    # Pause between packages so pub.dev indexes the dependency before
    # the next package tries to resolve it.
    if [[ "$pkg" != "${PACKAGES[-1]}" ]]; then
      log "Waiting 15 s for pub.dev indexing..."
      sleep 15
    fi
  else
    log "Dry run: $pkg..."
    (cd "$pkg_dir" && dart pub publish --dry-run) || true
  fi
done

if $LIVE; then
  log "All packages published."
else
  log "Dry run complete. Use --live to publish for real."
fi
