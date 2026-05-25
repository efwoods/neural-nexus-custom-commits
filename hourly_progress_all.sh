#!/usr/bin/env bash
#
# hourly_progress_all.sh
# ----------------------
# Runs `./hourly_progress.py -c -a "$AVATAR_ID"` inside EVERY git worktree under
# $WT_ROOT that contains the script. New worktrees are picked up automatically and
# removed ones simply disappear from the loop — no edits needed as worktrees come
# and go.
#
# Invoked by cron at minutes :20 and :50 of every hour. Cron runs with a minimal
# environment, so this script sets PATH/HOME explicitly and sources its config
# (AVATAR_ID, NN_API_KEY, WT_ROOT) from ~/.config/hourly_progress.env instead of
# relying on the interactive shell.

set -u

export HOME="${HOME:-/home/user}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin"

# hourly_progress.py declares its deps via PEP 723 inline metadata, so we run it
# with `uv run --script`: uv resolves/caches httpx + python-dotenv into an
# isolated env per script, ignoring any pyproject.toml in the worktree. No
# per-worktree venv and no system-pip install (which PEP 668 blocks) is needed.

ENV_FILE="$HOME/.config/hourly_progress.env"
LOG_DIR="$HOME/.local/state/hourly_progress"
LOG_FILE="$LOG_DIR/run.log"

mkdir -p "$LOG_DIR"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"; }

# --- config / credentials --------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  log "FATAL: config file not found: $ENV_FILE (run ./install.sh --setup)"
  exit 1
fi
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

if [ -z "${AVATAR_ID:-}" ] || [ -z "${NN_API_KEY:-}" ] || [ -z "${WT_ROOT:-}" ]; then
  log "FATAL: AVATAR_ID, NN_API_KEY, and/or WT_ROOT are empty in $ENV_FILE — fill them in."
  exit 1
fi
export NN_API_KEY  # hourly_progress.py reads the key from the environment

if ! command -v uv >/dev/null 2>&1; then
  log "FATAL: uv not found on PATH ($PATH). Install uv (https://docs.astral.sh/uv/) — the script runs via 'uv run --script'."
  exit 1
fi

if [ ! -d "$WT_ROOT" ]; then
  log "FATAL: WT_ROOT does not exist: $WT_ROOT"
  exit 1
fi

# --- run every worktree ----------------------------------------------------
log "=== run start (root=$WT_ROOT) ==="
ran=0; ok=0; fail=0
for d in "$WT_ROOT"/*/; do
  [ -f "${d}hourly_progress.py" ] || continue   # skip worktrees without the script
  name="$(basename "$d")"

  ran=$((ran + 1))
  log "[$name] running: uv run --script ./hourly_progress.py -c -a <AVATAR_ID>"
  if ( cd "$d" && uv run --script ./hourly_progress.py -c -a "$AVATAR_ID" ) >>"$LOG_FILE" 2>&1; then
    log "[$name] OK"
    ok=$((ok + 1))
  else
    rc=$?
    log "[$name] FAILED (exit $rc)"
    fail=$((fail + 1))
  fi
done
log "=== run done: ran=$ran ok=$ok fail=$fail ==="
