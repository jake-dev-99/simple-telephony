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

# Replace path dependencies with hosted version constraints in a pubspec.yaml.
# Only runs during --live publish. Reverted after publish via git checkout.
swap_path_to_hosted() {
  local pubspec="$1"
  local interface_version
  interface_version=$(grep '^version:' "$ROOT_DIR/simple_telephony_platform_interface/pubspec.yaml" | awk '{print $2}')
  local android_version
  android_version=$(grep '^version:' "$ROOT_DIR/simple_telephony_android/pubspec.yaml" | awk '{print $2}')

  # Replace multi-line path deps with single-line hosted deps.
  sed -i.bak \
    -e "/simple_telephony_platform_interface:/{n;s|.*path:.*|  simple_telephony_platform_interface: ^${interface_version}|;}" \
    -e "/simple_telephony_android:/{n;s|.*path:.*|  simple_telephony_android: ^${android_version}|;}" \
    "$pubspec"

  # Clean up: remove lines that are now just the package name with no value
  # (the sed above replaces the path: line but leaves the original key: line)
  sed -i.bak \
    '/^  simple_telephony_platform_interface:$/d;/^  simple_telephony_android:$/d' \
    "$pubspec"

  rm -f "${pubspec}.bak"
}

revert_pubspecs() {
  log "Reverting pubspec.yaml files..."
  for pkg in "${PACKAGES[@]}"; do
    git -C "$ROOT_DIR" checkout -- "$pkg/pubspec.yaml" 2>/dev/null || true
  done
}

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

  # Analysis — allow path-dep warnings during dev, strict for live.
  log "  Analyzing..."
  (cd "$pkg_dir" && dart analyze --no-fatal-warnings) || fail "$pkg: Analysis found errors."

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
if $LIVE; then
  # Swap path deps to hosted version constraints for publish, revert on exit.
  trap revert_pubspecs EXIT
  for pkg in "${PACKAGES[@]}"; do
    swap_path_to_hosted "$ROOT_DIR/$pkg/pubspec.yaml"
  done
fi

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
