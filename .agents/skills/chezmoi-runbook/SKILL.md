---
name: chezmoi-runbook
description: Verify changes to this dotfiles repo after any edit and before pushing or opening a PR. Follow the repo's smoke test, chezmoi diff/apply, Neovim health checks, and plugin lockfile workflow.
---

# Dotfiles verification

This skill is local to this repository, not a general chezmoi runbook.
Resolve the links below relative to this skill directory; the repository root
is `../../..`. Work from that root before running verification commands.

1. Read [AGENTS.md](../../../AGENTS.md) completely. Its rules apply whether
   or not this skill is invoked.
2. Follow [Verifying a change](../../../AGENTS.md#verifying-a-change) after
   every change and again before pushing or opening a PR.
3. For plugin changes, also follow
   [After changing plugins](../../../AGENTS.md#after-changing-plugins).
4. Read [the maintainer's guide](../../../docs/developing.md) for the test
   pyramid, task-specific checks, settings drift, and rollback.

AGENTS.md is the source of truth for commands and verification requirements.
Do not copy them into this skill; keep this file a thin entry point to the
repo's live documentation. Report which checks passed, any skips or failures,
and any unrelated target drift left untouched.
