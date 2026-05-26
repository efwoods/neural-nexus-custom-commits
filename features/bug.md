
  # BUG
  currently; git_log_all.sh is purporting an ~/.local/state/hourly_progress/err.log 

 ./git_log_all.sh --since '1 hour ago' --no-upload


(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ ./git_log_all.sh --since '1 hour ago' --no-upload
(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ cat ~/.local/state/hourly_progress/err.log
2026-05-25 20:45:18 git_log_all: appended logs for 6 repo(s), 12 branch(es), since '30 minutes ago' (2026-05-25 20:15:17), root=/home/user/gh/anubis-project
2026-05-25 20:47:34 git_log_all: appended logs for 5 repo(s), 11 branch(es), since '2 minutes ago' (2026-05-25 20:45:34), root=/home/user/gh/anubis-project
2026-05-25 20:47:53 FATAL: invalid --since expression: 'totally not a date'
2026-05-25 20:47:53 git_log_all: appended logs for 5 repo(s), 11 branch(es), since '10 minutes ago' (2026-05-25 20:37:53), root=/home/user/gh/anubis-project
2026-05-25 21:19:33 git_log_all: appended logs for 5 repo(s), 11 branch(es), since '30 minutes ago' (2026-05-25 20:49:33), root=/home/user/gh/anubis-project
fatal: ambiguous argument 'research': both revision and filename
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
2026-05-25 21:38:47 git_log_all: appended 3 repo(s) + 5 worktree(s), 12 branch(es), since '30 minutes ago' (2026-05-25 21:08:47), root=/home/user/gh/anubis-project
fatal: ambiguous argument 'research': both revision and filename
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
2026-05-25 22:40:40 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:40:40), root=/home/user/gh/anubis-project
fatal: ambiguous argument 'research': both revision and filename
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
2026-05-25 22:53:30 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:53:30), root=/home/user/gh/anubis-project
fatal: ambiguous argument 'research': both revision and filename
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
2026-05-25 22:57:47 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:57:47), root=/home/user/gh/anubis-project
2026-05-25 22:58:09 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:58:08), root=/home/user/gh/anubis-project
error: invalid argument to --no-walk
fatal: unrecognized argument: --no-walk=gnu
error: invalid argument to --no-walk
fatal: unrecognized argument: --no-walk=gnu
error: invalid argument to --no-walk
fatal: unrecognized argument: --no-walk=gnu
error: invalid argument to --no-walk
fatal: unrecognized argument: --no-walk=gnu
error: invalid argument to --no-walk
fatal: unrecognized argument: --no-walk=gnu
2026-05-25 22:58:36 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:58:36), root=/home/user/gh/anubis-project
2026-05-25 22:59:39 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 21:59:39), root=/home/user/gh/anubis-project
2026-05-25 23:00:29 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:00:29), root=/home/user/gh/anubis-project
2026-05-25 23:00:39 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:00:39), root=/home/user/gh/anubis-project
2026-05-25 23:01:30 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:01:30), root=/home/user/gh/anubis-project
2026-05-25 23:01:35 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:01:35), root=/home/user/gh/anubis-project
2026-05-25 23:02:41 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:02:41), root=/home/user/gh/anubis-project
fatal: ambiguous argument 'research': both revision and filename
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
2026-05-25 23:25:27 git_log_all: appended 3 repo(s) + 1 submodule(s) + 4 worktree(s), 14 branch(es), since '1 hour ago' (2026-05-25 22:25:26), root=/home/user/gh/anubis-project
(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ 











`git_log_all.sh` exists next to `install.sh`.
      - Updated setup messaging and the cron description to reflect that the daily uploaded log now includes raw git logs too.
      - Added on-demand query examples using the installed `git_log_all.sh`.
    
    - **`progress_1_hour.txt`**
      - Removed the old content (it’s now empty in the diff).

 CLAUDE.md                        |  50 +++++-
 features/git_log_user_feature.md |   6 +
 git_log_all.sh                   | 330 +++++++++++++++++++++++++++++++++++++++
 hourly_progress.env.example      |   7 +
 hourly_progress_all.sh           |  16 ++
 install.sh                       |  26 ++-
 progress_1_hour.txt              |  61 ++++----
 7 files changed, 450 insertions(+), 46 deletions(-)

##### repo: nn_document_downloader_from_email | origin: https://github.com/efwoods/nn_document_downloader_from_email.git | /home/user/gh/anubis-project/nn_document_downloader_from_email #####

----- branch: main (main) -----
(no commits since 2026-05-25 22:25:26)



also a syntax error in hourly progress:

(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ rm ~/.local/state/hourly_progress/run.log
(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ cat ~/.local/state/hourly_progress/cron.log
/home/user/.local/bin/hourly_progress_all.sh: line 68: syntax error near unexpected token `)'
/home/user/.local/bin/hourly_progress_all.sh: line 68: ` 1))'
/home/user/.local/bin/hourly_progress_all.sh: line 72: e: command not found
/home/user/.local/bin/hourly_progress_all.sh: line 85: syntax error near unexpected token `done'
/home/user/.local/bin/hourly_progress_all.sh: line 85: `done'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: syntax error near unexpected token `}'
/home/user/.local/bin/hourly_progress_all.sh: line 109: `}'
(.venv) user@linux-pc:~/gh/anubis-project/wt/f-git-logs$ 