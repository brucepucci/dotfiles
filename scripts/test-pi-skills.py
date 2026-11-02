#!/usr/bin/env python3
"""Exercise skill selection through real chezmoi apply, offline in a scratch HOME."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parent.parent

with tempfile.TemporaryDirectory(prefix="pi-skills-") as work:
    home = Path(work) / "home with spaces"
    repo = home / "gh/skills"
    repo.mkdir(parents=True)
    manifest = repo / "enabled-skills.json"
    target = home / ".pi/agent/settings.json"
    target.parent.mkdir(parents=True)
    # Model the previous cache-based install: apply must remove this wiring.
    target.write_text('{"skills": ["~/.cache/dotfiles/pi-skills/old/implement"]}\n')
    links = home / ".agents/skills"
    links.mkdir(parents=True)
    selected = "skills/engineering/implement"

    def fixture(relative):
        directory = repo / relative
        directory.mkdir(parents=True)
        (directory / "SKILL.md").write_text(
            f"---\nname: {directory.name}\ndescription: Test fixture.\n---\n\nOriginal.\n")
        return directory

    directory = fixture(selected)
    skill = directory / "SKILL.md"
    other = fixture("skills/productivity/grill-me")
    unselected = fixture("skills/in-progress/not-selected")
    # Existing checkout links (even unselected/broken ones) are ours to reconcile.
    (links / "not-selected").symlink_to(unselected, target_is_directory=True)
    (links / "deleted").symlink_to(repo / "deleted", target_is_directory=True)
    outside = home / "outside"
    outside.mkdir()
    (outside / "SKILL.md").write_text("unrelated content\n")
    (links / "foreign-link").symlink_to(outside, target_is_directory=True)
    (links / "foreign-broken").symlink_to(home / "missing", target_is_directory=True)
    (links / "foreign-prefix").symlink_to(home / "gh/skills-unrelated/skill", target_is_directory=True)
    (links / "user-skill").mkdir()
    (links / "user-skill/SKILL.md").write_text("user content\n")
    lock = home / ".agents/.skill-lock.json"
    lock.write_text("unmanaged lock\n")
    manifest.write_text(json.dumps([selected]))

    def apply(ok=True, dry_run=False):
        result = subprocess.run([
            "chezmoi", "--source", str(SOURCE), "--destination", str(home),
            "apply", *(["--dry-run"] if dry_run else []),
        ], capture_output=True, text=True)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        return result

    def snapshot():
        return {p.name: ("link", os.readlink(p)) if p.is_symlink()
                else ("dir", (p / "SKILL.md").read_text()) for p in links.iterdir()}

    def preserved():
        assert (links / "foreign-link").readlink() == outside
        assert (links / "foreign-broken").is_symlink()
        assert (links / "foreign-prefix").is_symlink()
        assert (links / "user-skill/SKILL.md").read_text() == "user content\n"
        assert lock.read_text() == "unmanaged lock\n"
        assert not (home / ".pi/agent/skills").exists(), "duplicate Pi skill copies"

    initial = snapshot()
    apply(dry_run=True)
    assert "skills" in json.loads(target.read_text()), "dry-run rewrote settings"
    assert snapshot() == initial, "dry-run changed discovery links"
    apply()
    assert "skills" not in json.loads(target.read_text()), "old cache wiring survived"
    assert (links / "implement").is_symlink()
    assert (links / "implement").resolve() == directory.resolve()
    assert not (links / "not-selected").exists()
    assert not (links / "deleted").is_symlink(), "broken checkout link survived"
    preserved()
    before = target.read_bytes()
    first = snapshot()
    inode = (links / "implement").lstat().st_ino
    apply()
    assert snapshot() == first and target.read_bytes() == before
    assert (links / "implement").lstat().st_ino == inode, "unchanged link rewritten"

    # Adopt/repair an existing relative checkout link without making a copy.
    (links / "implement").unlink()
    (links / "implement").symlink_to(Path("../../gh/skills") / selected, target_is_directory=True)
    manifest.write_text(json.dumps([selected, "skills/productivity/grill-me"]))
    apply()
    assert (links / "implement").readlink() == directory.resolve()
    assert (links / "grill-me").resolve() == other.resolve()
    manifest.write_text(json.dumps(["skills/productivity/grill-me"]))
    apply()
    assert not (links / "implement").is_symlink()
    assert skill.is_file(), "deselection deleted source content"

    # Move/rename a selected directory, leaving its old link dangling.
    renamed = repo / "skills/productivity/renamed"
    other.rename(renamed)
    manifest.write_text('["skills/productivity/renamed"]')
    apply()
    assert not (links / "grill-me").is_symlink()
    assert (links / "renamed").resolve() == renamed.resolve()
    manifest.write_text(json.dumps([selected]))
    apply()
    skill.write_text("edited without applying\n")
    assert (links / "implement/SKILL.md").read_text() == "edited without applying\n"
    stable = snapshot()

    # Invalid manifests must not prune links or rewrite settings.
    for invalid in [None, {}, "skills", [42], [""], ["/absolute"], ["../outside"],
                    ["skills/../engineering"], ["skills//engineering"], ["skills/*"],
                    ["missing"], ["skills/engineering"], [selected, selected], [selected + "/SKILL.md"]]:
        manifest.write_text(json.dumps(invalid))
        result = apply(ok=False)
        assert "Pi skills:" in result.stderr, result.stderr
        assert target.read_bytes() == before and snapshot() == stable
    manifest.write_text("not JSON")
    apply(ok=False)
    assert snapshot() == stable

    (repo / "escape").symlink_to(outside, target_is_directory=True)
    linked = repo / "linked"
    linked.mkdir()
    (linked / "SKILL.md").symlink_to(outside / "SKILL.md")
    (repo / "alias").symlink_to(directory, target_is_directory=True)
    fixture("skills/another/implement")
    fixture("skills/case/IMPLEMENT")
    fixture("skills/another/.hidden")
    (repo / "root-alias").symlink_to(repo, target_is_directory=True)
    (repo / "SKILL.md").write_text("root must not be selected\n")
    for entries in [["escape"], ["linked"], ["root-alias"], [selected, "alias"],
                    [selected, "skills/another/implement"],
                    [selected, "skills/case/IMPLEMENT"], ["skills/another/.hidden"]]:
        manifest.write_text(json.dumps(entries))
        apply(ok=False)
        assert snapshot() == stable and target.read_bytes() == before

    # Never replace an unrelated directory, regular file, or symlink on a name collision.
    for name in ["user-skill", "foreign-link", "foreign-broken", "user-file"]:
        relative = f"skills/fixtures/{name}"
        fixture(relative)
        if name == "user-file":
            (links / name).write_text("keep me\n")
        manifest.write_text(json.dumps([relative]))
        result = apply(ok=False)
        assert "unrelated" in result.stderr, result.stderr
        assert (links / "implement").is_symlink(), "collision partially pruned selection"
    assert (links / "user-file").read_text() == "keep me\n"
    (links / "user-file").unlink()
    assert snapshot() == stable

    manifest.unlink()
    # A linked manifest cannot move selection ownership outside the checkout.
    foreign_manifest = home / "foreign-selection.json"
    foreign_manifest.write_text("[]")
    manifest.symlink_to(foreign_manifest)
    apply(ok=False)
    assert snapshot() == stable
    manifest.unlink()
    apply(ok=False)
    assert snapshot() == stable
    manifest.write_text("[]")
    repo.rename(repo.with_name("missing-checkout"))
    apply(ok=False)
    assert snapshot() == stable
    repo.with_name("missing-checkout").rename(repo)
    apply()
    assert not (links / "implement").is_symlink()
    preserved()
    assert skill.is_file(), "empty selection deleted source content"

    # Refuse symlinked discovery parents instead of writing/pruning another tree.
    manifest.write_text(json.dumps([selected]))
    links.rename(home / "saved-skills")
    links.symlink_to(home / "saved-skills", target_is_directory=True)
    apply(ok=False)
    links.unlink()
    (home / "saved-skills").rename(links)
    agents = home / ".agents"
    agents.rename(home / "saved-agents")
    agents.symlink_to(home / "saved-agents", target_is_directory=True)
    apply(ok=False)
    agents.unlink()
    (home / "saved-agents").rename(agents)
    preserved()
    print("  ok  skill links: selection, migration, live edits, dry-run, empty list, safe failures and ownership")
