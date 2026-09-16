#!/usr/bin/env bash
set -euo pipefail

# mac-content-blocker — one-shot installer.
# Blocks adult, torrent/piracy, malware, phishing, scam, ransomware and
# malicious URL domains system-wide by running dnsmasq as a local DNS server.
# Run from the repo root:  bash setup.sh
# Sections needing root (daemon install, DNS change) are run via sudo.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BLOCK_DIR="/opt/homebrew/etc/dnsmasq-blocks"
DNSMASQ_CONF="/opt/homebrew/etc/dnsmasq.conf"
PLIST="/Library/LaunchDaemons/com.local.dnsblocker.plist"
DNSMASQ_BIN="/opt/homebrew/opt/dnsmasq/sbin/dnsmasq"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Checking prerequisites"
command -v brew >/dev/null 2>&1 || { echo "ERROR: Homebrew is required"; exit 1; }
if [ ! -x "$DNSMASQ_BIN" ]; then
  echo "==> Installing dnsmasq via Homebrew"
  brew install dnsmasq
fi

echo "==> Downloading blocklists"
curl -fsSL --max-time 120 -o "$WORK/porn-sb.hosts" \
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
curl -fsSL --max-time 120 -o "$WORK/torrent-blp.txt" \
  "https://raw.githubusercontent.com/blocklistproject/Lists/main/torrent.txt"
curl -fsSL --max-time 120 -o "$WORK/torrent-ndns.txt" \
  "https://raw.githubusercontent.com/nextdns/piracy-blocklists/master/torrent-websites"
curl -fsSL --max-time 240 -o "$WORK/malware.txt" \
  "https://raw.githubusercontent.com/blocklistproject/Lists/main/malware.txt"
curl -fsSL --max-time 120 -o "$WORK/phishing.txt" \
  "https://raw.githubusercontent.com/blocklistproject/Lists/main/phishing.txt"
curl -fsSL --max-time 120 -o "$WORK/scam.txt" \
  "https://raw.githubusercontent.com/blocklistproject/Lists/main/scam.txt"
curl -fsSL --max-time 120 -o "$WORK/ransomware.txt" \
  "https://raw.githubusercontent.com/blocklistproject/Lists/main/ransomware.txt"
curl -fsSL --max-time 120 -o "$WORK/phishingarmy.txt" \
  "https://phishing.army/download/phishing_army_blocklist_extended.txt"
curl -fsSL --max-time 120 -o "$WORK/urlhaus.txt" \
  "https://urlhaus.abuse.ch/downloads/hostfile/"

echo "==> Fetching Bon-Appetit porn-domains (block + allow)"
BA_CLONE="$WORK/ba"
git clone -q --depth 1 https://github.com/Bon-Appetit/porn-domains "$BA_CLONE"
BA_BLOCK="$(ls "$BA_CLONE"/block.*.txt | head -1)"
BA_ALLOW="$(ls "$BA_CLONE"/allow.*.txt | head -1)"
[ -n "$BA_BLOCK" ] && [ -n "$BA_ALLOW" ] || { echo "ERROR: Bon-Appetit lists not found"; exit 1; }
cp "$BA_BLOCK" "$WORK/ba-block.txt"
cp "$BA_ALLOW" "$WORK/ba-allow.txt"

echo "==> Building blocked-hosts files"
WORK="$WORK" OUT="$BLOCK_DIR" python3 "$REPO_DIR/src/build_lists.py"

echo "==> Writing dnsmasq configuration"
cat > "$DNSMASQ_CONF" <<'CONF'
port=53
listen-address=127.0.0.1
bind-interfaces
no-resolv
server=1.1.1.1
server=8.8.8.8
server=9.9.9.9
cache-size=10000
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/porn.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/torrent.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/malware.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/phishing.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/scam.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/ransomware.hosts
addn-hosts=/opt/homebrew/etc/dnsmasq-blocks/urlhaus.hosts
CONF

echo "==> Testing dnsmasq configuration"
"$DNSMASQ_BIN" --test -C "$DNSMASQ_CONF"

cat > "$WORK/system.sh" <<'SH'
#!/bin/sh
set -e
PLIST="/Library/LaunchDaemons/com.local.dnsblocker.plist"
DNSMASQ_BIN="/opt/homebrew/opt/dnsmasq/sbin/dnsmasq"
DNSMASQ_CONF="/opt/homebrew/etc/dnsmasq.conf"

# Back up the current hosts file once (restore target for uninstall).
if [ ! -f /etc/hosts.pre-dnsblocker.bak ]; then
  cp -p /etc/hosts /etc/hosts.pre-dnsblocker.bak
fi

# Keep /etc/hosts at the standard macOS defaults (localhost entries only).
cat > /etc/hosts <<'HOSTS'
##
# Host Database
#
# localhost is used to configure the loopback interface
# when the system is booting.  Do not change this entry.
##
127.0.0.1	localhost
255.255.255.255	broadcasthost
::1             localhost
HOSTS
chown root:wheel /etc/hosts
chmod 644 /etc/hosts

cat > "$PLIST" <<'PL'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.dnsblocker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/opt/dnsmasq/sbin/dnsmasq</string>
    <string>--keep-in-foreground</string>
    <string>-C</string>
    <string>/opt/homebrew/etc/dnsmasq.conf</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
PL

launchctl bootout system/com.local.dnsblocker 2>/dev/null || true
launchctl bootstrap system "$PLIST"

ok=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if nc -z 127.0.0.1 53 2>/dev/null; then ok=1; break; fi
  sleep 1
done
[ "$ok" = 1 ] || { echo "ERROR: dnsmasq did not bind :53"; exit 1; }

for svc in Wi-Fi Thunderbolt Bridge Ethernet; do
  networksetup -setdnsservers "$svc" 127.0.0.1 2>/dev/null || true
done

dscacheutil -flushcache
killall -HUP mDNSResponder || true
SH
chmod +x "$WORK/system.sh"
echo "==> Installing system service (sudo password may be requested)"
sudo -p "Administrator password: " "/bin/sh" "$WORK/system.sh"

echo "==> Verification"
echo "blocked pornhub.com -> $(dig +short pornhub.com | head -1)"
echo "blocked 1337x.to -> $(dig +short 1337x.to | head -1)"
echo "normal apple.com -> $(dig +short apple.com | head -1)"
echo "normal wikipedia.org -> $(dig +short wikipedia.org | head -1)"
echo "Done. Blocking is active system-wide and persists across reboots."