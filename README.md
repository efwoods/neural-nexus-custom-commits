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


## Instructions:
 Sign up for the Neural Nexus at api.neuralnexus.site
 Create an Avatar
 Select the Avatar & optionally message the avatar to inform the avatar about the identity or updload files to update the identity
 add your API key to your bashrc as NN_API_KEY
 move hourly_progress.py to your current repository
 run python hourly_progress.py --current
 
 Your currently selected avatar will be used for git diff summaries for your current repository!
 Optional: Create a cron job to summarize changes intermittently with empty commits (messages only)

## [Support the project if you enjoy!](www.neuralnexus.site/welcome)
- [Donate](https://github.com/sponsors/efwoods)