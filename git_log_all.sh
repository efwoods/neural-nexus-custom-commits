#!/usr/bin/env bash
#
# git_log_all.sh
# --------------
# Collects RAW `git log` output (never summarized) for the test/dev/main branches
# of every git repository found under $GIT_LOG_ROOT and appends it — labeled by
# repository and branch — to the day's log (run_YYYY-MM-DD.log). That dated log is
# the single file uploaded to the avatar, so this lets the avatar index the actual
# committed changes across every repo alongside the per-worktree narrated progress.
#
# It plays two roles:
#   * cron — hourly_progress_all.sh calls this at :20 and :50 with the default
#     window (--since "30 minutes ago") and --no-upload, so the git logs ride along
#     in the single daily upload the wrapper already performs.
#   * manual / query — run it directly with ANY `date -d` expression, e.g.
#         ./git_log_all.sh --since "1 minute ago"
#         ./git_log_all.sh --since "1 hour ago"
#         ./git_log_all.sh --since "1 week ago"
#     A manual run appends to the day's log and, by default, uploads it to the
#     avatar so the period is immediately queryable.
#
# Config (AVATAR_ID, NN_API_KEY, optional GIT_LOG_ROOT) is read from
# ~/.config/hourly_progress.env — the same file the cron wrapper uses. GIT_LOG_ROOT
# defaults to the parent of WT_ROOT, falling back to /home/user/gh/anubis-project.

set -u

# Cron has a minimal environment; set PATH/HOME ourselves so git/curl/date resolve
# whether we're invoked by cron, by the wrapper, or interactively.
export HOME="${HOME:-/home/user}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin"

ENV_FILE="$HOME/.config/hourly_progress.env"
LOG_DIR="$HOME/.local/state/hourly_progress"
LOG_FILE="$LOG_DIR/run_$(date '+%Y-%m-%d').log"  # the dated log; the file uploaded to the avatar
ERR_FILE="$LOG_DIR/err.log"                       # operational lines + errors; never uploaded

SINCE="30 minutes ago"   # default window; matches the :20/:50 cron cadence (no gaps, no overlap)
DO_UPLOAD=1              # manual runs upload by default; the cron wrapper passes --no-upload
ROOT_OVERRIDE=""
BRANCHES=(test dev main)
LARGEST_WINDOW="1 week ago"  # "largest acceptable input": unparseable --since maps here
MIN_SECONDS=60               # floor: the window is never narrower than 1 minute

usage() {
  cat <<'EOF'
Usage: git_log_all.sh [--since "<date -d expr>"] [--root DIR] [--no-upload]

Appends raw `git log` to today's run_YYYY-MM-DD.log — test/dev/main for each
top-level repo under the project root, the same for each registered submodule of
those repos, and each linked worktree on its own checked-out branch — then uploads
that log to the avatar. Stray nested clones that are NOT registered submodules
(e.g. data/elon-musk-dataset) are intentionally not treated as repos.

  --since EXPR   Window start as any `date -d` expression. The default time frame is "30 minutes ago".
                 Examples: "1 minute ago" "30 minutes ago" "1 hour ago" "1 day ago" "1 week ago".
                 Input is never under-shot: a valid expression is used as-is; an
                 invalid but numeric one is rounded UP to a whole unit (e.g.
                 "59.5 minutes ago" -> "60 minutes ago", "1.5 hours ago" -> "2 hours ago");
                 unparseable input maps to the largest window ("1 week ago"); and any
                 window under 1 minute is floored to "1 minute ago".
  --root DIR     Directory to scan for git repos. Default: $GIT_LOG_ROOT, else the
                 parent of WT_ROOT, else /home/user/gh/anubis-project.
  --no-upload    Append to today's log but do NOT upload it (used by the cron wrapper,
                 which performs a single combined upload itself).
  -h, --help     Show this help and exit.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --since)     SINCE="${2:?--since needs a value}"; shift 2 ;;
    --since=*)   SINCE="${1#*=}"; shift ;;
    --root)      ROOT_OVERRIDE="${2:?--root needs a value}"; shift 2 ;;
    --root=*)    ROOT_OVERRIDE="${1#*=}"; shift ;;
    --no-upload) DO_UPLOAD=0; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) printf 'git_log_all: unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

