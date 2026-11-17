#!/bin/bash
# Run Ubuntu on 7 cores / 14 threads, skipping faulty core 3.
# Usage: sudo ./install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }
cd "$(dirname "$0")"

install -m 755 skip-bad-core.sh      /usr/local/sbin/skip-bad-core.sh
install -m 644 skip-bad-core.service /etc/systemd/system/skip-bad-core.service
systemctl daemon-reload
systemctl enable skip-bad-core.service

# Boot on cores 0-2 only so core 3 never starts; the service adds the rest.
g=/etc/default/grub
[ -e "$g.before-cpu-fix" ] || cp "$g" "$g.before-cpu-fix"
if grep -q 'maxcpus=[0-9]*' "$g"; then
    sed -i 's/maxcpus=[0-9]*/maxcpus=3/' "$g"
else
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&maxcpus=3 /' "$g"
fi
grep '^GRUB_CMDLINE_LINUX_DEFAULT' "$g"
update-grub 2>&1 | tail -2

echo
echo "Applying now (no reboot needed):"
systemctl start skip-bad-core.service
journalctl -u skip-bad-core.service -b --no-pager -o cat | tail -3
echo
echo "Threads online: $(grep -c ^processor /proc/cpuinfo) of 16"
