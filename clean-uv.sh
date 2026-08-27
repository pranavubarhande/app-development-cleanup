#!/usr/bin/env bash
# Frees up disk space by clearing uv's package/build cache for Python
# projects - NOT project files. Nothing here touches any project's
# source, .venv/, or lockfiles. Everything removed here is
# downloadable/regeneratable: next time you run `uv sync`/`uv pip install`,
# uv will re-download and re-build whatever it needs fresh.
#
# Usage:
#   clean-uv.sh            # clean
#   clean-uv.sh --dry-run  # show what would be removed, remove nothing

set -uo pipefail

if [ -z "${HOME:-}" ]; then
  echo "error: \$HOME is not set, cannot locate caches" >&2
  exit 1
fi

DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *)
      echo "error: unknown option '$arg'" >&2
      echo "usage: $(basename "$0") [--dry-run]" >&2
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

echo "== uv (Python package manager) cache cleanup =="
df_before=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_before="${df_before:-unknown}"

echo
echo "-- uv cache --"
if command -v uv >/dev/null 2>&1; then
  cache_dir=$(uv cache dir 2>/dev/null)
  if [ -n "$cache_dir" ] && [ -e "$cache_dir" ]; then
    size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    size="${size:-unknown}"
    echo "  cache location: $cache_dir ($size)"
  fi
  if $DRY_RUN; then
    echo "  [dry-run] would run: uv cache clean"
  else
    if uv cache clean 2>/dev/null; then
      echo "  cache cleared via 'uv cache clean'"
    else
      echo "  warning: 'uv cache clean' failed, falling back to manual removal" >&2
      FAILURES=$((FAILURES + 1))
      if [ -n "$cache_dir" ]; then
        remove "$cache_dir"
      fi
    fi
  fi
else
  echo "  uv not found on PATH, falling back to manual removal of default cache locations"
  remove "${UV_CACHE_DIR:-}"
  remove "${XDG_CACHE_HOME:-$HOME/.cache}/uv"
  remove "$HOME/Library/Caches/uv"
fi

echo
df_after=$(df -h / 2>/dev/null | awk 'NR==2{print $4}')
df_after="${df_after:-unknown}"
echo "== Done =="
echo "Free space before: $df_before  ->  after: $df_after"
if ! $DRY_RUN; then
  echo "Next time you run uv, it will re-download/re-build whatever it needs fresh."
fi

if [ "$FAILURES" -gt 0 ]; then
  echo "Completed with $FAILURES failure(s); see warnings above." >&2
  exit 1
fi