mkdir -p "$LOG_DIR"
# log() is for operational/diagnostic lines only -> ERR_FILE. The collected git
# logs go to LOG_FILE directly (see below), never through log().
log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$ERR_FILE"; }
# notice() is for things the caller should see: it goes to stderr (visible on a
# manual run; captured to ERR_FILE when the cron wrapper redirects our stderr).
notice() { printf 'git_log_all: %s\n' "$*" >&2; }

# normalize_since: turn a --since value into an expression `date -d` accepts, never
# under-shooting the requested window:
#   * a valid date -d expression is used unchanged ("2 days ago" stays 2 days);
#   * an invalid but numeric one has its number rounded UP to a whole unit, so
#     "59.5 minutes ago" -> "60 minutes ago" and "1.5 hours ago" -> "2 hours ago";
#   * anything unparseable maps to the largest window ($LARGEST_WINDOW).
# The 1-minute floor is applied later, against the resolved timestamp. Echoes the
# normalized expression on stdout.
normalize_since() {
  local raw="$1" num unit n candidate
  # 1) already a valid date -d expression -> use as-is.
  if date -d "$raw" >/dev/null 2>&1; then
    printf '%s' "$raw"
    return 0
  fi
  # 2) recover: pull a leading (possibly fractional) number + unit out of the text
  #    and round the number UP to the next whole unit.
  if [[ "$raw" =~ ([0-9]+([.][0-9]+)?)[[:space:]]*(sec|secs|second|seconds|min|mins|minute|minutes|hour|hours|hr|hrs|day|days|week|weeks|month|months|year|years) ]]; then
    num="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[3]}"
    n="$(awk -v x="$num" 'BEGIN { printf("%d", (x == int(x)) ? x : int(x) + 1) }')"
    [ "${n:-0}" -lt 1 ] && n=1
    case "$unit" in
      sec|secs|second|seconds) unit=seconds ;;
      min|mins|minute|minutes) unit=minutes ;;
      hr|hrs|hour|hours)       unit=hours ;;
      day|days)                unit=days ;;
      week|weeks)              unit=weeks ;;
      month|months)            unit=months ;;
      year|years)              unit=years ;;
    esac
    candidate="$n $unit ago"
    if date -d "$candidate" >/dev/null 2>&1; then
      notice "rounded invalid --since '$raw' up to '$candidate'"
      printf '%s' "$candidate"
      return 0
    fi
  fi
  # 3) unparseable -> the largest acceptable window.
  notice "unparseable --since '$raw'; using largest window '$LARGEST_WINDOW'"
  printf '%s' "$LARGEST_WINDOW"
}

# --- config / credentials --------------------------------------------------
# Sourcing is best-effort: collection works without credentials (only the upload
# needs them), so a missing env file is a warning, not fatal, unless we must upload.
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ENV_FILE"
  set +a
else
  log "WARN: config file not found: $ENV_FILE (collection continues; upload will be skipped)"
fi

# Resolve the scan root: --root > GIT_LOG_ROOT > parent of WT_ROOT > default.
ROOT="${ROOT_OVERRIDE:-${GIT_LOG_ROOT:-}}"
if [ -z "$ROOT" ]; then
  if [ -n "${WT_ROOT:-}" ]; then ROOT="$(dirname "$WT_ROOT")"; else ROOT="/home/user/gh/anubis-project"; fi
fi
if [ ! -d "$ROOT" ]; then
  log "FATAL: git-log root does not exist: $ROOT"
  printf 'git_log_all: root not found: %s\n' "$ROOT" >&2
  exit 1
fi

