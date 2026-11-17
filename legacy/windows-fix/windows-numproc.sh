#!/bin/bash
# Limit Windows to its first N logical processors (default 6 = cores 0-2),
# by editing the Windows BCD on the Windows EFI partition from Ubuntu.
#
#   sudo ./windows-numproc.sh show      # just look, change nothing
#   sudo ./windows-numproc.sh set 6     # Windows uses threads 0-5 only
#   sudo ./windows-numproc.sh remove    # back to all 16 threads
#   sudo ./windows-numproc.sh restore   # put back the very first backup
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)
cmd=${1:-show}

ESP=/dev/disk/by-partuuid/82ccf0c1-0cd4-4011-b03e-b5a6a3df0af5   # Windows "SYSTEM" partition
BACKUPS=/var/backups/windows-bcd
MNT=/mnt/windows-esp

python3 -c "import hivex" 2>/dev/null || { echo "Installing python3-hivex (BCD editor) from Ubuntu's repository..."; apt-get install -y python3-hivex >/dev/null; }

mkdir -p "$MNT" "$BACKUPS"
mountpoint -q "$MNT" || mount -t vfat "$ESP" "$MNT"
trap 'sync; umount "$MNT" 2>/dev/null || true' EXIT
BCD="$MNT/EFI/Microsoft/Boot/BCD"
[ -f "$BCD" ] || { echo "No BCD found at $BCD"; exit 1; }

# Keep the untouched original forever, plus a copy before every change.
[ -e "$BACKUPS/BCD.original" ] || cp "$BCD" "$BACKUPS/BCD.original"

case "$cmd" in
  show)
    python3 -I "$here/bcd_numproc.py" "$BCD" show ;;
  set|remove)
    cp "$BCD" "$BACKUPS/BCD.$(date +%Y%m%d-%H%M%S)"
    work=$(mktemp)
    cp "$BCD" "$work"
    python3 -I "$here/bcd_numproc.py" "$work" "$cmd" ${2:-}
    cp "$work" "$BCD"; rm -f "$work"
    echo "Written to the Windows EFI partition. Read back:"
    python3 -I "$here/bcd_numproc.py" "$BCD" show ;;
  restore)
    cp "$BACKUPS/BCD.original" "$BCD"
    echo "Original BCD restored."
    python3 -I "$here/bcd_numproc.py" "$BCD" show ;;
  *) echo "usage: $0 show|set N|remove|restore"; exit 1 ;;
esac

echo
echo "CPU order the firmware gives Windows (APIC IDs; Linux core 3 = IDs 6 and 7):"
python3 -I - <<'EOF'
import struct
d = open("/sys/firmware/acpi/tables/APIC", "rb").read()
i, order = 44, []
while i < len(d):
    t, l = d[i], d[i + 1]
    if t == 0:   order.append((d[i + 3], struct.unpack("<I", d[i + 4:i + 8])[0] & 1))
    elif t == 9: order.append((struct.unpack("<I", d[i + 4:i + 8])[0], struct.unpack("<I", d[i + 8:i + 12])[0] & 1))
    i += l
print("  " + " ".join(f"{a}{'' if e else '(off)'}" for a, e in order))
print("  numproc=6 keeps the first 6 of these:", [a for a, e in order if e][:6])
EOF
