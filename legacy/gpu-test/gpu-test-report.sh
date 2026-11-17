#!/bin/bash
# Summarise the GPU-wake test: one line per boot since the test was installed.
LOG=${LOG:-/var/log/gpu-crash-test.log}
[ -r "$LOG" ] || { echo "No $LOG yet - is the test installed and have you rebooted?"; exit 1; }

first=$(head -1 "$LOG" | cut -d' ' -f1,2)
echo "Boots since test started ($first):"
echo

journalctl --list-boots --no-pager -o json 2>/dev/null | python3 -I -c '
import json, sys, datetime
log = open(sys.argv[1]).read().splitlines()
first = datetime.datetime.strptime(sys.argv[2], "%Y-%m-%d %H:%M:%S")
tally = {}
for b in json.load(sys.stdin):
    start = datetime.datetime.fromtimestamp(b["first_entry"] / 1e6)
    if start < first - datetime.timedelta(minutes=2):
        continue
    bid = b["boot_id"][:8]
    lines = [l for l in log if f"boot={bid}" in l]
    up = (b["last_entry"] - b["first_entry"]) / 1e6
    has = lambda w: any(w in l for l in lines)
    current = b["index"] == 0
    if has("SURVIVED"):
        verdict = "OK - GPU woke fine"
    elif has("NO_GPU_READY"):
        verdict = "no crash, but ollama never reported the GPU"
    elif current:
        verdict = "still testing (current boot)"
    elif up > 300:
        verdict = "no crash, test did not finish (check: systemctl status gpu-crash-test)"
    elif has("WAKING_GPU"):
        verdict = "CRASHED WHILE WAKING GPU"
    elif has("BOOTED"):
        verdict = "CRASHED BEFORE GPU WAS TOUCHED"
    else:
        verdict = "CRASHED VERY EARLY (before the test started)"
    tally[verdict] = tally.get(verdict, 0) + 1
    ac = next((l.split("ac_online=")[1] for l in lines if "ac_online=" in l), "?")
    print(f"{start:%m-%d %H:%M}  up {up:7.0f}s  charger={ac}  {verdict}")
print()
for k, v in sorted(tally.items(), key=lambda kv: -kv[1]):
    print(f"{v:3d}  {k}")
' "$LOG" "$first"
