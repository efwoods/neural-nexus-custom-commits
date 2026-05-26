# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A small automation that turns a Neural Nexus **Avatar** (a hosted AI persona at
`api.neuralnexus.site`) into a git commit-message writer. It captures a repo's
`git diff`, sends it to the avatar, and commits the avatar's first-person summary
as the commit message. The headline use case is recording progress across many
git worktrees on a cron schedule.

## Core flow (`hourly_progress.py`)

This single script is the whole tool; everything else installs or schedules it.

1. Resolve `NN_API_KEY` and `AVATAR_ID`. **Environment variables take precedence
   over CLI flags** (`os.environ.get(...) or args...`), so an exported var
   silently overrides `-k`/`-a`.
2. Write `git diff HEAD` (staged + unstaged vs last commit) to a temp file
   `progress_1_hour.txt` in the cwd.
3. POST that file to `https://api.neuralnexus.site/message/{avatar_id}` (header
   `API-KEY`, multipart `files`, a `message` instruction prompt). The prompt
   tells the avatar to speak in first person, reference only what's in the diff,
   and name the current worktree (derived from `basename(cwd)`).
4. Overwrite the temp file with the avatar's reply and use it as the commit
   message via `git commit -F`, then `git push`. Finally `rm` the temp file.

**Commit behavior is the key design point:** by default it makes an **empty
commit** (`git commit --allow-empty -F ...`) — message only, no file changes —
so progress narration never disturbs the working tree. `--mass_commit` instead
does `git add -A && git commit -F ...` to commit the actual changes with the
avatar's message.

The `--current`/`-c` flag vs. the default only swaps "since the last commit" for
"within the last hour" wording in the prompt; both are otherwise identical, and
all automation paths pass `-c`.

## Automation layering

```
install.sh --setup      → copies hourly_progress_all.sh to ~/.local/bin,
                          creates ~/.config/hourly_progress.env (chmod 600,
                          from hourly_progress.env.example), runs crontab.sh
crontab.sh              → idempotent cron entry: 20,50 * * * * → the wrapper
hourly_progress_all.sh → cron-run wrapper; loops every worktree under $WT_ROOT
                          that contains hourly_progress.py and runs it via
                          `uv run --script ... -c`, appends raw cross-repo git logs
                          (git_log_all.sh), then uploads the day's log to the avatar
git_log_all.sh         → collects RAW `git log`: test/dev/main of each top-level repo
                          under $GIT_LOG_ROOT, plus each linked worktree on its own
                          branch; appends to the day's log; called by the wrapper at
                          :20/:50 and runnable standalone as a query
install.sh --worktree   → copies hourly_progress.py into one worktree (or --all)
```

- `~/.config/hourly_progress.env` holds `AVATAR_ID`, `NN_API_KEY`, `WT_ROOT`.
  It exists because **cron has a minimal environment and cannot see your
  interactive shell**; the wrapper sources this file and sets `PATH`/`HOME`
  itself. Until the file has real values the wrapper exits early (logs `FATAL`),
  making no network calls or commits.
- The wrapper runs each worktree via `uv run --script`, which resolves the
  script's PEP 723 deps (`httpx`, `python-dotenv`) into an isolated, cached env —
  ignoring any `pyproject.toml` in the worktree. `uv` must be on cron's `PATH`
  (the wrapper adds `$HOME/.local/bin` and aborts with `FATAL` if uv is absent).
  There is nothing to `pip install` per worktree.
- `git push` under cron needs non-interactive auth (stored HTTPS credentials or
  a passphrase-less SSH key).
