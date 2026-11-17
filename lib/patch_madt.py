#!/usr/bin/env python3
"""Make a copy of the ACPI MADT ("APIC" table) with some CPUs disabled.

Clears the Enabled (bit 0) and Online-Capable (bit 1) flags of the given
APIC IDs, so the OS never starts those threads, then fixes the checksum.

usage: patch_madt.py ORIGINAL OUTPUT APIC_ID [APIC_ID ...]
"""
import struct
import sys

src, dst, *ids = sys.argv[1:]
if not ids:
    sys.exit(__doc__)
ids = {int(i) for i in ids}

d = bytearray(open(src, "rb").read())
if d[:4] != b"APIC" or struct.unpack("<I", d[4:8])[0] != len(d):
    sys.exit("Not a valid MADT (APIC) table - aborting.")
if sum(d) & 0xFF:
    sys.exit("Original MADT checksum is wrong - aborting.")

i, seen, disabled = 44, [], []
while i < len(d):
    t, l = d[i], d[i + 1]
    if l < 2:
        sys.exit("Malformed MADT entry - aborting.")
    if t == 0:                                   # Processor Local APIC
        apic, fo = d[i + 3], i + 4
    elif t == 9:                                 # Processor Local x2APIC
        apic, fo = struct.unpack("<I", d[i + 4:i + 8])[0], i + 8
    else:
        i += l
        continue
    flags = struct.unpack("<I", d[fo:fo + 4])[0]
    if apic in ids:
        struct.pack_into("<I", d, fo, flags & ~0x3)
        disabled.append(apic)
    seen.append((apic, bool(flags & 1) and apic not in ids))
    i += l

if sorted(set(disabled)) != sorted(ids):
    sys.exit(f"Did not find all APIC IDs {sorted(ids)} (found {disabled}) - aborting.")

d[9] = 0
d[9] = (-sum(d)) & 0xFF
assert sum(d) & 0xFF == 0
open(dst, "wb").write(d)

on = [a for a, e in seen if e]
print(f"Patched MADT written to {dst}")
print(f"  disabled APIC IDs: {sorted(set(disabled))}")
print(f"  CPUs Windows will see: {on}  ({len(on)} threads)")
