# Issue tracker: GitHub

Use GitHub Issues for the repository currently being worked on.

- Infer the repository from its Git remote; never hardcode dotfiles.
- Use the gh CLI for issues, comments, labels and dependencies.
- Before creating issues, verify the destination with
  `gh repo view --json nameWithOwner`; confirm ambiguous fork/upstream targets.
- When a skill says to publish to the issue tracker, create a GitHub issue.
- Never default to the repository that distributes the skills.

PRs as a request surface: no. New work requests belong in Issues, not PRs.
This does not prohibit reviewing an existing PR: `code-review` accepts a PR
number/URL and publishes its review on that PR. Local review requests stay local.
