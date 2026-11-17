#!/bin/bash
# Remove the GPU-wake test and restore ollama autostart. Run with: sudo ./uninstall.sh
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo ./uninstall.sh"; exit 1; }
systemctl disable --now gpu-crash-test.service 2>/dev/null
rm -f /etc/systemd/system/gpu-crash-test.service /usr/local/bin/gpu-crash-test.sh /usr/local/bin/gpu-test-report
systemctl daemon-reload
systemctl enable ollama.service
echo "Removed. ollama autostart restored. The log is kept at /var/log/gpu-crash-test.log"
