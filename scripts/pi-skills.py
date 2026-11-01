#!/usr/bin/env python3
"""Resolve the local skills selection for Pi's chezmoi settings template."""
import json
from pathlib import Path
import sys


def skill_paths(checkout):
    root = Path(checkout).resolve(strict=True)
    manifest = root / "enabled-skills.json"
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


if __name__ == "__main__":
    try:
        print(json.dumps(skill_paths(sys.argv[1]), indent=2))
    except (OSError, ValueError) as error:
        sys.exit(f"Pi skills: {error}. Check ~/gh/skills/enabled-skills.json.")
