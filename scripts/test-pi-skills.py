#!/usr/bin/env python3
"""Exercise remote-main updates through apply, using only disposable local Git repos."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parent.parent

with tempfile.TemporaryDirectory(prefix="pi-skills-") as work:
    work = Path(work)
    home = work / "home with spaces"
    upstream = work / "remote"
    upstream.mkdir()
    target = home / ".pi/agent/settings.json"
    target.parent.mkdir(parents=True)
    cache = home / ".cache/dotfiles/pi-skills"
    selected = "skills/engineering/implement"
    other = "skills/productivity/grill-me"
    manifest = upstream / "enabled-skills.json"

    def git(repo, *args):
        return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()

    def publish():
        git(upstream, "add", "-A")
        git(upstream, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Fixture update")
        return git(upstream, "rev-parse", "HEAD")

    git(upstream, "init", "-qb", "main")
    skill = upstream / selected / "SKILL.md"
    skill.parent.mkdir(parents=True)
    skill.write_text("---\nname: implement\ndescription: Test fixture.\n---\n\nPublished original.\n")
    manifest.write_text(json.dumps([selected]))
    first = publish()
    # Neither the remote's default branch nor the developer's checkout is main.
    git(upstream, "checkout", "-qb", "feature")
    manifest.write_text("[]")
    publish()
    developer = home / "gh/skills"
    developer.parent.mkdir(parents=True)
    subprocess.run(["git", "clone", "-q", upstream.as_uri(), str(developer)], check=True)
    local_skill = developer / selected / "SKILL.md"
    local_skill.write_text("uncommitted developer work\n")
    (developer / "untracked").write_text("keep me\n")
    developer_before = (git(developer, "rev-parse", "HEAD"), git(developer, "status", "--porcelain"))
    env = {**os.environ, "DOTFILES_SKILLS_REPOSITORY": upstream.as_uri()}

    def apply(ok=True, command="apply"):
        result = subprocess.run([
            "chezmoi", "--source", str(SOURCE), "--destination", str(home),
            command, "--exclude=scripts", str(target),
        ], capture_output=True, text=True, env=env)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        assert (git(developer, "rev-parse", "HEAD"), git(developer, "status", "--porcelain")) == developer_before
        assert local_skill.read_text() == "uncommitted developer work\n"
        assert (developer / "untracked").read_text() == "keep me\n"
        return result

    def paths():
        return json.loads(target.read_text())["skills"]

    def expected(commit, entries):
        return [str((cache / commit / entry).resolve()) for entry in entries]

    apply()
    assert paths() == expected(first, [selected]), "must fetch main, not the remote default/developer branch"
    assert "Published original." in (Path(paths()[0]) / "SKILL.md").read_text()
    assert not (home / ".agents").exists()
    assert not (home / ".pi/agent/skills").exists()
    original_settings = target.read_bytes()
    apply()
    assert target.read_bytes() == original_settings, "unchanged main must reuse stable paths"

    # Publish content and manifest updates together; diff must not change active skills.
    git(upstream, "checkout", "-q", "main")
    (upstream / other).mkdir(parents=True)
    (upstream / other / "SKILL.md").write_text("---\nname: grill-me\ndescription: Another fixture.\n---\n")
    skill.write_text("published update\n")
    manifest.write_text(json.dumps([selected, other]))
    second = publish()
    apply(command="diff")
    assert target.read_bytes() == original_settings
    assert "Published original." in (cache / first / selected / "SKILL.md").read_text()
    apply()
    assert paths() == expected(second, [selected, other])
    assert (Path(paths()[0]) / "SKILL.md").read_text() == "published update\n"

    # A removed entry/file disappears from the active selection, not from old snapshots.
    shutil.rmtree(upstream / selected)
    manifest.write_text(json.dumps([other]))
    third = publish()
    apply()
    assert paths() == expected(third, [other])
    assert (cache / first / selected / "SKILL.md").is_file()
    before = target.read_bytes()

    # A fetch failure must fail closed, not silently fall back to stale cached content.
    upstream.rename(work / "offline")
    apply(ok=False)
    assert target.read_bytes() == before
    (work / "offline").rename(upstream)
    git(upstream, "branch", "-m", "main", "not-main")
    apply(ok=False)
    assert target.read_bytes() == before, "a missing main branch must not fall back to another ref"
    git(upstream, "branch", "-m", "not-main", "main")

    # Invalid remote manifests never replace settings or the last valid snapshot.
    for invalid in [None, {}, "skills", [42], [""], ["/absolute"], ["../outside"],
                    ["skills/../engineering"], ["skills//engineering"], ["skills/*"],
                    [selected], ["skills/productivity"], [other, other], [other + "/SKILL.md"]]:
        manifest.write_text(json.dumps(invalid))
        bad = publish()
        result = apply(ok=False)
        assert "Pi skills:" in result.stderr, result.stderr
        assert target.read_bytes() == before
        assert not (cache / bad).exists(), "invalid snapshots must not be published"
    manifest.write_text("not JSON")
    publish()
    apply(ok=False)
    assert target.read_bytes() == before

    outside = work / "outside"
    outside.mkdir()
    (outside / "SKILL.md").write_text("outside checkout\n")
    (upstream / "escape").symlink_to(outside, target_is_directory=True)
    manifest.write_text('["escape"]')
    publish()
    apply(ok=False)
    assert target.read_bytes() == before
    linked = upstream / "linked"
    linked.mkdir()
    (linked / "SKILL.md").symlink_to(outside / "SKILL.md")
    manifest.write_text('["linked"]')
    publish()
    apply(ok=False)
    assert target.read_bytes() == before
    manifest.unlink()
    publish()
    apply(ok=False)
    assert target.read_bytes() == before

    outside_manifest = outside / "enabled-skills.json"
    outside_manifest.write_text(json.dumps([other]))
    manifest.symlink_to(outside_manifest)
    publish()
    apply(ok=False)
    assert target.read_bytes() == before
    manifest.unlink()
    manifest.write_text(json.dumps([other]))
    valid = publish()
    apply()
    assert paths() == expected(valid, [other])
    cached_skill = Path(paths()[0]) / "SKILL.md"
    original = cached_skill.read_bytes()
    cached_skill.write_text("accidental cache edit\n")
    before = target.read_bytes()
    result = apply(ok=False)
    assert "snapshot was modified" in result.stderr
    assert target.read_bytes() == before
    assert cached_skill.read_text() == "accidental cache edit\n", "never discard edits implicitly"
    cached_skill.write_bytes(original)
    apply()

    manifest.write_text("[]")
    publish()
    apply()
    assert paths() == []
    assert cached_skill.is_file(), "deselection must preserve old snapshots for active sessions/rollback"
    assert not any(cache.glob("fetch-*")), "temporary clones should always be cleaned up"
    print("  ok  remote main: content/config updates, removals, stable snapshots, safe failures and developer isolation")