# Normalize the window: valid date -d expressions pass through; invalid-but-numeric
# input is rounded UP to a whole unit; unparseable input maps to the largest window.
# Then resolve to an absolute timestamp.
SINCE="$(normalize_since "$SINCE")"
SINCE_TS="$(date -d "$SINCE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" || {
  # normalize_since only ever returns a date -d-valid expression, so reaching here
  # means the environment's `date` itself failed — a real, unexpected error.
  log "FATAL: could not resolve --since after normalization: '$SINCE'"
  printf "git_log_all: could not resolve --since '%s'\n" "$SINCE" >&2
  exit 2
}

# Floor the window at the 1-minute minimum (also catches "now"/sub-minute/future
# inputs that resolve to a zero or negative span).
now_epoch="$(date '+%s')"
since_epoch="$(date -d "$SINCE_TS" '+%s' 2>/dev/null || printf '%s' "$now_epoch")"
if [ "$((now_epoch - since_epoch))" -lt "$MIN_SECONDS" ]; then
  notice "--since '$SINCE' is under the 1-minute minimum; using '1 minute ago'"
  SINCE="1 minute ago"
  SINCE_TS="$(date -d "$SINCE" '+%Y-%m-%d %H:%M:%S')"
fi

# Append a `git log` block for one ref to the dated log (raw, never summarized).
log_range() {  # $1 = dir to run git in   $2 = ref/branch/sha
  local out
  out="$(git -C "$1" log "$2" --since="$SINCE_TS" --date=iso-strict --stat --no-color 2>>"$ERR_FILE")"
  if [ -n "$out" ]; then printf '%s\n' "$out"; else printf '(no commits since %s)\n' "$SINCE_TS"; fi
}

