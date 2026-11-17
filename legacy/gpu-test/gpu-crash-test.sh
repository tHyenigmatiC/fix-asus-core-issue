#!/bin/bash
# Delayed GPU-wake test.
# With ollama's autostart disabled, the NVIDIA GPU is no longer pushed into
# compute mode ~14 s after boot. This script waits until the machine has been
# up for WAKE_AT seconds, writes a marker to disk, THEN starts ollama (which
# initialises CUDA on the RTX 3050 exactly like before) and writes a second
# marker if the machine survives.
#
#   crash right after "WAKING_GPU"          -> GPU compute init is the trigger
#   crash before "WAKING_GPU" (no marker)   -> something else, not the GPU
#   "SURVIVED" every time                   -> no crash this boot

LOG=${LOG:-/var/log/gpu-crash-test.log}
WAKE_AT=${WAKE_AT:-90}   # seconds of uptime before touching the GPU

boot_id=$(cat /proc/sys/kernel/random/boot_id)
uptime_s() { cut -d' ' -f1 /proc/uptime; }

mark() {
    printf '%s boot=%s uptime=%s %s\n' "$(date '+%F %T')" "${boot_id:0:8}" "$(uptime_s)" "$*" >> "$LOG"
    sync "$LOG"   # force to disk, a hard reset must not lose this line
}

ac=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo "?")
mark "BOOTED ac_online=$ac"

while [ "$(cut -d. -f1 /proc/uptime)" -lt "$WAKE_AT" ]; do sleep 1; done

pstate=$(nvidia-smi --query-gpu=pstate,power.draw --format=csv,noheader 2>/dev/null)
mark "WAKING_GPU (before: $pstate)"

start=$(date +%s)
systemctl start ollama.service

ok=0
for _ in $(seq 1 60); do
    if journalctl -u ollama.service --since "@$start" --no-pager 2>/dev/null | grep -q "inference compute"; then
        ok=1; break
    fi
    sleep 1
done

pstate=$(nvidia-smi --query-gpu=pstate,power.draw --format=csv,noheader 2>/dev/null)
if [ "$ok" = 1 ]; then
    mark "SURVIVED gpu_ready after $(( $(date +%s) - start ))s (now: $pstate)"
else
    mark "NO_GPU_READY within 60s (now: $pstate) - check: journalctl -u ollama -b"
fi
