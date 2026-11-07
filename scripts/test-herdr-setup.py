#!/usr/bin/env python3
"""Check Herdr palettes, desktop setup, legacy retirement, and import boundaries."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
brewfile = (repo / "Brewfile").read_text()
assert re.search(r'^cask "herdr-app"$', brewfile, re.M), "desktop app cask missing"
assert not re.search(r'^brew "herdr(?:-core)?"', brewfile, re.M), "legacy/nonexistent formula"
assert not (repo / "private_dot_config/herdr").exists(), "legacy config still managed"
app_source = repo / "private_dot_config/herdr-app"
assert (app_source / "settings.json.tmpl").is_file(), "Herdr settings must resolve appearance"
environment = {k: v for k, v in os.environ.items() if k not in ("DOTFILES_SETTINGS_FILE", "DOTFILES_THEMES")}


def appearance(extra=None):
    return json.loads(subprocess.run(
        [sys.executable, str(repo / "scripts/theme.py"), "appearance"],
        env={**environment, **(extra or {})}, capture_output=True, text=True, check=True,
    ).stdout)


def check_palettes(home, data):
    expected = {"telemetry": False, "theme": {"light": "dotfiles-light", "dark": "dotfiles-dark"}}
    if data["mode"] != "system":
        expected["appearance"] = data["mode"]
    actual = json.loads((home / ".config/herdr-app/settings.json").read_text())
    assert actual == expected, ("Herdr mode/preferences", actual, expected)
    for side in ("light", "dark"):
        terminal = data[side]["terminal"]
        expected_theme = {
            "background": terminal["background"],
            "foreground": terminal["foreground"],
            "cursor": terminal["cursor-color"],
            "selection": terminal["selection-background"],
            "ansi": [terminal[f"palette_{i}"] for i in range(16)],
        }
        path = home / f".config/herdr-app/themes/dotfiles-{side}.json"
        actual = json.loads(path.read_text())
        assert actual == expected_theme, ("Herdr palette mismatch", side, actual, expected_theme)


# When called by smoke-test, check the actual full-repo apply as well as fixtures.
if len(sys.argv) > 1:
    check_palettes(Path(sys.argv[1]), appearance())

with tempfile.TemporaryDirectory(prefix="herdr-setup-") as tmp:
    root = Path(tmp)
    source, home = root / "source", root / "home"
    source.mkdir()
    home.mkdir()
    config, state = root / "config/chezmoi.toml", root / "state/chezmoi.db"
    config.parent.mkdir()
    state.parent.mkdir()
    config.write_text("")
    for name in (".chezmoiignore", ".chezmoiremove", "settings.toml"):
        shutil.copyfile(repo / name, source / name)
    shutil.copytree(app_source, source / "private_dot_config/herdr-app")
    (source / "scripts").mkdir()
    shutil.copy2(repo / "scripts/theme.py", source / "scripts/theme.py")
    # Read the real theme inputs without copying or changing the catalog.
    for name in ("themes", "themes-local"):
        if (repo / name).is_dir():
            (source / name).symlink_to(repo / name, target_is_directory=True)
    command = [
        "chezmoi", "--config", str(config), "--source", str(source),
        "--destination", str(home), "--persistent-state", str(state), "--no-tty", "--force",
    ]

    def run(*args, extra=None, ignored_parent=False):
        result = subprocess.run(command + list(args), capture_output=True, text=True,
                                env={**environment, **(extra or {})})
        # Explicit imports below an ignored directory can be refused rather
        # than silently skipped. Both outcomes must leave the source untouched.
        refused = (
            ignored_parent
            and "ignoring" in result.stderr
            and "parent directory not in source state" in result.stderr
        )
        assert result.returncode == 0 or refused, (args, result.stdout, result.stderr)
        return result.stdout

    # Fresh install supplies both palettes and system following, not core payloads.
    run("apply")
    baseline = appearance()
    check_palettes(home, baseline)
    assert not (home / ".config/herdr").exists()
    assert not (home / ".config/herdr-core").exists()
    assert not (home / ".pi/agent/extensions/herdr-agent-state.ts").exists()

    # Both pins are enforced independently of the OS. Both palettes always exist.
    original_settings = (repo / "settings.toml").read_text()
    for mode in ("light", "dark", "system"):
        settings = root / f"settings-{mode}.toml"
        settings.write_text(re.sub(r'^theme = ".*"$', f'theme = "{mode}"', original_settings, flags=re.M))
        extra = {"DOTFILES_SETTINGS_FILE": str(settings)}
        run("apply", extra=extra)
        check_palettes(home, appearance(extra))
        assert run("diff", extra=extra) == "", f"{mode}: second apply is not clean"

    # Swapping names must regenerate the palettes, not leave a cached pair.
    swapped = root / "settings-swapped.toml"
    swapped_text = original_settings
    swapped_text = re.sub(r'^light_theme = ".*"$', f'light_theme = "{baseline["dark_theme"]}"', swapped_text, flags=re.M)
    swapped_text = re.sub(r'^dark_theme = ".*"$', f'dark_theme = "{baseline["light_theme"]}"', swapped_text, flags=re.M)
    swapped.write_text(swapped_text)
    extra = {"DOTFILES_SETTINGS_FILE": str(swapped)}
    run("apply", extra=extra)
    check_palettes(home, appearance(extra))

    # Sparse custom themes must use resolver fallbacks for all omitted ANSI slots.
    custom = root / "custom-themes"
    custom.mkdir()
    for side in ("light", "dark"):
        terminal = baseline[side]["terminal"]
        (custom / baseline[f"{side}_theme"]).write_text(
            f'background = {terminal["background"]}\nforeground = {terminal["foreground"]}\n'
            f'palette = 1={terminal["palette_1"]}\n'
        )
    extra = {"DOTFILES_THEMES": str(custom)}
    run("apply", extra=extra)
    check_palettes(home, appearance(extra))
    run("apply")

    # Upgrade removes only obsolete config/integration, not sessions or user files.
    retired = [".config/herdr/config.toml", ".pi/agent/extensions/herdr-agent-state.ts"]
    preserved = {
        ".config/herdr/session.json": "legacy live session\n",
        ".config/herdr/herdr.log": "legacy log\n",
        ".pi/agent/extensions/user-extension.ts": "user extension\n",
        ".config/herdr-app/keys.json": '{"global":{"cmd-x":"app.quit"}}\n',
        ".config/herdr-app/shared.json": '{"layout":"personal"}\n',
        ".config/herdr-app/view.json": '{"focused":"local-pane"}\n',
        ".config/herdr-app/window.json": '{"width":1234}\n',
        ".config/herdr-app/installed.json": '{"installed":"app-owned"}\n',
        ".config/herdr-app/layouts/.state/main.json": '{"width":345}\n',
        ".config/herdr-app/mods/personal/main.js": "// personal mod\n",
        ".config/herdr-app/themes/personal.json": '{"custom":"user theme"}\n',
        ".config/herdr-core/config.toml": "notes = false\n",
        ".config/herdr-core/machines.json": '{"private":"machine identity"}\n',
        ".local/state/herdr-core/default/session.json": "live core session\n",
        ".local/share/herdr-core/releases/core": "installed core bundle\n",
        ".local/bin/hc": "core CLI\n",
        ".local/bin/herdr-core": "core executable\n",
        ".local/bin/herdr-app": "desktop CLI\n",
    }
    for name, content in {**preserved, **dict.fromkeys(retired, "obsolete\n")}.items():
        path = home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    (home / ".config/herdr-app/settings.json").write_text('{"telemetry":true,"appearance":"dark","zoom":2}\n')
    (home / ".config/herdr-app/themes/dotfiles-light.json").write_text('{}\n')
    run("apply")
    for name in retired:
        assert not (home / name).exists(), f"legacy file survived: {name}"
    for name, content in preserved.items():
        assert (home / name).read_text() == content, f"unrelated state changed: {name}"
    check_palettes(home, baseline)
    assert run("diff") == "", "upgrade: second apply is not clean"

    # Recursive AND explicit imports allow just settings and the generated pair.
    imports = root / "imports"
    imports.mkdir()
    shutil.copyfile(repo / ".chezmoiignore", imports / ".chezmoiignore")
    command[command.index(str(source))] = str(imports)
    for name in (
        ".config/herdr-app", ".config/herdr-core", ".config/herdr",
        ".local/state/herdr-core", ".local/share/herdr-core",
    ):
        run("add", str(home / name))
    for name in preserved:
        if "herdr" in name or name == ".local/bin/hc":
            run("add", str(home / name), ignored_parent=True)
    imported = [path for path in imports.rglob("*") if path.is_file()]
    assert sorted(path.name for path in imported) == [
        ".chezmoiignore", "dotfiles-dark.json", "dotfiles-light.json", "settings.json",
    ], imported
    imported_settings = next(path for path in imported if path.name == "settings.json")
    assert json.loads(imported_settings.read_text())["telemetry"] is False

print("PASS: Herdr system/light/dark palettes, regeneration, sparse themes, cleanup, import boundaries")
