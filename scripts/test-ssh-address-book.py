#!/usr/bin/env python3
"""Offline checks for aliases, host identities, and credential separation."""
from pathlib import Path
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parents[1]
book = Path(sys.argv[1]) if len(sys.argv) > 1 else source / "private_dot_ssh/private_hosts.conf"
regular = "mm mini rpi o3c-pi mm-lan mini-lan rpi-lan o3c-pi-wifi rpi-eth o3c-pi-eth"
mini = "bruces-mac-mini.cyprus-temperature.ts.net"
pi = "o3c-pi.cyprus-temperature.ts.net"
expected = {
    "mm": (mini, mini, "brucepucci"),
    "mini": (mini, mini, "brucepucci"),
    "rpi": (pi, pi, "brucepucci"),
    "o3c-pi": (pi, pi, "brucepucci"),
    "mm-lan": ("192.168.1.64", mini, "brucepucci"),
    "mini-lan": ("192.168.1.64", mini, "brucepucci"),
    "rpi-lan": ("192.168.4.25", pi, "brucepucci"),
    "o3c-pi-wifi": ("192.168.4.25", pi, "brucepucci"),
    "rpi-eth": ("192.168.1.220", pi, "brucepucci"),
    "o3c-pi-eth": ("192.168.1.220", pi, "brucepucci"),
}

with tempfile.TemporaryDirectory(prefix="ssh-address-book-") as tmp:
    cfg = Path(tmp) / "config"
    for daily in ("id_ed25519", "id_rsa"):
        cfg.write_text(
            f'Include "{book}"\n'
            f"Host {regular}\n"
            f"    IdentityFile ~/.ssh/{daily}\n"
            "    IdentitiesOnly yes\n"
            "    PreferredAuthentications publickey\n"
            "Host mm-breakglass mini-breakglass mm-lan-breakglass mini-lan-breakglass\n"
            "    IdentityFile ~/.ssh/breakglass.pub\n"
            "Host rpi-breakglass o3c-pi-breakglass rpi-lan-breakglass o3c-pi-wifi-breakglass rpi-eth-breakglass o3c-pi-eth-breakglass\n"
            "    IdentityFile ~/.ssh/breakglass-rpi.pub\n"
            "Host *-breakglass\n"
            "    IdentityAgent none\n"
            "    IdentitiesOnly yes\n"
            "    PreferredAuthentications publickey\n"
            "Host *\n"
            "    ForwardAgent no\n"
        )
        for alias, (hostname, hostkeyalias, user) in expected.items():
            for emergency in (False, True):
                name = alias + ("-breakglass" if emergency else "")
                output = subprocess.check_output(
                    ["ssh", "-F", str(cfg), "-G", name],
                    text=True, stderr=subprocess.DEVNULL,
                )
                values = {}
                for line in output.splitlines():
                    key, value = line.split(" ", 1)
                    values.setdefault(key, []).append(value)
                for key, value in {
                    "hostname": hostname,
                    "hostkeyalias": hostkeyalias,
                    "user": user,
                    "identitiesonly": "yes",
                    "preferredauthentications": "publickey",
                    "forwardagent": "no",
                }.items():
                    assert values.get(key) == [value], (name, key, values.get(key))
                identity = ("breakglass.pub" if hostkeyalias == mini else "breakglass-rpi.pub") if emergency else daily
                assert values["identityfile"] == [f"~/.ssh/{identity}"], (name, values["identityfile"])
                if emergency:
                    assert values["identityagent"] == ["none"], name

print("PASS: all aliases, canonical host identities, account names, and isolated daily/emergency identities")
