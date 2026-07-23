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

DEEP=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=true ;;
    --dry-run) DRY_RUN=true ;;
  esac
done

remove() {
  local target="$1"
  if [ -e "$target" ]; then
    local size
    size=$(du -sh "$target" 2>/dev/null | cut -f1)
    if $DRY_RUN; then
      echo "  [dry-run] would remove $target ($size)"
    else
      echo "  removing $target ($size)"
      rm -rf "$target"
    fi
  fi
}

echo "== Android/Gradle machine-wide cache cleanup =="
df_before=$(df -h / | awk 'NR==2{print $4}')

echo
echo "-- Stopping any running Gradle daemons --"
pkill -f GradleDaemon 2>/dev/null || true

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
df_after=$(df -h / | awk 'NR==2{print $4}')
echo "== Done =="
echo "Free space before: $df_before  ->  after: $df_after"
if ! $DRY_RUN; then
  echo "Next time you open a project, Gradle/Android Studio will re-sync and re-download deps fresh."
fi
