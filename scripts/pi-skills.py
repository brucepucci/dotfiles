#!/usr/bin/env python3
"""Expose a local skills selection through ~/.agents/skills symlinks."""
import json
import os
from pathlib import Path
import sys


def skill_paths(checkout):
    root = checkout.resolve(strict=True)
    manifest = root / "enabled-skills.json"
    if not manifest.resolve(strict=True).is_relative_to(root):
        raise ValueError(f"{manifest}: manifest escapes the checkout")
    entries = json.loads(manifest.read_text())
    if not isinstance(entries, list):
        raise ValueError(f"{manifest}: expected an array of relative skill directories")
    paths = []
    names = set()
    for entry in entries:
        if (not isinstance(entry, str) or not entry
                or any(part in ("", ".", "..") for part in entry.split("/"))
                or any(char in entry for char in "*?[]{}\\")):
            raise ValueError(f"{manifest}: invalid relative skill directory: {entry!r}")
        directory = (root / entry).resolve(strict=True)
        if directory == root or not directory.is_relative_to(root):
            raise ValueError(f"{manifest}: expected a skill directory below the checkout: {entry!r}")
        skill = directory / "SKILL.md"
        if not directory.is_dir() or not skill.is_file() or not skill.resolve().is_relative_to(root):
            raise ValueError(f"{manifest}: expected an in-checkout SKILL.md in {entry!r}")
        if directory in paths:
            raise ValueError(f"{manifest}: duplicate skill directory: {entry!r}")
        if directory.name.startswith(".") or directory.name.casefold() in names:
            raise ValueError(f"{manifest}: hidden or duplicate discovery name: {directory.name!r}")
        paths.append(directory)
        names.add(directory.name.casefold())
    return paths


def reconcile(home):
    checkout = home / "gh/skills"
    # Validate the entire selection and destination before changing any links.
    desired = {path.name: path for path in skill_paths(checkout)}
    root = checkout.resolve(strict=True)
    agents = home / ".agents"
    destination = agents / "skills"
    for parent in (agents, destination):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError(f"{parent}: expected a real directory, not a file or symlink")

    def owned(link):
        if not link.is_symlink():
            return False
        # Lexical containment also recognizes dangling links after source deletion.
        # Do not follow the link or a symlink inside the checkout to claim ownership.
        target = Path(os.path.abspath(link.parent / link.readlink()))
        return any(target != base and target.is_relative_to(base)
                   for base in (checkout, root))

    existing = list(destination.iterdir()) if destination.exists() else []
    for name in desired:
        link = destination / name
        if (link.exists() or link.is_symlink()) and not owned(link):
            raise ValueError(f"{link}: unrelated skill already exists; move it aside explicitly")

    if desired:
        destination.mkdir(parents=True, exist_ok=True)
    for link in existing:
        if owned(link) and link.name not in desired:
            link.unlink()
            print(f"Skills: removed deselected link {link.name}")
    for name, path in desired.items():
        link = destination / name
        if link.is_symlink() and link.readlink() == path:
            continue
        if link.is_symlink():
            link.unlink()
        link.symlink_to(path, target_is_directory=True)
        print(f"Skills: linked {name}")


if __name__ == "__main__":
    try:
        reconcile(Path(sys.argv[1]).absolute())
    except (OSError, ValueError) as error:
        sys.exit(f"Pi skills: {error}. Check ~/gh/skills/enabled-skills.json.")
