# SSH address book

`private_dot_ssh/private_hosts.conf` installs `~/.ssh/hosts.conf` on the Macs.
It is an address book: aliases, destination usernames, hostnames, and host-key
names, not credentials or server authorization. Keeping it here makes `ssh mm`,
`ssh air`, and `ssh rpi` resolve consistently on both Macs.

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

Configure daily fleet aliases explicitly with the client's local private key
and `IdentitiesOnly yes`. The Air currently uses `id_ed25519`; the mini uses
its independent 4096-bit `id_rsa`. Do not copy a private key between clients.
Do not put an `IdentityFile` under `Host *`, because identity entries accumulate
and can leak daily identities into emergency profiles.

Emergency aliases use a public-key selector (`breakglass.pub`) and a separately
configured 1Password agent. A client without a supported/unlocked recovery
agent must not silently use a daily key instead. Keep agent forwarding off.

`HostKeyAlias` uses the server's canonical Tailscale hostname even for LAN
connections. Verify the server's fingerprint before enrollment; never bypass
host-key checking. The LAN routes are explicit alternatives, not automatic
failover. Their addresses need rechecking if DHCP changes.

## Scope and verification

This repo remains macOS-only. It does not install an SSH server, edit
`authorized_keys`, manage tailnet policy, or install dotfiles on the Pi. The
portable address-book file can be copied separately to another SSH client;
that does not make the rest of this repo a Linux configuration.

The detailed rollout, recovery procedures, phone instructions, and current
verification record are maintained in `/Users/bp/gh/ssh-setup` on the Air.

After applying, check `ssh -G mm`, `ssh -G air`, and `ssh -G rpi` for effective
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
history belong in this repo. Run the normal dotfiles verification runbook
after changes.
