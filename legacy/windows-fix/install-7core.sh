#!/bin/bash
# Windows on 7 cores / 14 threads: GRUB hands Windows a CPU table (MADT)
# with core 3 (APIC IDs 6 and 7) disabled, then starts Windows Boot Manager.
# Needs Secure Boot OFF (GRUB refuses to load ACPI tables while it is on).
#
#   sudo ./install-7core.sh      # install
#   sudo ./uninstall-7core.sh    # undo, back to Windows on 6 threads
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo"; exit 1; }
here=$(cd "$(dirname "$0")" && pwd)

BAD_APIC_IDS="6 7"                      # core 3
WIN_ESP_UUID=1679-F4EB                  # Windows "SYSTEM" EFI partition
BACKUPS=/var/backups/windows-bcd
TABLE_DIR=/boot/acpi
TABLE=$TABLE_DIR/madt-skip-core3.aml
ENTRY=/etc/grub.d/42_windows_skip_core3

mkdir -p "$BACKUPS" "$TABLE_DIR"

# 1. Patched CPU table, built from this laptop's own firmware table.
[ -e "$BACKUPS/APIC.original" ] || cp /sys/firmware/acpi/tables/APIC "$BACKUPS/APIC.original"
python3 -I "$here/patch_madt.py" "$BACKUPS/APIC.original" "$TABLE" $BAD_APIC_IDS

# 2. GRUB menu entry.
BOOT_UUID=$(findmnt -no UUID /boot)
cat > "$ENTRY" <<EOF
#!/bin/sh
cat <<'MENU'
menuentry "Windows 11 (7 cores, skip core 3)" --class windows {
    insmod part_gpt
    insmod fat
    insmod ext2
    search --no-floppy --fs-uuid --set=acpifs $BOOT_UUID
    if acpi --exclude=APIC (\$acpifs)/acpi/madt-skip-core3.aml; then
        search --no-floppy --fs-uuid --set=root $WIN_ESP_UUID
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    else
        echo "Could not load the patched CPU table (is Secure Boot still on?)."
        echo "Not starting Windows - it would use core 3. Returning to the menu..."
        sleep 10
    fi
}
MENU
EOF
chmod 755 "$ENTRY"

# 3. Hide GRUB's automatic "Windows Boot Manager" entry: without the patched
#    table it would start Windows on all 16 threads, including core 3.
g=/etc/default/grub
[ -e "$g.before-7core" ] || cp "$g" "$g.before-7core"
if grep -q '^#\?GRUB_DISABLE_OS_PROBER=' "$g"; then
    sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' "$g"
else
    echo 'GRUB_DISABLE_OS_PROBER=true' >> "$g"
fi
update-grub 2>&1 | tail -2

# 4. Let Windows use every CPU it is shown (14), instead of the first 6.
"$here/windows-numproc.sh" remove

echo
grep -c "skip core 3" /boot/grub/grub.cfg >/dev/null && echo "GRUB entry installed: \"Windows 11 (7 cores, skip core 3)\""
mokutil --sb-state 2>/dev/null | grep -q enabled && echo ">>> Secure Boot is still ON - turn it off in the BIOS before using the new entry."
echo "Only start Windows from that GRUB entry. Starting it straight from the BIOS boot menu uses all 16 threads."
