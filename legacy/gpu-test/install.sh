#!/bin/bash
# Install the delayed GPU-wake test. Run with: sudo ./install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./install.sh"; exit 1; }
cd "$(dirname "$0")"

install -m 755 gpu-crash-test.sh   /usr/local/bin/gpu-crash-test.sh
install -m 755 gpu-test-report.sh  /usr/local/bin/gpu-test-report
install -m 644 gpu-crash-test.service /etc/systemd/system/gpu-crash-test.service
touch /var/log/gpu-crash-test.log && chmod 644 /var/log/gpu-crash-test.log

# Stop ollama from waking the GPU 14 s into boot; the test starts it at 90 s instead.
systemctl disable ollama.service
systemctl daemon-reload
systemctl enable gpu-crash-test.service

echo
echo "Installed. ollama autostart is disabled; the test will start it 90 s after each boot."
echo "Firmware power limits stored in the laptop (also used by Windows):"
for a in ppt_pl1_spl ppt_pl2_sppt ppt_pl3_fppt nv_dynamic_boost nv_temp_target; do
    f=/sys/class/firmware-attributes/asus-armoury/attributes/$a
    [ -e "$f/current_value" ] && printf '  %-17s current=%s  (min %s / max %s)\n' "$a" \
        "$(cat $f/current_value 2>/dev/null)" "$(cat $f/min_value 2>/dev/null)" "$(cat $f/max_value 2>/dev/null)"
done
echo
echo "Now: shut down fully, boot Ubuntu, repeat. Check results any time with: gpu-test-report"
