#!/bin/bash
# Undo the skip-core-3 setup: all 16 threads on next boot (e.g. after a board repair).
# Usage: sudo ./uninstall.sh
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh"; exit 1; }
systemctl disable skip-bad-core.service 2>/dev/null
rm -f /etc/systemd/system/skip-bad-core.service /usr/local/sbin/skip-bad-core.sh
systemctl daemon-reload
sed -i 's/maxcpus=[0-9]* //' /etc/default/grub
grep '^GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub
update-grub 2>&1 | tail -2
echo "Removed. All 16 threads will be used from the next boot."
