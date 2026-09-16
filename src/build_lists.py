import os
import re

# Builds per-category hosts files for dnsmasq from downloaded blocklists.
# Input: WORK = dir holding the raw downloaded list files
# Output: OUT = dir where *.hosts files are written (default /opt/homebrew/etc/dnsmasq-blocks)

WORK = os.environ.get("WORK", "/tmp/dnsblock-sources")
OUT = os.environ.get("OUT", "/opt/homebrew/etc/dnsmasq-blocks")

BA_BLOCK = os.path.join(WORK, os.environ.get("BA_BLOCK", "").strip() or "ba-block.txt")
BA_ALLOW = os.path.join(WORK, "ba-allow.txt")
SB = os.path.join(WORK, "porn-sb.hosts")
BLP_T = os.path.join(WORK, "torrent-blp.txt")
NDNS_T = os.path.join(WORK, "torrent-ndns.txt")
BLP_MAL = os.path.join(WORK, "malware.txt")
BLP_PHISH = os.path.join(WORK, "phishing.txt")
BLP_SCAM = os.path.join(WORK, "scam.txt")
BLP_RANSOM = os.path.join(WORK, "ransomware.txt")
PA = os.path.join(WORK, "phishingarmy.txt")
UH = os.path.join(WORK, "urlhaus.txt")

DNL = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$")

TORRENT_LEGIT = {
    "archive.org", "mit.edu", "nasa.gov", "pbs.org",
    "pentagonchannel.mil", "berkeley.edu", "opera.com",
    "sourceforge.net", "uni-kl.de",
}


def norm_domain(line, hosts_format=False, adblock=False):
    if adblock:
        line = line.strip()
        if not line.startswith("||") or not line.endswith("^"):
            return None
        line = line[2:-1]
    elif hosts_format:
        parts = line.split()
        if len(parts) != 2 or parts[0] not in ("0.0.0.0", "127.0.0.1"):
            return None
        line = parts[1]
    else:
        line = line.split("#", 1)[0]
    d = line.strip().strip(".").lower()
    if not d or len(d) > 253 or not DNL.fullmatch(d):
        return None
    return d


def load(path, hosts_format=False, adblock=False):
    if not os.path.exists(path):
        raise SystemExit("source file missing: %s" % path)
    out = set()
    with open(path, encoding="utf-8", errors="ignore") as f:
        for raw in f:
            d = norm_domain(raw, hosts_format, adblock)
            if d:
                out.add(d)
    return out


def suffix_protected(d, protected):
    s = d
    while s:
        if s in protected:
            return True
        dot = s.find(".")
        if dot < 0:
            break
        s = s[dot + 1:]
    return False


EduGovMil = re.compile(r"^[a-z0-9-]+\.(edu|gov|mil)$")


def edu_gov_mil_related(d):
    s = d
    while s:
        if EduGovMil.fullmatch(s):
            return True
        dot = s.find(".")
        if dot < 0:
            break
        s = s[dot + 1:]
    return False


def write_hosts(name, domains):
    if not os.path.exists(OUT):
        os.makedirs(OUT)
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        for d in sorted(domains):
            f.write("0.0.0.0 %s\n" % d)
    return len(domains)


porn = load(SB, hosts_format=True) | load(BA_BLOCK)
ba_allow = load(BA_ALLOW)
porn = {d for d in porn if not suffix_protected(d, ba_allow)}

torrent = load(BLP_T, hosts_format=True) | load(NDNS_T)
torrent = {d for d in torrent if not suffix_protected(d, TORRENT_LEGIT)}

malware = {d for d in load(BLP_MAL, hosts_format=True) if not edu_gov_mil_related(d)}
phishing = {d for d in (load(BLP_PHISH, hosts_format=True) | load(PA, adblock=True)) if not edu_gov_mil_related(d)}
scam = {d for d in load(BLP_SCAM, hosts_format=True) if not edu_gov_mil_related(d)}
ransom = {d for d in load(BLP_RANSOM, hosts_format=True) if not edu_gov_mil_related(d)}
urlhaus = {d for d in load(UH, hosts_format=True) if not edu_gov_mil_related(d)}

report = {
    "porn.hosts": write_hosts("porn.hosts", porn),
    "torrent.hosts": write_hosts("torrent.hosts", torrent),
    "malware.hosts": write_hosts("malware.hosts", malware),
    "phishing.hosts": write_hosts("phishing.hosts", phishing),
    "scam.hosts": write_hosts("scam.hosts", scam),
    "ransomware.hosts": write_hosts("ransomware.hosts", ransom),
    "urlhaus.hosts": write_hosts("urlhaus.hosts", urlhaus),
}
for k, v in report.items():
    print("%-18s %d" % (k, v))
print("TOTAL", sum(report.values()))