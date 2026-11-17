#!/bin/bash
# Bring every CPU thread online EXCEPT the ones on the faulty physical core.
# The kernel boots with maxcpus=3 (cores 0-2 only), so the bad core never runs
# during early boot; this script then adds the healthy cores back.

BAD_CORE=3          # physical core_id that corrupts data
BAD_CPUS="6 7"      # its two threads (from /sys/.../topology on this laptop)

cpu_dir=/sys/devices/system/cpu

for path in "$cpu_dir"/cpu[0-9]*; do
    n=${path##*cpu}
    [[ " $BAD_CPUS " == *" $n "* ]] && continue
    [ -w "$path/online" ] || continue
    [ "$(cat "$path/online")" = 1 ] || echo 1 > "$path/online"
done

# Safety net: if any online thread turns out to belong to the bad core
# (e.g. numbering changed after a BIOS update), take it offline again.
for path in "$cpu_dir"/cpu[0-9]*; do
    [ -w "$path/online" ] && [ "$(cat "$path/online")" = 1 ] || continue
    if [ "$(cat "$path/topology/core_id" 2>/dev/null)" = "$BAD_CORE" ]; then
        echo 0 > "$path/online"
        echo "WARNING: ${path##*/} is on core $BAD_CORE - taken offline"
    fi
done

echo "Online CPUs: $(cat $cpu_dir/online)  (offline: $(cat $cpu_dir/offline))"
