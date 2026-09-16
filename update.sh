#!/usr/bin/env bash
set -euo pipefail

# Refresh all blocklists and reload dnsmasq (no DNS outage).
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOCK_DIR="/opt/homebrew/etc/dnsmasq-blocks"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

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

BA_CLONE="$WORK/ba"
git clone -q --depth 1 https://github.com/Bon-Appetit/porn-domains "$BA_CLONE"
BA_BLOCK="$(ls "$BA_CLONE"/block.*.txt | head -1)"
BA_ALLOW="$(ls "$BA_CLONE"/allow.*.txt | head -1)"
cp "$BA_BLOCK" "$WORK/ba-block.txt"
cp "$BA_ALLOW" "$WORK/ba-allow.txt"

WORK="$WORK" OUT="$BLOCK_DIR" python3 "$REPO_DIR/src/build_lists.py"

sudo -p "Administrator password: " sh -c 'killall -HUP dnsmasq' || {
  echo "ERROR: reload failed"; exit 1
}

sleep 1
nc -z 127.0.0.1 53 || { echo "ERROR: resolver not listening"; exit 1; }
echo "Lists updated and resolver reloaded."