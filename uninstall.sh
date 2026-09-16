#!/usr/bin/env bash
set -euo pipefail

# Remove the blocker and restore previous DNS / hosts settings.
PLIST="/Library/LaunchDaemons/com.local.dnsblocker.plist"

echo "==> Stopping and removing the dnsmasq daemon"
sudo -p "Administrator password: " sh -c '
launchctl bootout system/com.local.dnsblocker 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.local.dnsblocker.plist
'

echo "==> Restoring DNS servers to automatic"
for svc in Wi-Fi Thunderbolt Bridge Ethernet; do
  networksetup -setdnsservers "$svc" Empty 2>/dev/null || true
done

echo "==> Restoring original /etc/hosts"
if [ -f /etc/hosts.pre-dnsblocker.bak ]; then
  sudo -p "Administrator password: " cp -p /etc/hosts.pre-dnsblocker.bak /etc/hosts
  sudo -p "Administrator password: " chown root:wheel /etc/hosts
  sudo -p "Administrator password: " chmod 644 /etc/hosts
else
  echo "  (no pre-install backup found; leaving current /etc/hosts untouched)"
fi

sudo -p "Administrator password: " dscacheutil -flushcache
sudo -p "Administrator password: " killall -HUP mDNSResponder || true

echo "Done. Blocking removed, DNS restored to automatic (DHCP)."