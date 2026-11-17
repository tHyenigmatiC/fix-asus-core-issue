#!/bin/bash
# Install (or update) the core3-fix command. Changes no settings by itself.
# Usage: sudo ./install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }
cd "$(dirname "$0")"

# Packages core3-fix needs (all from Ubuntu's own repositories):
#   python3        - helper scripts
#   python3-hivex  - reads/edits the Windows BCD (boot configuration)
#   mokutil        - reports whether Secure Boot is on
#   grub-efi-amd64-bin - GRUB's "acpi" module for the Windows 7-core entry
pkgs="python3 python3-hivex mokutil grub-efi-amd64-bin"
missing=$(for p in $pkgs; do dpkg -s "$p" >/dev/null 2>&1 || echo "$p"; done)
if [ -n "$missing" ]; then
    echo "Installing: $missing"
    apt-get update -qq
    apt-get install -y $missing
fi

dest=/usr/local/lib/core3-fix
mkdir -p "$dest/lib"
install -m 755 core3-fix "$dest/core3-fix"
install -m 644 README.md "$dest/README.md"
install -m 644 lib/*.py lib/*.service "$dest/lib/"
install -m 755 lib/skip-bad-core.sh "$dest/lib/"
chmod 755 "$dest"/lib/*.py
ln -sf "$dest/core3-fix" /usr/local/bin/core3-fix

# The old backups from the first scripts become part of core3-fix's backups.
if [ -d /var/backups/windows-bcd ]; then
    mkdir -p /var/backups/core3-fix
    cp -n /var/backups/windows-bcd/BCD.original /var/backups/windows-bcd/APIC.original /var/backups/core3-fix/ 2>/dev/null || true
fi

echo "Installed: $(command -v core3-fix)   (README: $dest/README.md)"
echo
core3-fix status