# --- discover repositories and their worktrees -----------------------------
# We log two kinds of thing, differently, and deliberately do NOT recurse the
# filesystem — so nested clones or submodules sitting inside a repo's working tree
# (e.g. data/elon-musk-dataset, a frontend submodule) are never treated as repos:
#   * MAIN repo = an immediate child of ROOT whose own .git is a real directory
#                 (its primary worktree). Logged for the test/dev/main branches.
#   * WORKTREE  = a linked worktree (`git worktree add`) of a main repo, found via
#                 `git worktree list`. Logged SEPARATELY and ONLY for the single
#                 branch it has checked out — not test/dev/main. Logging is driven
#                 from the parent repo's shared object store, so a broken/stale
#                 worktree directory (unregistered ones never appear here anyway)
#                 cannot break collection.
main_repos=()
for child in "$ROOT"/*/; do
  child="${child%/}"
  [ -d "$child" ] || continue
  top="$(git -C "$child" rev-parse --show-toplevel 2>/dev/null)" || continue
  [ "$top" = "$child" ] || continue          # skip linked worktrees / dirs resolving to an ancestor
  [ -d "$child/.git" ] || continue           # a primary worktree has a real .git directory
  main_repos+=("$child")
done

# --- collect -> append raw git logs to today's dated log -------------------
{
  printf '\n========== GIT LOG | since: %s (%s) | generated %s | root: %s ==========\n' \
    "$SINCE" "$SINCE_TS" "$(date '+%Y-%m-%d %H:%M:%S')" "$ROOT"
} >>"$LOG_FILE"

repos=0
submods=0
worktrees=0
branches_logged=0
for repo in "${main_repos[@]}"; do
  name="$(basename "$repo")"
  origin="$(git -C "$repo" config --get remote.origin.url 2>/dev/null || true)"
  repos=$((repos + 1))

  # MAIN repo -> test/dev/main (local branch, else its remote-tracking ref).
  { printf '\n##### repo: %s | origin: %s | %s #####\n' "$name" "${origin:-<none>}" "$repo"; } >>"$LOG_FILE"
  for b in "${BRANCHES[@]}"; do
    if git -C "$repo" rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1; then
      ref="$b"
    elif git -C "$repo" rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null 2>&1; then
      ref="origin/$b"
    else
      continue
    fi
    branches_logged=$((branches_logged + 1))
    { printf '\n----- branch: %s (%s) -----\n' "$b" "$ref"; log_range "$repo" "$ref"; } >>"$LOG_FILE"
  done

  # Its registered submodules -> each its own entry, also test/dev/main. Driven by
  # `git submodule foreach --recursive`, which only iterates submodules actually
  # registered in .gitmodules and currently initialized — so a stray nested clone
  # like data/elon-musk-dataset (NOT a registered submodule) is never picked up.
  # shellcheck disable=SC2016  # $sm_path is expanded by `git submodule foreach`, not by our shell
  while IFS= read -r sm_path; do
    [ -n "$sm_path" ] || continue
    sm_dir="$repo/$sm_path"
    sm_top="$(git -C "$sm_dir" rev-parse --show-toplevel 2>/dev/null)" || continue
    [ -n "$sm_top" ] || continue
    sm_name="$(basename "$sm_path")"
    sm_origin="$(git -C "$sm_dir" config --get remote.origin.url 2>/dev/null || true)"
    submods=$((submods + 1))
    { printf '\n##### submodule: %s | parent: %s | path: %s | origin: %s | %s #####\n' \
        "$sm_name" "$name" "$sm_path" "${sm_origin:-<none>}" "$sm_dir"; } >>"$LOG_FILE"
    for b in "${BRANCHES[@]}"; do
      if git -C "$sm_dir" rev-parse --verify --quiet "refs/heads/$b" >/dev/null 2>&1; then
        ref="$b"
      elif git -C "$sm_dir" rev-parse --verify --quiet "refs/remotes/origin/$b" >/dev/null 2>&1; then
        ref="origin/$b"
      else
        continue
      fi
      branches_logged=$((branches_logged + 1))
      { printf '\n----- branch: %s (%s) -----\n' "$b" "$ref"; log_range "$sm_dir" "$ref"; } >>"$LOG_FILE"
    done
  done < <(git -C "$repo" submodule foreach --recursive --quiet 'printf "%s\n" "$sm_path"' 2>>"$ERR_FILE")

  # Its linked worktrees -> each its own entry, ONLY its checked-out branch.
  wt_path=""; wt_head=""; wt_branch=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) wt_path="${line#worktree }" ;;
      "HEAD "*)     wt_head="${line#HEAD }" ;;
      "branch "*)   wt_branch="${line#branch refs/heads/}" ;;
      "detached")   wt_branch="" ;;
      "")  # end of a porcelain block — emit if it's a linked worktree under ROOT
        if [ -n "$wt_path" ] && [ "$wt_path" != "$repo" ]; then
          case "$wt_path/" in
            "$ROOT"/*)
              wt_ref="${wt_branch:-$wt_head}"
              wt_label="${wt_branch:-(detached) $wt_head}"
              worktrees=$((worktrees + 1))
              branches_logged=$((branches_logged + 1))
              { printf '\n##### worktree: %s | parent: %s | %s #####\n' "$(basename "$wt_path")" "$name" "$wt_path"
                printf '\n----- branch: %s -----\n' "$wt_label"
                log_range "$repo" "$wt_ref"; } >>"$LOG_FILE"
              ;;
          esac
        fi
        wt_path=""; wt_head=""; wt_branch="" ;;
    esac
  done < <(git -C "$repo" worktree list --porcelain 2>>"$ERR_FILE"; printf '\n')
done

log "git_log_all: appended $repos repo(s) + $submods submodule(s) + $worktrees worktree(s), $branches_logged branch(es), since '$SINCE' ($SINCE_TS), root=$ROOT"

# --- upload today's log to the avatar --------------------------------------
# Same mechanism as the cron wrapper. curl sets the multipart Content-Type (with
# the boundary) itself, so we must NOT set that header by hand. Failures are logged,
# not fatal — the log is already written locally.
upload_log_to_avatar() {
  if ! command -v curl >/dev/null 2>&1; then
    log "WARN: curl not found on PATH ($PATH); skipping log upload to avatar."
    return
  fi
  if [ -z "${AVATAR_ID:-}" ] || [ -z "${NN_API_KEY:-}" ]; then
    log "WARN: AVATAR_ID/NN_API_KEY not set; skipping log upload to avatar."
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

if [ "$DO_UPLOAD" -eq 1 ]; then
  upload_log_to_avatar
fi
