# ~/.zsh/secrets.example.zsh — template for ~/.zsh/secrets.zsh.
#
# Copy to ~/.zsh/secrets.zsh (note: no .example), fill in real values, and
# chmod 600. ~/.zshrc sources the real file when present; it is listed in
# .chezmoiignore precisely so it can never be committed by accident.
# Secrets never go in this repo.

# GitHub. `gh` keeps its own token in ~/.config/gh/hosts.yml; export one here
# only for tools that want GITHUB_TOKEN / GH_TOKEN in the environment.
# export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Anthropic
# export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# OpenAI
# export OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
