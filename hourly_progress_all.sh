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
# Two logs, split strictly by role:
#   LOG_FILE — the day's worktree updates ONLY. This is the file uploaded to the
#              avatar, so it must stay free of operational noise and errors.
#   ERR_FILE — everything operational: run markers, per-worktree OK/FAILED,
#              FATAL/WARN, and any uv/Python/curl stderr. Never uploaded.
LOG_FILE="$LOG_DIR/run_$(date '+%Y-%m-%d').log"
ERR_FILE="$LOG_DIR/err.log"

mkdir -p "$LOG_DIR"

# log() is for operational/diagnostic lines only -> ERR_FILE. Worktree updates go
# to LOG_FILE separately (see the run loop), never through log().
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$ERR_FILE"; }

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
# Each worktree's script prints ONLY the avatar's update to stdout; its
# diagnostics (temp-file path, "Reviewing…", git commit/push output) and any
# tracebacks go to stderr. So we split the streams: stdout -> the day's update
# feed (LOG_FILE, later uploaded), stderr -> ERR_FILE. stdout is captured to a
# temp first and appended under a worktree header only on a successful, non-empty
# run, so a failed or empty run never leaves a dangling entry in the upload.
log "=== run start (root=$WT_ROOT) ==="
ran=0; ok=0; fail=0
for d in "$WT_ROOT"/*/; do
  [ -f "${d}hourly_progress.py" ] || continue   # skip worktrees without the script
  name="$(basename "$d")"

  ran=$((ran + 1))
  log "[$name] running: uv run --script ./hourly_progress.py -c -a <AVATAR_ID>"
  update="$(mktemp)"
  if ( cd "$d" && uv run --script ./hourly_progress.py -c -a "$AVATAR_ID" ) >"$update" 2>>"$ERR_FILE"; then
    log "[$name] OK"
    ok=$((ok + 1))
    if [ -s "$update" ]; then
      { printf '\n----- %s | %s -----\n' "$name" "$(date '+%Y-%m-%d %H:%M:%S')"
        cat "$update"
        printf '\n'; } >>"$LOG_FILE"
    fi
  else
    rc=$?
    log "[$name] FAILED (exit $rc)"
    fail=$((fail + 1))
    # Keep any partial stdout out of the uploaded feed, but record it for debugging.
    [ -s "$update" ] && { printf '%s [%s] stdout on failure:\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$name"; cat "$update"; } >>"$ERR_FILE"
  fi
  rm -f "$update"
done
log "=== run done: ran=$ran ok=$ok fail=$fail ==="

# --- upload today's log to the avatar --------------------------------------
# Now that every worktree's update has been appended to today's dated log, push
# the whole file to the avatar's identity media so it can learn from the day's
# progress. Uses curl's multipart (-F): curl sets Content-Type with the required
# boundary, so we must NOT set that header by hand.
upload_log_to_avatar() {
  if ! command -v curl >/dev/null 2>&1; then
    log "WARN: curl not found on PATH ($PATH); skipping log upload to avatar."
    return
  fi
  [ -f "$LOG_FILE" ] || { log "WARN: $LOG_FILE missing; nothing to upload."; return; }

  local body code
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' \
    -X POST "https://api.neuralnexus.site/update_avatar_identity_with_media" \
    -H "Accept: application/json" \
    -H "API-KEY: $NN_API_KEY" \
    -F "files=@${LOG_FILE};type=text/plain" \
    -F "url=" \
    -F "assistant_id=$AVATAR_ID" \
    -F "reference_audio=false" \
    -F "reference_image=false" 2>>"$ERR_FILE")" || true

  if [ "$code" = "200" ]; then
    log "uploaded $LOG_FILE to avatar identity media (HTTP $code)"
  else
    log "FAILED to upload $LOG_FILE to avatar (HTTP ${code:-000}): $(head -c 500 "$body" 2>/dev/null)"
  fi
  rm -f "$body"
}

upload_log_to_avatar
