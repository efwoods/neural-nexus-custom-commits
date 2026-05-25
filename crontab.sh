#!/usr/bin/env bash
#
# crontab.sh
# ----------
# Idempotently installs (or refreshes) the cron entry that runs
# hourly_progress_all.sh at minute :20 and :50 of every hour. Safe to re-run:
# it strips any previous hourly_progress entry before adding the current one, so
# your other crontab lines are preserved.
#
# Normally invoked by `./install.sh --setup`. Run it standalone to repair or
# reinstall just the cron entry.

set -euo pipefail

WRAPPER="$HOME/.local/bin/hourly_progress_all.sh"
LOG_DIR="$HOME/.local/state/hourly_progress"
CRON_LINE="20,50 * * * * $WRAPPER >> $LOG_DIR/cron.log 2>&1"
MARKER="# hourly_progress: runs ./hourly_progress.py -c -a \$AVATAR_ID in every worktree (config: ~/.config/hourly_progress.env)"

mkdir -p "$LOG_DIR"

if [ ! -x "$WRAPPER" ]; then
  echo "ERROR: wrapper not found or not executable: $WRAPPER" >&2
  echo "Run ./install.sh --setup first." >&2
  exit 1
fi

# Keep the user's other entries, drop any prior hourly_progress lines, append ours.
current="$(crontab -l 2>/dev/null || true)"
filtered="$(printf '%s\n' "$current" | grep -v -F 'hourly_progress' || true)"

{
  printf '%s\n' "$filtered" | sed '/^[[:space:]]*$/d'
  printf '%s\n' "$MARKER"
  printf '%s\n' "$CRON_LINE"
} | crontab -

echo "Installed cron entry:"
echo "  $CRON_LINE"
