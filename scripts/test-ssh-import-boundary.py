#!/usr/bin/env python3
"""Ensure recursive SSH imports manage only hosts.conf, never local credentials."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="ssh-import-boundary-") as tmp:
    root = Path(tmp)
    source = root / "source"
    home = root / "home"
    ssh = home / ".ssh"
    config = root / "config" / "chezmoi.toml"
    state = root / "state" / "chezmoi.db"
    for directory in (source, ssh, config.parent, state.parent):
        directory.mkdir(parents=True)
    config.write_text("")
    (source / ".chezmoiignore").write_text((repo / ".chezmoiignore").read_text())
    ssh.chmod(0o700)
    book = (repo / "private_dot_ssh/private_hosts.conf").read_text()
    (ssh / "hosts.conf").write_text(book)
    (ssh / "hosts.conf").chmod(0o600)

    # Use a real, disposable private key with a name the old denylist missed.
    subprocess.run(
        ["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(ssh / "work-github")],
        check=True,
    )
    backups = ssh / "backups"
    backups.mkdir()
    (backups / "custom-credential").write_bytes((ssh / "work-github").read_bytes())
    for name in ("config", "authorized_keys", "known_hosts", "hosts.conf.old", ".custom-secret"):
        (ssh / name).write_text("client-local data\n")

    command = [
        "chezmoi", "--config", str(config), "--source", str(source),
        "--destination", str(home), "--persistent-state", str(state), "--no-tty",
    ]

    def check_import_boundary():
        files = {str(path.relative_to(source)) for path in source.rglob("*") if path.is_file()}
        expected = {".chezmoiignore", "private_dot_ssh/private_hosts.conf"}
        assert files == expected, ("unexpected imported files", files - expected)
        assert (source / "private_dot_ssh/private_hosts.conf").read_text() == book

    # Exercise both the accidental bulk import and explicit custom-key imports.
    subprocess.run(command + ["add", str(ssh)], check=True, capture_output=True)
    check_import_boundary()
    for target in (ssh / "work-github", backups / "custom-credential"):
        subprocess.run(command + ["add", str(target)], check=True, capture_output=True)
        check_import_boundary()

    # The allowlist must not accidentally hide the address book on a fresh apply.
    fresh = root / "fresh-home"
    fresh.mkdir()
    subprocess.run(command + ["--destination", str(fresh), "apply"], check=True, capture_output=True)
    installed = {str(path.relative_to(fresh)) for path in fresh.rglob("*") if path.is_file()}
    assert installed == {".ssh/hosts.conf"}, installed
    assert (fresh / ".ssh/hosts.conf").read_text() == book
    assert (fresh / ".ssh").stat().st_mode & 0o777 == 0o700
    assert (fresh / ".ssh/hosts.conf").stat().st_mode & 0o777 == 0o600

print("PASS: SSH imports exclude custom private keys and local state; only hosts.conf installs")
