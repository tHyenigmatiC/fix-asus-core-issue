#!/usr/bin/env python3
"""Show / set / remove the Windows "numproc" boot option in a BCD hive.

numproc = BCD element 0x25000061 (BcdOSLoaderInteger_NumberOfProcessors),
stored as an 8-byte little-endian REG_BINARY. It is applied to every
Windows OS loader entry (type 0x10200003): the normal Windows entry and the
Windows Recovery entry, so both start on the first N logical processors only.

usage: bcd_numproc.py BCD show
       bcd_numproc.py BCD set N
       bcd_numproc.py BCD remove
"""
import struct
import sys

import hivex

NUMPROC = "25000061"
DESCRIPTION = "12000004"
OS_LOADER_TYPE = 0x10200003
REG_BINARY = 3


def child(h, node, name):
    for c in h.node_children(node):
        if h.node_name(c).lower() == name.lower():
            return c
    return None


def value(h, node, name):
    for v in h.node_values(node):
        if h.value_key(v) == name:
            return h.value_value(v)[1]
    return None


def os_loaders(h):
    objects = child(h, h.root(), "Objects")
    for obj in h.node_children(objects):
        desc = child(h, obj, "Description")
        t = value(h, desc, "Type") if desc else None
        if t is None or struct.unpack("<I", t[:4])[0] != OS_LOADER_TYPE:
            continue
        elements = child(h, obj, "Elements")
        name_node = child(h, elements, DESCRIPTION)
        name = value(h, name_node, "Element").decode("utf-16-le").rstrip("\0") if name_node else "?"
        yield h.node_name(obj), name, elements


def numproc_of(h, elements):
    n = child(h, elements, NUMPROC)
    if n is None:
        return None
    return struct.unpack("<Q", value(h, n, "Element")[:8])[0]


def show(path):
    h = hivex.Hivex(path)
    found = False
    for guid, name, elements in os_loaders(h):
        found = True
        np = numproc_of(h, elements)
        print(f"  {name:32s} {guid}  numproc={'not set (all CPUs)' if np is None else np}")
    if not found:
        sys.exit("No Windows loader entries found in this BCD - not touching it.")


def change(path, n):
    h = hivex.Hivex(path, write=True)
    loaders = list(os_loaders(h))
    if not loaders:
        sys.exit("No Windows loader entries found in this BCD - not touching it.")
    for guid, name, elements in loaders:
        node = child(h, elements, NUMPROC)
        if n is None:
            if node is not None:
                h.node_delete_child(node)
        else:
            if node is None:
                node = h.node_add_child(elements, NUMPROC)
            h.node_set_value(node, {"key": "Element", "t": REG_BINARY,
                                    "value": struct.pack("<Q", n)})
    h.commit(None)


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[2] not in ("show", "set", "remove"):
        sys.exit(__doc__)
    bcd, cmd = sys.argv[1], sys.argv[2]
    if cmd == "set":
        change(bcd, int(sys.argv[3]))
    elif cmd == "remove":
        change(bcd, None)
    show(bcd)
