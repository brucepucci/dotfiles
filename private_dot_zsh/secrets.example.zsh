# ~/.zsh/secrets.example.zsh — template for ~/.zsh/secrets.zsh.
#
# Copy to ~/.zsh/secrets.zsh (note: no .example), fill in real values, and
# chmod 600. ~/.zshrc sources the real file when present; it is listed in
# .chezmoiignore precisely so it can never be committed by accident.
# Secrets never go in this repo.

# Z.ai — the pi coding agent's key (provider "zai"; get one at https://z.ai).
# pi's /login is an alternative that writes ~/.pi/agent/auth.json; if that
# file exists it takes precedence over this variable.
# export ZAI_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# GitHub. gh prefers a token in the environment over its own
# ~/.config/gh/hosts.yml — same token today, but if you re-run
# `gh auth login`, refresh or comment out this line.
# export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# Anthropic
# export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# OpenAI
# export OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
