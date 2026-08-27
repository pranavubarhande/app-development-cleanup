#!/usr/bin/env bash
# Frees up macOS disk space by clearing iOS/Xcode/CocoaPods toolchain
# caches machine-wide - NOT project files. Nothing here touches any
# project's source, Pods/, or build folder. Everything removed here is
# downloadable/regeneratable: next time you open a project, Xcode will
# re-index and CocoaPods/SwiftPM will re-install whatever they need fresh.
#
# Intentionally left alone: Xcode Archives (real build output, e.g. for
# App Store submission) and iOS DeviceSupport symbol caches (slow to
# regenerate, only relevant when debugging on a physical device).
#
# Usage:
#   clean-ios.sh            # clean
#   clean-ios.sh --deep     # also clear CoreSimulator's cache dir
#   clean-ios.sh --dry-run  # show what would be removed, remove nothing

set -uo pipefail

if [ -z "${HOME:-}" ]; then
  echo "error: \$HOME is not set, cannot locate caches" >&2
  exit 1
fi

DEEP=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=true ;;
    --dry-run) DRY_RUN=true ;;
    *)
      echo "error: unknown option '$arg'" >&2
      echo "usage: $(basename "$0") [--deep] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

FAILURES=0

remove() {
  local target="$1"
  if [ -e "$target" ]; then
    local size
    size=$(du -sh "$target" 2>/dev/null | cut -f1)
    size="${size:-unknown}"
    if $DRY_RUN; then
      echo "  [dry-run] would remove $target ($size)"
    else
      if rm -rf "$target" 2>/dev/null; then
        echo "  removed $target ($size)"
      else
        echo "  warning: failed to remove $target" >&2
        FAILURES=$((FAILURES + 1))
      fi
    fi
  fi
}

echo "== iOS/Xcode/CocoaPods machine-wide cache cleanup =="
df_before=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_before="${df_before:-unknown}"

echo
echo "-- Xcode caches --"
remove "$HOME/Library/Developer/Xcode/DerivedData"

echo
echo "-- CocoaPods / Swift Package Manager caches --"
remove "$HOME/Library/Caches/CocoaPods"
remove "$HOME/Library/Caches/org.swift.swiftpm"
remove "$HOME/Library/org.swift.swiftpm"

echo
echo "-- Simulator cleanup --"
if command -v xcrun >/dev/null 2>&1; then
  if $DRY_RUN; then
    echo "  [dry-run] would run: xcrun simctl delete unavailable"
  else
    if xcrun simctl delete unavailable 2>/dev/null; then
      echo "  removed unavailable/orphaned simulator devices"
    else
      echo "  warning: failed to prune simulator devices" >&2
      FAILURES=$((FAILURES + 1))
    fi
  fi
  if $DEEP; then
    remove "$HOME/Library/Developer/CoreSimulator/Caches"
  fi
else
  echo "  skipping: xcrun not found"
fi

echo
df_after=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_after="${df_after:-unknown}"
echo "== Done =="
echo "Free space before: $df_before  ->  after: $df_after"
if ! $DRY_RUN; then
  echo "Next time you open a project, Xcode will re-index and CocoaPods/SwiftPM will re-install fresh."
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "Completed with $FAILURES failure(s); see warnings above." >&2
  exit 1
fi
