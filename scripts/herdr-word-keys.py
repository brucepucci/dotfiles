#!/usr/bin/env python3
"""Reconcile four word-editing chords without importing Herdr's keys file."""
import json
from pathlib import Path
import sys

WORD_KEYS = {
    "alt-left": "send:\x1bb",
    "alt-right": "send:\x1bf",
    "alt-backspace": "send:\x17",
    "alt-shift-backspace": "send:\x1bd",
}


def apply(home):
    path = home / ".config/herdr-app/keys.json"
    # Let first launch generate the vendor defaults. Never seed a partial file.
    if not path.exists():
        return
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a JSON object")
    terminal = data.get("terminal", {})
    if not isinstance(terminal, dict):
        raise ValueError(f"{path}: terminal bindings must be a JSON object")
    if all(terminal.get(key) == value for key, value in WORD_KEYS.items()):
        return
    terminal.update(WORD_KEYS)
    data["terminal"] = terminal
    path.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: herdr-word-keys.py DESTINATION_HOME")
    try:
        apply(Path(sys.argv[1]))
    except (OSError, ValueError) as error:
        sys.exit(f"herdr-word-keys: {error}")
