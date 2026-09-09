#!/usr/bin/env bash
# Frees up disk space by clearing uv's (the Python package/project tool)
# caches machine-wide - NOT project files. Nothing here touches any
# project's source, .venv, or lockfiles. Everything removed here is
# downloadable/regeneratable: next time you run uv, it will re-download
# and re-build whatever it needs fresh.
#
# Usage:
#   clean-uv.sh            # clean the uv cache (wheels, sdists, builds, etc.)
#   clean-uv.sh --deep     # also wipe uv-managed Python interpreters
#                           # (forces re-download of those Python versions
#                           # on next `uv python install` / `uv run`)
#   clean-uv.sh --dry-run  # show what would be removed, remove nothing

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

echo "== uv (Python) machine-wide cache cleanup =="
df_before=$(df -h / | awk 'NR==2{print $4}')

echo
echo "-- uv cache --"
UV_CACHE_DIR=""
if command -v uv >/dev/null 2>&1; then
  UV_CACHE_DIR=$(uv cache dir 2>/dev/null || true)
fi
if [ -z "$UV_CACHE_DIR" ]; then
  # Fall back to uv's documented default locations if the `uv` CLI
  # isn't on PATH or `uv cache dir` failed.
  if [ -n "${XDG_CACHE_HOME:-}" ] && [ -d "$XDG_CACHE_HOME/uv" ]; then
    UV_CACHE_DIR="$XDG_CACHE_HOME/uv"
  elif [ -d "$HOME/.cache/uv" ]; then
    UV_CACHE_DIR="$HOME/.cache/uv"
  elif [ -d "$HOME/Library/Caches/uv" ]; then
    UV_CACHE_DIR="$HOME/Library/Caches/uv"
  else
    UV_CACHE_DIR="$HOME/.cache/uv"
  fi
fi

if command -v uv >/dev/null 2>&1; then
  if $DRY_RUN; then
    echo "  [dry-run] would run: uv cache clean"
  else
    uv cache clean 2>/dev/null || remove "$UV_CACHE_DIR"
    echo "  cleaned uv cache ($UV_CACHE_DIR)"
  fi
else
  remove "$UV_CACHE_DIR"
fi

if $DEEP; then
  echo
  echo "-- uv-managed Python interpreters --"
  UV_PYTHON_DIR="${UV_PYTHON_INSTALL_DIR:-}"
  if [ -z "$UV_PYTHON_DIR" ]; then
    if [ -n "${XDG_DATA_HOME:-}" ]; then
      UV_PYTHON_DIR="$XDG_DATA_HOME/uv/python"
    else
      UV_PYTHON_DIR="$HOME/.local/share/uv/python"
    fi
  fi
  remove "$UV_PYTHON_DIR"
fi

echo
df_after=$(df -h / | awk 'NR==2{print $4}')
echo "== Done =="
echo "Free space before: $df_before  ->  after: $df_after"
if ! $DRY_RUN; then
  echo "Next time you run uv, it will re-download/re-build whatever it needs fresh."
fi
