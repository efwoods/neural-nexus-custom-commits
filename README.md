# neural-nexus-custom-commits
An example use case of using your Neural Nexus Avatar for custom commit messages!

## Instructions:
 Sign up for the Neural Nexus at api.neuralnexus.site
 Create an Avatar
 Select the Avatar & optionally message the avatar to inform the avatar about the identity or updload files to update the identity
 add your API key to your bashrc as NN_API_KEY
 move hourly_progress.py to your current repository
 run python hourly_progress.py --current
 
 Your currently selected avatar will be used for git diff summaries for your current repository!
 Optional: Create a cron job to summarize changes intermittently with empty commits (messages only)