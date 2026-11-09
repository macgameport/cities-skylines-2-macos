#!/usr/bin/env python3
"""pe_patch.py -- the two PE edits make-engine.sh needs for D3DMetal on Wine 11 (stdlib only).

  pe_patch.py rename-import <dll> <old.dll> <new.dll>   rename one import descriptor's DLL name in
                                                       place (same length; refuses anything else)
  pe_patch.py stamp-builtin <dll>                      write "Wine builtin DLL", NUL-padded to 32 bytes, at 0x40, as
                                                       winebuild --builtin does
  pe_patch.py imports <dll>                            print the imported DLL names

See tools/d3dmu.c for why. Exit 0 = done, 1 = refused (nothing written).
"""
import struct
import sys

MARK = b"Wine builtin DLL".ljust(32, b"\0")   # Wine compares all 32 bytes (char builtin_signature[32])


def sections(d):
    pe = struct.unpack_from("<I", d, 0x3C)[0]
    if d[pe:pe + 4] != b"PE\0\0":
        sys.exit("not a PE file")
    nsec, optsize = struct.unpack_from("<H", d, pe + 6)[0], struct.unpack_from("<H", d, pe + 20)[0]
    opt = pe + 24
    if struct.unpack_from("<H", d, opt)[0] != 0x20B:
        sys.exit("not PE32+ (x86_64)")
    imp_rva = struct.unpack_from("<I", d, opt + 112 + 8)[0]   # data directory 1 = imports
    secs = []
    for i in range(nsec):
        s = opt + optsize + 40 * i
        vsize, va, rsize, raw = struct.unpack_from("<IIII", d, s + 8)
        secs.append((va, max(vsize, rsize), raw))
    return imp_rva, secs


def off(secs, rva):
    for va, size, raw in secs:
        if va <= rva < va + size:
            return rva - va + raw
    sys.exit("RVA 0x%x is in no section" % rva)


def import_names(d):
    imp_rva, secs = sections(d)
    o, out = off(secs, imp_rva), []
    while True:
        desc = struct.unpack_from("<IIIII", d, o)
        if not any(desc):
            return out
        n = off(secs, desc[3])
        name = d[n:d.index(b"\0", n)]
        out.append((name, n))
        o += 20


def main(argv):
    cmd, path = argv[1], argv[2]
    d = bytearray(open(path, "rb").read())
    if cmd == "imports":
        print(" ".join(n.decode() for n, _ in import_names(d)))
        return 0
    if cmd == "stamp-builtin":
        if struct.unpack_from("<I", d, 0x3C)[0] < 0x40 + len(MARK):
            print("refused: PE header starts inside 0x40..0x60")
            return 1
        d[0x40:0x40 + len(MARK)] = MARK
    elif cmd == "rename-import":
        old, new = argv[3].encode(), argv[4].encode()
        if len(old) != len(new):
            print("refused: names differ in length")
            return 1
        hits = [n for name, n in import_names(d) if name.lower() == old.lower()]
        if len(hits) != 1:
            print("refused: %d import descriptors name %s" % (len(hits), argv[3]))
            return 1
        d[hits[0]:hits[0] + len(new)] = new
    else:
        sys.exit(__doc__)
    open(path, "wb").write(d)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
