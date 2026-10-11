# Code review skill source

Vendored from [awesome-skills/code-review-skill](https://github.com/awesome-skills/code-review-skill)
at commit `4850184dfd7765ea7b3c5c4e9b6cf8e0815ee7cb` (branch `main`).

`SKILL.md`, `reference/`, `assets/`, `scripts/`, and `LICENSE` are copied
verbatim. The upstream website, README, contributor docs, and development
metadata are not part of the installed skill. The MIT license is retained
in `LICENSE`; this file is local provenance, not an upstream file.

Chezmoi installs this directory to `~/.pi/agent/skills/code-review-skill/`.
Use `/skill:code-review-skill` in pi; `/reload` discovers it in an existing
session. Resolve supporting paths from this skill directory, not the
project being reviewed. On this Mac, invoke the optional analyzer with
`python3` (the upstream example uses `python`):

```bash
git diff main...HEAD | python3 ~/.pi/agent/skills/code-review-skill/scripts/pr-analyzer.py
```

Updates are manual: review a new upstream commit, replace the same files
in `dot_pi/agent/skills/code-review-skill/` in the dotfiles source repo,
update the commit above, then run `scripts/smoke-test.sh` and
`chezmoi diff && chezmoi apply`. No network fetch happens at apply time;
`pi update --extensions` does not update this repo-managed skill.