- **Cross-repo git logs (`git_log_all.sh`).** After the worktree loop and before the
  upload, the wrapper runs `git_log_all.sh --since "30 minutes ago" --no-upload`. The
  collector scans `$GIT_LOG_ROOT` (default: parent of `WT_ROOT`, i.e.
  `/home/user/gh/anubis-project`) and appends the **raw** `git log` (`--stat`, not
  summarized) for three kinds of thing: each **top-level repo** (an immediate child
  of the root whose `.git` is a real directory) gets its `test`/`dev`/`main` branches
  (`##### repo: X #####`); each **registered submodule** of those repos — enumerated
  via `git submodule foreach --recursive` — is logged as its own entry, also for
  `test`/`dev`/`main` (`##### submodule: Y | parent: X #####`); and each **linked
  worktree** — found via `git worktree list` — is logged **separately and only for
  the branch it has checked out** (`##### worktree: Z | parent: X #####`). It
  deliberately does **not** recurse the filesystem: stray nested clones that are NOT
  registered submodules (e.g. `data/elon-musk-dataset`) and unregistered/stale
  worktrees are never treated as repos. Worktree logs are read from the parent repo's
  shared object store, so a broken worktree directory can't break collection. It is also a standalone,
  queryable command: `./git_log_all.sh --since "<any date -d expr>"` (default
  `"30 minutes ago"`; e.g. `"1 minute ago"`, `"1 hour ago"`, `"1 week ago"`). Run
  standalone it uploads the day's log by default; run from the wrapper it passes
  `--no-upload` so there is exactly one combined upload per cron cycle. `--since` is
  normalized so the window is never under-shot: a valid `date -d` expression is used
  as-is; an invalid but numeric one is rounded UP to a whole unit (`59.5 minutes ago`
  → `60 minutes ago`, `1.5 hours ago` → `2 hours ago`); unparseable input maps to the
  largest window (`1 week ago`); and any sub-minute window is floored to `1 minute
  ago`. The collector needs no avatar credentials to collect — only to upload.
- After the worktree loop, the wrapper POSTs the day's dated log to the avatar via
  `curl -F` to `https://api.neuralnexus.site/update_avatar_identity_with_media`
  (header `API-KEY`, multipart `files=@<log>`, `assistant_id=$AVATAR_ID`), so the
  avatar indexes the day's accumulated progress. curl must set the multipart
  `Content-Type` itself (boundary), so the wrapper never sets that header by hand.
  Upload failures (including the HTTP error body) are logged to `err.log`, not
  fatal — the commits/pushes already happened.
- **The dated log is split from operational output by design.** The wrapper writes
  each worktree's run two ways: the script's **stdout** (only the avatar's update —
  the script sends every diagnostic to stderr) is appended under a worktree header
  to `run_YYYY-MM-DD.log`, and its **stderr** plus all `log()` lines (run markers,
  OK/FAILED, FATAL/WARN, uv/Python/curl stderr) go to `err.log`. `git_log_all.sh`
  follows the same rule: the raw git logs it collects go straight into
  `run_YYYY-MM-DD.log`, its diagnostics into `err.log`. Only `run_YYYY-MM-DD.log` is
  uploaded, so the avatar never sees operational noise.
- Logs in `~/.local/state/hourly_progress/`: `run_YYYY-MM-DD.log` (per-worktree avatar
  updates **plus** the raw cross-repo git logs, one file per day, the uploaded file),
  `err.log` (operational + errors), and `cron.log` (cron-level stdout/stderr).
- `install.sh --setup` and `crontab.sh` are safe to re-run; `--setup` never
  overwrites an existing env file.

## Commands

```bash
# Run against the current repo (needs NN_API_KEY + an avatar id; uv installs deps)
uv run --script hourly_progress.py -c -a "$AVATAR_ID"

# Query cross-repo git logs for any period (appends to today's log; uploads by default)
./git_log_all.sh --since "1 hour ago"            # any `date -d` expression
./git_log_all.sh --since "1 week ago" --no-upload  # collect only, no avatar upload

# Lint the shell scripts
shellcheck install.sh hourly_progress_all.sh git_log_all.sh crontab.sh

# Syntax-check the Python (there is no test suite)
python3 -c "import ast; ast.parse(open('hourly_progress.py').read()); print('syntax OK')"

# End-to-end dry of the cron path
~/.local/bin/hourly_progress_all.sh && tail -n 40 ~/.local/state/hourly_progress/run_"$(date '+%Y-%m-%d')".log
```