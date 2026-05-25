#!/usr/bin/env bash
#
# install.sh — set up the Neural Nexus hourly-progress automation.
#
# Keep this checkout around after installing; --worktree copies from it.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config"
STATE_DIR="$HOME/.local/state/hourly_progress"
ENV_FILE="$CONFIG_DIR/hourly_progress.env"

ENV_EXAMPLE="$SRC_DIR/hourly_progress.env.example"
WRAPPER_SRC="$SRC_DIR/hourly_progress_all.sh"
WRAPPER_DST="$BIN_DIR/hourly_progress_all.sh"
SCRIPT_SRC="$SRC_DIR/hourly_progress.py"

err() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
install.sh — Neural Nexus hourly-progress automation

Usage:
  ./install.sh --setup              Initial, machine-wide setup. Installs the cron
                                    wrapper, creates the credentials file, and
                                    installs the cron job (:20 and :50 every hour).
                                    Run this ONCE per machine.

  ./install.sh --worktree [DIR]     Drop hourly_progress.py into a single worktree
                                    (default: current directory) so the cron job
                                    processes the dit diffs for the worktree. Run once per worktree.

  ./install.sh --worktree --all     Drop hourly_progress.py into every git worktree
                                    under WT_ROOT (read from $ENV_FILE).

  ./install.sh --help               Show this help.

See README.md for the full walkthrough.
EOF
}

# Copy hourly_progress.py into one worktree directory.
install_worktree() {
  local target="${1:-$PWD}"
  [ -f "$SCRIPT_SRC" ] || err "cannot find hourly_progress.py next to install.sh ($SRC_DIR)"
  target="$(cd "$target" 2>/dev/null && pwd)" || err "target directory does not exist: ${1:-$PWD}"

  if [ "$target" = "$SRC_DIR" ]; then
    err "refusing to install into the source checkout. cd into a worktree first, e.g.:
  cd /path/to/your/worktree && $SRC_DIR/install.sh --worktree"
  fi

  if ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'WARNING: %s is not a git repository/worktree; installing anyway.\n' "$target" >&2
  fi

  cp "$SCRIPT_SRC" "$target/hourly_progress.py"
  chmod +x "$target/hourly_progress.py" 2>/dev/null || true
  printf 'Installed hourly_progress.py -> %s/hourly_progress.py\n' "$target"
}

# Copy hourly_progress.py into every git worktree under WT_ROOT.
install_worktree_all() {
  [ -f "$ENV_FILE" ] || err "no config file ($ENV_FILE); run: $0 --setup"
  [ -f "$SCRIPT_SRC" ] || err "cannot find hourly_progress.py next to install.sh ($SRC_DIR)"
  local wt_root
  # shellcheck source=/dev/null
  wt_root="$(. "$ENV_FILE"; printf '%s' "${WT_ROOT:-}")"
  [ -n "$wt_root" ] || err "WT_ROOT is not set in $ENV_FILE"
  [ -d "$wt_root" ] || err "WT_ROOT does not exist: $wt_root"

  local count=0 d
  for d in "$wt_root"/*/; do
    [ -d "$d" ] || continue
    if git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
      cp "$SCRIPT_SRC" "${d}hourly_progress.py"
      chmod +x "${d}hourly_progress.py" 2>/dev/null || true
      printf 'Installed -> %shourly_progress.py\n' "$d"
      count=$((count + 1))
    else
      printf 'Skipped (not a git worktree): %s\n' "$d"
    fi
  done
  printf 'Done. Installed into %d worktree(s) under %s.\n' "$count" "$wt_root"
}

# Machine-wide initial setup: wrapper + credentials file + cron entry.
install_setup() {
  [ -f "$WRAPPER_SRC" ] || err "cannot find hourly_progress_all.sh next to install.sh"
  [ -f "$ENV_EXAMPLE" ] || err "cannot find hourly_progress.env.example next to install.sh"

  mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$STATE_DIR"

  # 1) cron wrapper
  cp "$WRAPPER_SRC" "$WRAPPER_DST"
  chmod 755 "$WRAPPER_DST"
  printf 'Installed cron wrapper -> %s\n' "$WRAPPER_DST"

  # 2) credentials file (never clobber an existing one)
  if [ -f "$ENV_FILE" ]; then
    printf 'Kept existing config file -> %s\n' "$ENV_FILE"
  else
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    printf 'Created config file -> %s (chmod 600)\n' "$ENV_FILE"
  fi

  # 3) cron entry
  bash "$SRC_DIR/crontab.sh"

  cat <<EOF

Setup complete. Next steps:

  1. Create your avatar
     Sign up at https://api.neuralnexus.site for an API KEY, create an Avatar (/create), and copy its
     assistant id (that is your AVATAR_ID). There is an example description in this repository for the avatar.

  2. Fill in your config
     Edit $ENV_FILE and set:
       AVATAR_ID   — the avatar's assistant id from step 1
       NN_API_KEY  — your Neural Nexus API key
       WT_ROOT     — the folder that holds all your worktrees
                     (e.g. /home/user/gh/anubis-project/wt)

  3. Install the script into your worktrees
       ./install.sh --worktree --all        (all worktrees under WT_ROOT)
     or, per worktree:
       cd <worktree> && $SRC_DIR/install.sh --worktree

  The cron job runs at :20 and :50 every hour and posts each worktree's progress
  to your avatar. Logs: $STATE_DIR/run.log (and cron.log).

  Test a run now (after steps 1-3):
    $WRAPPER_DST && tail -n 40 $STATE_DIR/run.log
EOF
}

main() {
  [ $# -ge 1 ] || { usage; exit 1; }
  case "$1" in
    -s|--setup)    install_setup ;;
    -w|--worktree)
      shift
      if [ "${1:-}" = "--all" ] || [ "${1:-}" = "-a" ]; then
        install_worktree_all
      else
        install_worktree "${1:-$PWD}"
      fi
      ;;
    -h|--help)     usage ;;
    *) err "unknown option: $1 (use --setup, --worktree [DIR|--all], or --help)" ;;
  esac
}

main "$@"
