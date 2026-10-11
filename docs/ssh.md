# SSH address book

`private_dot_ssh/private_hosts.conf` installs `~/.ssh/hosts.conf` on the Macs.
It is an address book: aliases, destination usernames, hostnames, and host-key
names, not credentials or server authorization. Keeping it here makes `ssh mm`
and `ssh rpi` resolve consistently on both Macs. This configures outbound SSH
client behavior, including on a Mac that also accepts inbound SSH.

## Ownership

| Responsibility | Source of truth |
| --- | --- |
| Mac terminal environment, shared SSH aliases, and offline config tests | This dotfiles repo |
| Device roles, network expectations, enrollment, server hardening, recovery, and live verification records | Private [ssh-setup](https://github.com/brucepucci/ssh-setup) runbook |
| Client keys/agents/trust and server authorization | Local configuration or credential store; neither repo deploys them |

Start infrastructure work at [ssh-setup's README](https://github.com/brucepucci/ssh-setup/blob/main/README.md)
and [onboarding guide](https://github.com/brucepucci/ssh-setup/blob/main/ONBOARDING.md).
Those links require access to the private repo. It is not a dependency of
`chezmoi apply`. Keep operational procedures there, not duplicated here.

The private source prefix controls file permissions; it does **not** encrypt
anything or make a committed file secret. This address book contains public
configuration but reveals personal infrastructure metadata.

## Client-local settings

`~/.ssh/config` is intentionally unmanaged: each client owns its existing keys,
agent setup, and other hosts. Include the shared file near the top:

```sshconfig
Include ~/.ssh/hosts.conf
Host *
```

The `Host *` reset matters: an included file ends in a host block. Without a
reset, following settings can accidentally belong to that last block.

Configure daily fleet aliases explicitly with the client's own local private
key and `IdentitiesOnly yes`; do not copy keys between clients. Do not put an
`IdentityFile` under `Host *`, because identity entries accumulate and can leak
daily identities into emergency profiles. Keep agent forwarding off.

Emergency aliases need separate local identity/agent profiles; an alias alone
does not provide recovery access. They must not silently fall back to daily
keys. Client-specific key choices, public selectors, 1Password setup, and
recovery procedures belong in [ssh-setup's credential plan](https://github.com/brucepucci/ssh-setup/blob/main/PLAN.md#5-server-specific-1password-rescue-keys).

`HostKeyAlias` uses the server's canonical Tailscale hostname even for LAN
connections. Verify the server's fingerprint before enrollment; never bypass
host-key checking. The LAN routes are explicit alternatives, not automatic
failover. Their addresses need rechecking if DHCP changes.

## Scope and verification

This repo remains macOS-only. It does not install an SSH server, edit
`authorized_keys`, manage tailnet policy, or install dotfiles on the Pi. A Pi
that only accepts inbound SSH does not need this address book or an outbound
client key. The portable address-book file can be copied separately if another
client is deliberately added; that does not make this a Linux configuration.

Applying dotfiles installs the address book but does not add the local
`Include` or enroll credentials. It does not alter Remote Login, `sshd`,
`authorized_keys`, firewall rules, or tailnet grants. On a Mac used only for
inbound SSH, the address book can remain unused; no outbound key is required.

Review `chezmoi diff` before applying the whole terminal configuration. When
applying remotely, keep the existing session open and prove a second login
works before closing it. Record per-host apply results in
[ssh-setup's status](https://github.com/brucepucci/ssh-setup/blob/main/STATUS.md),
separately from historical live SSH tests.

After applying, check `ssh -G mm` and `ssh -G rpi` for effective
hostname, user, key files, host-key alias, and agent forwarding. Then test real
public-key-only logins. Config expansion alone is not an authentication test.

Run the offline address-book check (no network or private keys required):

```sh
python3 scripts/test-ssh-address-book.py
```

It checks both Mac daily-key choices, all aliases, destination accounts,
canonical host-key names, and separation from emergency identities. It does
not prove that a server accepts a key or that a LAN address is reachable.

No private keys, SSH backups, server authorization files, or known-hosts
history belong in this repo. `.chezmoiignore` excludes everything under `.ssh`
except `hosts.conf`, including custom-named credentials and nested backups.
The smoke test runs `scripts/test-ssh-import-boundary.py` with a disposable
private key to verify recursive and explicit imports cannot copy it into the
source tree, while the address book still installs with private permissions.
Run the normal dotfiles verification runbook after changes.
