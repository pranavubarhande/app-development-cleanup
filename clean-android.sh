#!/usr/bin/env bash
# Frees up macOS disk space by clearing Android/Gradle toolchain caches
# machine-wide - NOT project files. Nothing here touches any project's
# source, build/, or .gradle folder. Everything removed here is
# downloadable/regeneratable: next time you open a project, Gradle Sync
# and Android Studio will fetch/rebuild whatever they need fresh.
#
# Usage:
#   clean-android.sh            # clean
#   clean-android.sh --deep     # also wipe the Gradle wrapper distribution
#                                # cache (forces re-download of Gradle
#                                # itself on next build - slower first run)
#   clean-android.sh --dry-run  # show what would be removed, remove nothing

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

echo "== Android/Gradle machine-wide cache cleanup =="
df_before=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_before="${df_before:-unknown}"

echo
echo "-- Stopping any running Gradle daemons --"
if $DRY_RUN; then
  echo "  [dry-run] would stop any running Gradle daemons"
elif command -v pkill >/dev/null 2>&1; then
  pkill -f GradleDaemon 2>/dev/null || true
else
  echo "  skipping: pkill not found"
fi

echo
echo "-- Global Gradle caches --"
remove "$HOME/.gradle/caches"
remove "$HOME/.gradle/daemon"
remove "$HOME/.gradle/notifications"
if $DEEP; then
  remove "$HOME/.gradle/wrapper/dists"
fi

echo
echo "-- Android Studio caches --"
for d in "$HOME"/Library/Caches/Google/AndroidStudio*; do
  remove "$d"
done
for d in "$HOME"/Library/Logs/Google/AndroidStudio*; do
  remove "$d"
done

echo
echo "-- Android build/emulator caches --"
remove "$HOME/.android/cache"
remove "$HOME/.android/build-cache"

echo
df_after=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_after="${df_after:-unknown}"
echo "== Done =="
echo "Free space before: $df_before  ->  after: $df_after"
if ! $DRY_RUN; then
  echo "Next time you open a project, Gradle/Android Studio will re-sync and re-download deps fresh."
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "Completed with $FAILURES failure(s); see warnings above." >&2
  exit 1
fi
