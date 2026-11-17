#!/bin/bash
# Undo the 7-core Windows setup and go back to Windows on 6 threads (numproc=6),
# which works with Secure Boot on and from any boot menu.
[ "$(id -u)" = 0 ] || { echo "Run with sudo"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)

rm -f /etc/grub.d/42_windows_skip_core3 /boot/acpi/madt-skip-core3.aml
sed -i 's/^GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
update-grub 2>&1 | tail -2
"$here/windows-numproc.sh" set 6
echo "Back to Windows on 6 threads. You can turn Secure Boot on again."
