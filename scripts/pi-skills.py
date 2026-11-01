#!/usr/bin/env python3
"""Fetch the fork's remote main and resolve its manifest into Pi skill paths."""
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory


def skill_paths(checkout):
    root = Path(checkout).resolve(strict=True)
    manifest = root / "enabled-skills.json"
    if not manifest.resolve(strict=True).is_relative_to(root):
        raise ValueError(f"{manifest}: manifest escapes the checkout")
    entries = json.loads(manifest.read_text())
    if not isinstance(entries, list):
        raise ValueError(f"{manifest}: expected an array of relative skill directories")
    paths = []
    for entry in entries:
        if (not isinstance(entry, str) or not entry
                or any(part in ("", ".", "..") for part in entry.split("/"))
                or any(char in entry for char in "*?[]{}\\")):
            raise ValueError(f"{manifest}: invalid relative skill directory: {entry!r}")
        directory = (root / entry).resolve(strict=True)
        if not directory.is_relative_to(root):
            raise ValueError(f"{manifest}: skill directory escapes the checkout: {entry!r}")
        skill = directory / "SKILL.md"
        if not directory.is_dir() or not skill.is_file() or not skill.resolve().is_relative_to(root):
            raise ValueError(f"{manifest}: expected an in-checkout SKILL.md in {entry!r}")
        if str(directory) in paths:
            raise ValueError(f"{manifest}: duplicate skill directory: {entry!r}")
        paths.append(str(directory))
    return paths


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def published_skill_paths(home):
    cache = Path(home).resolve() / ".cache/dotfiles/pi-skills"
    cache.mkdir(parents=True, exist_ok=True)
    # The override is for offline tests. Production always defaults to our fork.
    repository = os.environ.get("DOTFILES_SKILLS_REPOSITORY", "https://github.com/brucepucci/skills.git")
    with TemporaryDirectory(prefix="fetch-", dir=cache) as work:
        checkout = Path(work) / "skills"
        git("clone", "--quiet", "--depth=1", "--single-branch", "--no-tags",
            "--branch", "main", "--", repository, str(checkout))
        commit = git("-C", str(checkout), "rev-parse", "refs/heads/main^{commit}")
        skill_paths(checkout)  # Validate the fetched manifest before publishing it.
        snapshot = cache / commit
        if snapshot.exists() or snapshot.is_symlink():
            if (snapshot.is_symlink()
                    or git("-C", str(snapshot), "rev-parse", "HEAD") != commit
                    or git("-C", str(snapshot), "status", "--porcelain", "--untracked-files=all", "--ignored")):
                raise ValueError(f"managed skills snapshot was modified: {snapshot}; restore or remove it and reapply")
        else:
            checkout.rename(snapshot)
        # Commit-specific paths leave active skills untouched during diff or a
        # failed apply. Old snapshots stay available for rollback; never edit them.
        return skill_paths(snapshot)


if __name__ == "__main__":
    try:
        print(json.dumps(published_skill_paths(sys.argv[1]), indent=2))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"Pi skills: {error}. Could not apply published brucepucci/skills main.")
