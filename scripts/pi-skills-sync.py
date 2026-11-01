#!/usr/bin/env python3
"""Refresh exactly two reviewed skill snapshots. Never called by chezmoi or CI."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "https://github.com/mattpocock/skills"
FILES = {
    "grilling/SKILL.md": "skills/productivity/grilling/SKILL.md",
    "grill-me/SKILL.md": "skills/productivity/grill-me/SKILL.md",
    "LICENSE": "LICENSE",
}
DELEGATION = 'Call the Skill tool with "grilling".'


def fetch(url):
    request = Request(url, headers={"User-Agent": "dotfiles-pi-skills-sync"})
    with urlopen(request, timeout=30) as response:
        return response.read()


def validate(files):
    if set(files) != set(FILES):
        raise ValueError("snapshot must contain exactly grilling, grill-me, and LICENSE")
    for name in ("grilling", "grill-me"):
        text = files[f"{name}/SKILL.md"].decode("utf-8")
        frontmatter = re.match(r"---\n(.*?)\n---\n", text, re.S)
        if not frontmatter:
            raise ValueError(f"{name}: missing frontmatter")
        fm = frontmatter.group(1)
        if not re.search(rf"^name: {name}$", fm, re.M):
            raise ValueError(f"{name}: unexpected skill name")
        if not re.search(r"^description: .+", fm, re.M):
            raise ValueError(f"{name}: missing description")
        if name == "grill-me":
            if not re.search(r"^disable-model-invocation: true$", fm, re.M):
                raise ValueError("grill-me must remain explicitly user-invoked")
            if text.count(DELEGATION) != 1:
                raise ValueError("upstream wrapper changed; review the Pi adapter before syncing")
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if not link.startswith(("https://", "http://", "#")):
                raise ValueError(f"{name}: new bundled reference {link!r}; review dependencies")
    if not files["LICENSE"].startswith(b"MIT License\n"):
        raise ValueError("upstream license changed; review before syncing")
    baseline = ROOT / "vendor/pi-skills/LICENSE"
    if files["LICENSE"] != baseline.read_bytes():
        raise ValueError("upstream license changed; review before syncing")


def write_snapshot(root, commit, files):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("--ref must be a full 40-character commit SHA")
    validate(files)
    metadata = {
        "repository": REPOSITORY,
        "commit": commit,
        "files": {
            name: {"upstream_path": FILES[name],
                   "sha256": hashlib.sha256(content).hexdigest()}
            for name, content in files.items()
        },
    }
    destination = root / "vendor/pi-skills"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".pi-skills-sync-", dir=root) as tmp:
        stage = Path(tmp) / "snapshot"
        for name, content in files.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        (stage / "SOURCE.json").write_text(json.dumps(metadata, indent=2) + "\n")
        old = Path(tmp) / "old"
        if destination.exists():
            destination.rename(old)
        try:
            stage.rename(destination)
        except BaseException:
            if old.exists():
                old.rename(destination)
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ref", help="full upstream commit SHA; default: upstream HEAD")
    args = parser.parse_args()
    commit = args.ref
    if commit is None:
        result = subprocess.run(["git", "ls-remote", REPOSITORY + ".git", "HEAD"],
                                check=True, capture_output=True, text=True)
        commit = result.stdout.split()[0]
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        parser.error("expected a full 40-character upstream commit SHA")
    files = {name: fetch(f"https://raw.githubusercontent.com/mattpocock/skills/{commit}/{path}")
             for name, path in FILES.items()}
    write_snapshot(ROOT, commit, files)
    print(f"Mirrored grilling and grill-me at {commit}.")
    print("Review: git diff -- vendor/pi-skills")
    print("Then run scripts/smoke-test.sh, review chezmoi diff, and apply.")


if __name__ == "__main__":
    main()
