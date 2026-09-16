# mac-content-blocker

System-wide content and threat blocking for macOS.

Blocks adult-content, torrent/piracy, malware, phishing, scam, ransomware and
malicious-URL domains across **all browsers and apps**, persistently across
reboots. Runs a local DNS resolver (dnsmasq) that null-routes blocked domains
and forwards everything else to upstream DNS normally. Legitimate sites are
left untouched.

## What it blocks

| Category                | Blocked | Sources |
|-------------------------|--------|---------|
| Adult / pornography     | 460k+  | StevenBlack porn-only, Bon-Appetit/porn-domains |
| Torrent / piracy        | ~4k    | blocklistproject torrent, NextDNS piracy (torrent-websites) |
| Malware distribution    | 2.6M+  | blocklistproject malware |
| Phishing               | 190k+  | blocklistproject phishing, phishing.army |
| Scam                    | ~9k    | blocklistproject scam |
| Ransomware              | ~2k    | blocklistproject ransomware |
| Malicious URLs          | ~400   | abuse.ch URLhaus |

### Safety guards (false-positive protection)

- Domains on Bon-Appetit's official *allow list* (legit sites that were
  incorrectly flagged) are never blocked.
- Well-known legitimate platform domains found in the torrent list
  (`archive.org`, `.edu/public` orgs such as `mit.edu`, `nasa.gov`, `pbs.org`,
  `berkeley.edu`, `opera.com`, `sourceforge.net`, `uni-kl.de`) are spared.
- Entries under `.edu/.gov/.mil` are excluded from the malware/phishing/scam
  lists so real university and government sites are never blocked.

## Requirements

- macOS with Homebrew + `curl`, `git`, `python3`, `networksetup`
  (all ship with macOS except Homebrew)
- Administrator rights (for the daemon install + DNS change). It uses the same
  technique as any DNS blocker: the system DNS is pointed at `127.0.0.1`.

## Install

```bash
bash setup.sh
```

`setup.sh` will: install dnsmasq, download all lists, build the block files,
install and start a `launchd` daemon (`com.local.dnsblocker`), point DNS at the
local resolver, and verify. One-time first DNS query after reboot is fast (this
replaces the slower /etc/hosts approach for large lists).

## Update lists

```bash
bash update.sh
```

Re-downloads everything and reloads the resolver without interrupting service.

## Uninstall

```bash
bash uninstall.sh
```

Removes the daemon, returns DNS to automatic, restores the pre-install
`/etc/hosts` backup (`/etc/hosts.pre-dnsblocker.bak`).

## Files

- `setup.sh` — full installer
- `update.sh` — refresh blocklists + reload
- `uninstall.sh` — revert all changes
- `src/build_lists.py` — normalizes/downloaded lists into dnsmasq hosts files

## Attribution

Criteria stripped/merged data from these excellent open projects:

- [StevenBlack/hosts](https://github.com/StevenBlack/hosts)
- [Bon-Appetit/porn-domains](https://github.com/Bon-Appetit/porn-domains)
  (CC-BY-SA-4.0)
- [blocklistproject/Lists](https://github.com/blocklistproject/Lists)
  (MIT / Unlicense)
- [nextdns/piracy-blocklists](https://github.com/nextdns/piracy-blocklists)
  (MIT)
- [Phishing Army](https://phishing.army/)
- [abuse.ch URLhaus](https://urlhaus.abuse.ch/) (CC-BY)

## Disclaimer

Blocklists are community-curated and can contain transient entries. This is
provided as-is; review `update.sh` sources if you rely on a specific site.