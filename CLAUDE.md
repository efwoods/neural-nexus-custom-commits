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
                          `uv run --script ... -c`
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
- Logs: `~/.local/state/hourly_progress/run.log` (per run) and `cron.log`.
- `install.sh --setup` and `crontab.sh` are safe to re-run; `--setup` never
  overwrites an existing env file.

## Commands

```bash
# Run against the current repo (needs NN_API_KEY + an avatar id; uv installs deps)
uv run --script hourly_progress.py -c -a "$AVATAR_ID"

# Lint the shell scripts
shellcheck install.sh hourly_progress_all.sh crontab.sh

# Syntax-check the Python (there is no test suite)
python3 -c "import ast; ast.parse(open('hourly_progress.py').read()); print('syntax OK')"

# End-to-end dry of the cron path
~/.local/bin/hourly_progress_all.sh && tail -n 40 ~/.local/state/hourly_progress/run.log
```