#!/usr/bin/env python3
"""Exercise manifest changes through chezmoi apply, without network or user files."""
import json
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
    selected = "skills/engineering/implement"
    directory = repo / selected
    directory.mkdir(parents=True)
    skill = directory / "SKILL.md"
    skill.write_text("---\nname: implement\ndescription: Test fixture.\n---\n\nOriginal.\n")
    manifest.write_text(json.dumps([selected]))

    def apply(ok=True):
        result = subprocess.run([
            "chezmoi", "--source", str(SOURCE), "--destination", str(home),
            "apply", "--exclude=scripts", str(target),
        ], capture_output=True, text=True)
        assert (result.returncode == 0) == ok, result.stdout + result.stderr
        return result

    apply()
    assert json.loads(target.read_text())["skills"] == [str(directory.resolve())]
    assert not (home / ".agents").exists()
    assert not (home / ".pi/agent/skills").exists()

    other = repo / "skills/productivity/grill-me"
    other.mkdir(parents=True)
    (other / "SKILL.md").write_text("---\nname: grill-me\ndescription: Another fixture.\n---\n")
    manifest.write_text(json.dumps([selected, "skills/productivity/grill-me"]))
    apply()
    assert json.loads(target.read_text())["skills"] == [str(directory.resolve()), str(other.resolve())]
    manifest.write_text(json.dumps(["skills/productivity/grill-me"]))
    apply()
    assert json.loads(target.read_text())["skills"] == [str(other.resolve())]
    assert skill.is_file(), "deselecting a skill must not delete source content"

    # Direct paths leave edits live, rather than taking a snapshot on apply.
    skill.write_text("edited locally\n")
    manifest.write_text(json.dumps([selected]))
    apply()
    before = target.read_bytes()
    skill.write_text("edited again without applying\n")
    configured = Path(json.loads(target.read_text())["skills"][0])
    assert (configured / "SKILL.md").read_text() == "edited again without applying\n"
    apply()
    assert target.read_bytes() == before

    # Invalid input fails before rewriting the previously valid settings.
    for invalid in [None, {}, "skills", [42], [""], ["/absolute"], ["../outside"],
                    ["skills/../engineering"], ["skills//engineering"], ["skills/*"],
                    ["missing"], ["skills/engineering"], [selected, selected], [selected + "/SKILL.md"]]:
        manifest.write_text(json.dumps(invalid))
        result = apply(ok=False)
        assert "Pi skills:" in result.stderr, result.stderr
        assert target.read_bytes() == before
    manifest.write_text("not JSON")
    apply(ok=False)
    assert target.read_bytes() == before

    outside = home / "outside"
    outside.mkdir()
    (outside / "SKILL.md").write_text("outside checkout\n")
    (repo / "escape").symlink_to(outside, target_is_directory=True)
    manifest.write_text('["escape"]')
    apply(ok=False)
    assert target.read_bytes() == before
    # A symlinked SKILL.md must not sneak outside an otherwise valid directory.
    linked = repo / "linked"
    linked.mkdir()
    (linked / "SKILL.md").symlink_to(outside / "SKILL.md")
    manifest.write_text('["linked"]')
    apply(ok=False)
    assert target.read_bytes() == before
    (repo / "alias").symlink_to(directory, target_is_directory=True)
    manifest.write_text(json.dumps([selected, "alias"]))
    apply(ok=False)
    assert target.read_bytes() == before

    manifest.unlink()
    apply(ok=False)
    assert target.read_bytes() == before
    manifest.write_text("[]")
    repo.rename(repo.with_name("missing-checkout"))
    apply(ok=False)
    assert target.read_bytes() == before
    repo.with_name("missing-checkout").rename(repo)
    apply()
    assert json.loads(target.read_text())["skills"] == []
    assert skill.is_file(), "an empty selection must not remove source files"
    print("  ok  local manifest: selection changes, live edits, empty list, safe failures and no copies")
