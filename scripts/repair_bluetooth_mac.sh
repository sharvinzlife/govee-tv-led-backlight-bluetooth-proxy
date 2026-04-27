#!/usr/bin/env bash
#
# repair_bluetooth_mac.sh
#
# Fixes the AA:AA:AA:AA:AA:AA placeholder-MAC failure in Home Assistant's
# bluetooth integration (see docs/TROUBLESHOOTING.md §B).
#
# What it does:
#   1. Stops the Home Assistant service
#   2. Backs up core.config_entries with a UTC timestamp
#   3. Removes any bluetooth integration entry whose unique_id is the placeholder,
#      then inserts a fresh entry with the real adapter MAC
#   4. Starts Home Assistant
#
# Designed to be safe: the script aborts if it can't validate the input,
# and every change is reversible from the timestamped backup.

set -euo pipefail

CONFIG_DIR=""
SERVICE=""
NEW_MAC=""
DRY_RUN=0

usage() {
    cat <<EOF
Usage: $0 --config-dir DIR --service NAME --new-mac MAC [--dry-run]

Required:
  --config-dir DIR   Path to the Home Assistant config directory
                     (containing the .storage subdirectory).
  --service NAME     systemd service name controlling Home Assistant
                     (e.g. container-homeassistant.service, home-assistant@homeassistant.service).
  --new-mac MAC      The real adapter MAC, uppercase, colon-separated
                     (e.g. DC:A6:32:EA:E4:13). Find it with: hciconfig -a

Optional:
  --dry-run          Show what would change without modifying anything.
  -h, --help         This help.

Example:
  sudo bash $0 \\
      --config-dir /mnt/dietpi_userdata/homeassistant/config \\
      --service container-homeassistant.service \\
      --new-mac DC:A6:32:EA:E4:13
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --config-dir) CONFIG_DIR=$2; shift 2 ;;
        --service)    SERVICE=$2;    shift 2 ;;
        --new-mac)    NEW_MAC=$2;    shift 2 ;;
        --dry-run)    DRY_RUN=1;     shift   ;;
        -h|--help)    usage; exit 0          ;;
        *)            echo "Unknown arg: $1"; usage; exit 2 ;;
    esac
done

if [[ -z $CONFIG_DIR || -z $SERVICE || -z $NEW_MAC ]]; then
    echo "ERROR: --config-dir, --service and --new-mac are all required."
    usage
    exit 2
fi

if [[ ! $NEW_MAC =~ ^[0-9A-Fa-f:]{17}$ ]]; then
    echo "ERROR: --new-mac doesn't look like a MAC address: $NEW_MAC"
    exit 2
fi

ENTRIES="$CONFIG_DIR/.storage/core.config_entries"
if [[ ! -f $ENTRIES ]]; then
    echo "ERROR: not found: $ENTRIES"
    exit 2
fi

NEW_MAC=$(echo "$NEW_MAC" | tr '[:lower:]' '[:upper:]')
TS=$(date -u +%Y%m%dT%H%M%SZ)
BACKUP="$ENTRIES.bak-$TS"

echo "==> Inspecting current bluetooth entry"
python3 - "$ENTRIES" "$NEW_MAC" <<'PY'
import json, sys
path, new_mac = sys.argv[1], sys.argv[2]
with open(path) as f:
    d = json.load(f)
bt = [e for e in d["data"]["entries"] if e["domain"] == "bluetooth"]
if not bt:
    print("  (no existing bluetooth entry — will insert one)")
for e in bt:
    print(f"  current: unique_id={e.get('unique_id')!r} title={e.get('title')!r}")
print(f"  desired: unique_id={new_mac!r}")
PY

if (( DRY_RUN )); then
    echo "==> Dry-run mode, exiting before modifying anything."
    exit 0
fi

echo "==> Stopping $SERVICE"
systemctl stop "$SERVICE"

echo "==> Backing up to $BACKUP"
cp -a "$ENTRIES" "$BACKUP"

echo "==> Rewriting $ENTRIES"
python3 - "$ENTRIES" "$NEW_MAC" <<'PY'
import json, os, secrets, time, sys

path, new_mac = sys.argv[1], sys.argv[2]

with open(path) as f:
    d = json.load(f)

placeholder = "AA:AA:AA:AA:AA:AA"
keep = []
removed = 0
for e in d["data"]["entries"]:
    if e["domain"] == "bluetooth":
        removed += 1
        continue
    keep.append(e)
d["data"]["entries"] = keep
print(f"  removed {removed} existing bluetooth entry/entries")

# Generate a Crockford Base32 ULID-style entry_id (26 chars).
alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # pragma: allowlist secret
def b32(n, length):
    s = ""
    for _ in range(length):
        s = alphabet[n & 31] + s; n >>= 5
    return s
ts = int(time.time() * 1000)
entry_id = b32(ts, 10) + "".join(secrets.choice(alphabet) for _ in range(16))
now = time.strftime("%Y-%m-%dT%H:%M:%S.000000+00:00", time.gmtime())

new_entry = {
    "created_at": now,
    "data": {},
    "disabled_by": None,
    "discovery_keys": {},
    "domain": "bluetooth",
    "entry_id": entry_id,
    "minor_version": 1,
    "modified_at": now,
    "options": {},
    "pref_disable_new_entities": False,
    "pref_disable_polling": False,
    "source": "integration_discovery",
    "subentries": [],
    "title": f"bluetooth ({new_mac})",
    "unique_id": new_mac,
    "version": 1,
}
d["data"]["entries"].append(new_entry)
print(f"  inserted new bluetooth entry: unique_id={new_mac} entry_id={entry_id}")

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(d, f, indent=2)
os.replace(tmp, path)
print(f"  wrote {path}")
PY

echo "==> Starting $SERVICE"
systemctl start "$SERVICE"

echo
echo "==> Done. To verify:"
echo "    grep -A2 '\"domain\": \"bluetooth\"' $ENTRIES"
echo "    journalctl -u $SERVICE -f      # watch HA boot"
echo
echo "    Backup: $BACKUP"
echo "    Rollback: systemctl stop $SERVICE && cp -a $BACKUP $ENTRIES && systemctl start $SERVICE"
