# neural-nexus-custom-commits
An example use case of using your Neural Nexus Avatar for custom commit messages!

## Results:
commit 4f23b77ea262669d4780d45a4cb8c93569e7d12a (HEAD -> main, origin/main, origin/HEAD)
Author: Evan Woods <22337004+efwoods@users.noreply.github.com>
Date:   Thu Apr 9 11:13:21 2026 -0400

    Since the last commit, I updated `README.md` to add a new **“Instructions”** section with step-by-step setup and usage guidance:
    
    - Added instructions to sign up at `api.neuralnexus.site` and create/select an Avatar.
    - Included steps to add your Neural Nexus API key to your `bashrc` as `NN_API_KEY`.
    - Added guidance to move `hourly_progress.py` into the current repository and run:
      - `python hourly_progress.py --current`
    - Documented that the currently selected avatar will be used for git diff summaries for the current repository.
    - Added an optional note about creating a cron job to summarize changes intermittently with empty commits (messages only).
    
    Also, the file now ends without a newline (`\ No newline at end of file`).

commit 67399e8cadd0e7417a3a884401532437bc424f54
Author: Evan Woods <22337004+efwoods@users.noreply.github.com>
Date:   Thu Apr 9 10:45:32 2026 -0400

    Initial commit

## Requirements
- Python 3 with `httpx` and `python-dotenv` (`pip install httpx python-dotenv`).
  In a worktree that uses a virtualenv, install them into that `.venv`.
- A Neural Nexus account, an Avatar, and your API key — see step 1 below.

## Quick start (single repository)
1. Sign in at [api.neuralnexus.site](https://api.neuralnexus.site), create an
   Avatar, and copy its **assistant id** (`AVATAR_ID`). Optionally message the
   avatar or upload files to shape its identity/voice.
2. Add your API key to your shell, e.g. in `~/.bashrc`: `export NN_API_KEY="..."`.
3. Clone this repository inside the repo you want to summarize, then drop the
   script in: `./install.sh --worktree` (copies `hourly_progress.py` into the
   current directory).
4. Generate a commit message from your uncommitted changes:
   ```
   python hourly_progress.py -c -a "$AVATAR_ID"
   ```
   Your selected avatar writes the git-diff summary, commits it, and pushes.

## Automated setup (cron, all worktrees)
Posts each worktree's progress to your avatar at **:20 and :50 every hour** by
running `python ./hourly_progress.py -c -a $AVATAR_ID` in every worktree under
your worktree root. New worktrees are picked up automatically.

Clone this repo once and keep the checkout (it is the source `--worktree` copies
from), then:

1. **Machine-wide setup** — installs the cron wrapper, creates the config file,
   and installs the cron entry:
   ```
   ./install.sh --setup
   ```
2. **Create your avatar** at [api.neuralnexus.site](https://api.neuralnexus.site)
   and copy its assistant id (this becomes `AVATAR_ID`).
3. **Fill in your config** — edit `~/.config/hourly_progress.env` (created by
   step 1, `chmod 600`) and set:
   - `AVATAR_ID` — the avatar's assistant id
   - `NN_API_KEY` — your Neural Nexus API key
   - `WT_ROOT` — the folder that holds all your worktrees
     (e.g. `/home/user/gh/anubis-project/wt`)
4. **Install the script into your worktrees**:
   ```
   ./install.sh --worktree --all          # every worktree under WT_ROOT
   # or, per worktree:
   cd <worktree> && /path/to/this/repo/install.sh --worktree
   ```

That's it. The cron job runs at :20 and :50; logs land in
`~/.local/state/hourly_progress/run.log` (per-run) and `cron.log` (cron-level).

Test a run immediately (after steps 1–4):
```
~/.local/bin/hourly_progress_all.sh && tail -n 40 ~/.local/state/hourly_progress/run.log
```

### What `--setup` installs
| Path | Purpose |
| --- | --- |
| `~/.local/bin/hourly_progress_all.sh` | Loops over every worktree under `WT_ROOT` and runs the script (uses each worktree's `.venv/bin/python`, falling back to `/usr/bin/python3`). |
| `~/.config/hourly_progress.env` | Your `AVATAR_ID`, `NN_API_KEY`, and `WT_ROOT` (`chmod 600`, sourced by cron — cron can't see your shell env). |
| crontab entry | `20,50 * * * *` → runs the wrapper, logging to `~/.local/state/hourly_progress/`. |

Re-running `./install.sh --setup` is safe: it refreshes the wrapper and cron
entry and **never overwrites** an existing config file. To repair just the cron
entry, run `./crontab.sh`.

### Notes & gotchas
- **Cron has a minimal environment.** It does not see your interactive shell's
  `AVATAR_ID`/`NN_API_KEY`, which is why they live in
  `~/.config/hourly_progress.env`. Until that file is filled in, the wrapper
  exits safely and logs a `FATAL: ... empty` line (no network calls, no commits).
- **`git push` under cron** needs non-interactive auth — either an HTTPS
  credential helper (`git config --global credential.helper store` with
  `~/.git-credentials`) or an SSH key without a passphrase / an SSH agent
  available to cron.
- **Each worktree needs `httpx` + `python-dotenv`** available to the Python it
  runs (its `.venv` or system Python), or that worktree's run will fail while the
  others continue.

## [Support the project if you enjoy!](https://www.neuralnexus.site/welcome)
- [Donate](https://github.com/sponsors/efwoods)
