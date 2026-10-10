#!/usr/bin/env python3
"""
patch_mkparent.py — make PdxSdk's DiskIODefaultWindows.CreateFileStream create the parent
directory before opening the stream (CS2 macOS/Wine Paradox-Mods download fix).

Root cause: the mod download writes into nested dirs (.downloading/<id>/.metadata/,
.cpatch/<guid>/<ver>/-1_to_<ver>/) that PdxSdk never creates on this stack, so
FileStream throws DirectoryNotFoundException and the download aborts (thumbnail/manifest/
.zip never land). An external mkdir watcher can't win the in-process create->write race.
Fix it in-process: prepend  Directory.CreateDirectory(Path.GetDirectoryName(path))  to
DiskIODefaultWindows.CreateFileStream so the parent always exists before the write. Race-free,
idempotent (CreateDirectory is a no-op if the dir exists).

Mechanics: CreateFileStream is a tiny-header, no-EH instance method (this,path,mode,access,share).
Original 38-byte IL:
  ldarg.0; ldarg.1; call IsLongPath; brtrue.s L; ldarg.0; ldarg.1; call GetCleanPath;
  ldarg.2; ldarg.3; ldarg.s 4; newobj FileStream; ret; L: ...CreateLongPathFileStream...; ret
We PREPEND (12 bytes, no branches so the original's relative brtrue.s is unaffected):
  ldarg.1; call Path.GetDirectoryName; call Directory.CreateDirectory; pop
New body (50 IL bytes) still fits a TINY header. A body can't grow in place, so it is RELOCATED
into the .text section's file-alignment padding (the zero bytes between .text VirtualSize and
SizeOfRawData — Mono maps RVAs against raw size) and the MethodDef's RVA is repointed. The
original body stays where it was, unreferenced. Fully reversible via .bak.

RE-DERIVED for 1.6.2f1 (2026-10-10): nothing is hardcoded any more. The MethodDef, its RVA field,
the body, the slack and every token are resolved BY NAME through dnfile at run time, and the
whole original IL is matched instruction-by-instruction (tokens must resolve to the expected
names) before anything is written. 1.6.0f1: MethodDef#278, slack file 0x191868 (RVA 0x193668).
1.6.2f1: MethodDef#280, slack file 0x192da8 (RVA 0x194ba8).
Usage: patch_mkparent.py <PDX.SDK.dll | game-dir>   (needs dnfile; re-execs under ~/cs2-patch/revenv)
"""
# ---- shared by-name resolver + strict IL checker (identical in all five PDX patchers) ----
import sys, os, re, shutil, struct

_REVENV = os.path.expanduser("~/cs2-patch/revenv/bin/python3")
try:
    import dnfile
except ImportError:  # repatch.sh calls plain `python3`; dnfile lives in the revenv
    if os.path.exists(_REVENV) and not os.environ.get("PDXPATCH_REEXEC"):
        os.environ["PDXPATCH_REEXEC"] = "1"
        os.execv(_REVENV, [_REVENV] + sys.argv)
    sys.exit("ERROR: needs dnfile — run with ~/cs2-patch/revenv/bin/python3")


def die(msg):
    print(f"UNEXPECTED: {msg} — refusing to patch (game updated? re-derive)")
    sys.exit(1)


def find_dll(arg):
    if os.path.isdir(arg):
        for c in (os.path.join(arg, "Cities2_Data", "Managed", "PDX.SDK.dll"), os.path.join(arg, "PDX.SDK.dll")):
            if os.path.isfile(c):
                return c
    if os.path.isfile(arg):
        return arg
    sys.exit(f"PDX.SDK.dll not found: {arg}")


def backup_and_write(p, data):
    if not os.path.exists(p + ".bak"):
        shutil.copy2(p, p + ".bak")
    with open(p, "wb") as f:
        f.write(bytes(data))


# operand sizes per ECMA-335 III; 'S' = switch. Anything absent is an unknown opcode.
_OP1 = {}
for _o in list(range(0x00, 0x0e)) + [0x14, 0x15] + list(range(0x16, 0x1f)) + [0x25, 0x26, 0x2a] + \
        list(range(0x46, 0x6f)) + [0x76, 0x7a, 0x8e] + list(range(0x82, 0x8c)) + list(range(0x90, 0xa3)) + \
        list(range(0xb3, 0xbb)) + [0xc3] + list(range(0xd1, 0xdd)) + [0xdf, 0xe0]:
    _OP1[_o] = 0
for _o in (0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x1f, 0xde):
    _OP1[_o] = 1
for _o in list(range(0x2b, 0x38)):
    _OP1[_o] = 1
for _o in [0x20, 0x22, 0x27, 0x28, 0x29, 0x6f, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x79, 0x7b, 0x7c, 0x7d, 0x7e,
           0x7f, 0x80, 0x81, 0x8c, 0x8d, 0x8f, 0xa3, 0xa4, 0xa5, 0xc2, 0xc6, 0xd0, 0xdd] + list(range(0x38, 0x45)):
    _OP1[_o] = 4
_OP1[0x21] = 8; _OP1[0x23] = 8; _OP1[0x45] = "S"
_OP2 = {0x00: 0, 0x01: 0, 0x02: 0, 0x03: 0, 0x04: 0, 0x05: 0, 0x06: 4, 0x07: 4, 0x09: 2, 0x0a: 2, 0x0b: 2, 0x0c: 2,
        0x0d: 2, 0x0e: 2, 0x0f: 0, 0x11: 0, 0x12: 1, 0x13: 0, 0x14: 0, 0x15: 4, 0x16: 4, 0x17: 0, 0x18: 0, 0x19: 1,
        0x1a: 0, 0x1c: 4, 0x1d: 0, 0x1e: 0}
_BR1 = set(range(0x2b, 0x38)) | {0xde}
_BR4 = set(range(0x38, 0x45)) | {0xdd}
_TERM1 = {0x2a, 0x7a, 0x2b, 0x38, 0xdd, 0xde, 0xdc, 0x27}
_TERM2 = {0x1a, 0x11}


def decode(il):
    """Strict linear decode. -> list of (off, opcode, operand, next_off, branch_targets). Raises ValueError."""
    out, i = [], 0
    while i < len(il):
        off = i; op = il[i]; i += 1
        if op == 0xFE:
            if i >= len(il): raise ValueError(f"truncated 0xfe at IL {off:#x}")
            op2 = il[i]; i += 1
            if op2 not in _OP2: raise ValueError(f"unknown opcode fe {op2:02x} at IL {off:#x}")
            n = _OP2[op2]; opc = 0xFE00 | op2
        else:
            if op not in _OP1: raise ValueError(f"unknown opcode {op:02x} at IL {off:#x}")
            n = _OP1[op]; opc = op
        tg = []
        if n == "S":
            if i + 4 > len(il): raise ValueError(f"switch runs off body at IL {off:#x}")
            cnt = struct.unpack_from("<I", il, i)[0]; i += 4
            if i + 4 * cnt > len(il): raise ValueError(f"switch table runs off body at IL {off:#x}")
            rel = struct.unpack_from(f"<{cnt}i", il, i); i += 4 * cnt
            tg = [i + r for r in rel]; operand = cnt
        else:
            if i + n > len(il): raise ValueError(f"operand runs off body at IL {off:#x}")
            raw = bytes(il[i:i + n]); i += n
            operand = int.from_bytes(raw, "little") if n else None
            if op in _BR1 and opc == op: tg = [i + struct.unpack("<b", raw)[0]]
            if op in _BR4 and opc == op: tg = [i + struct.unpack("<i", raw)[0]]
        out.append((off, opc, operand, i, tg))
    return out


def check_body(il, eh):
    try:
        return _check_body(il, eh)
    except ValueError as e:
        die(f"IL does not decode cleanly: {e}")


def _check_body(il, eh):
    """Mono-style linear validity: every byte decodes, ends exactly at the body end on a terminator,
    every branch target and EH boundary lands on an instruction boundary."""
    ins = decode(il)
    bounds = {o for o, *_ in ins} | {len(il)}
    last = ins[-1][1]
    if not (last in _TERM1 or (last >> 8 == 0xFE and last & 0xFF in _TERM2)):
        raise ValueError(f"last instruction {last:#x} is not a terminator")
    for o, opc, _, _, tg in ins:
        for t in tg:
            if t not in bounds or t == len(il): raise ValueError(f"branch at IL {o:#x} -> {t:#x} not an instruction")
    for (flags, toff, tlen, hoff, hlen, _x) in eh:
        for b in (toff, toff + tlen, hoff, hoff + hlen):
            if b not in bounds: raise ValueError(f"EH boundary {b:#x} not on an instruction")
    return ins


class PDX:
    def __init__(self, data):
        self.data = data
        self.pe = dnfile.dnPE(data=bytes(data))
        self.md = self.pe.net.mdtables
        self.nested = {}
        if self.md.NestedClass:
            for n in self.md.NestedClass.rows:
                self.nested[n.NestedClass.row_index] = n.EnclosingClass.row_index
        self.mparent = {}
        for ti, ty in enumerate(self.md.TypeDef.rows):
            try:
                for m in ty.MethodList: self.mparent[m.row_index] = ti + 1
            except Exception:
                pass

    # -- names --
    def tdname(self, ti):
        ty = self.md.TypeDef.rows[ti - 1]; enc = self.nested.get(ti)
        if enc: return self.tdname(enc) + "/" + str(ty.TypeName)
        ns = str(ty.TypeNamespace or "")
        return (ns + "." if ns else "") + str(ty.TypeName)

    def trname(self, row):
        ns = str(getattr(row, "TypeNamespace", "") or "")
        return (ns + "." if ns else "") + str(getattr(row, "TypeName", "?"))

    def tokname(self, tok):
        tbl, rid = tok >> 24, tok & 0xFFFFFF
        try:
            if tbl == 0x06 and 1 <= rid <= len(self.md.MethodDef.rows):
                return self.tdname(self.mparent[rid]) + "::" + str(self.md.MethodDef.rows[rid - 1].Name)
            if tbl == 0x0A and 1 <= rid <= len(self.md.MemberRef.rows):
                r = self.md.MemberRef.rows[rid - 1]
                return self.trname(r.Class.row) + "::" + str(r.Name)
            if tbl == 0x04 and 1 <= rid <= len(self.md.Field.rows):
                return "field " + str(self.md.Field.rows[rid - 1].Name)
            if tbl == 0x70:
                return '"' + str(self.pe.net.user_strings.get(rid).value) + '"'
            if tbl == 0x2B and 1 <= rid <= len(self.md.MethodSpec.rows):
                m = self.md.MethodSpec.rows[rid - 1].Method.row
                return "spec " + str(getattr(m, "Name", "?"))
        except Exception:
            pass
        return f"<{tok:#010x}>"

    def sig(self, row):
        s = row.Signature
        return bytes(s.value if hasattr(s, "value") else s)

    # -- lookups --
    def types(self, pattern):
        rx = re.compile(pattern)
        return [ti + 1 for ti in range(len(self.md.TypeDef.rows)) if rx.fullmatch(self.tdname(ti + 1))]

    def method(self, type_pattern, name):
        tis = self.types(type_pattern)
        if len(tis) != 1: die(f"type /{type_pattern}/ matched {len(tis)} types")
        rids = [m.row_index for m in self.md.TypeDef.rows[tis[0] - 1].MethodList if str(m.row.Name) == name]
        if len(rids) != 1: die(f"{self.tdname(tis[0])}::{name} matched {len(rids)} methods")
        return rids[0]

    def memberref(self, cls, name, sig):
        hits = [i + 1 for i, r in enumerate(self.md.MemberRef.rows)
                if str(r.Name) == name and self.trname(r.Class.row) == cls and self.sig(r) == sig]
        if not hits: die(f"no MemberRef {cls}::{name} with sig {sig.hex()}")
        return 0x0A000000 | hits[0]

    # -- PE / bodies (Mono maps an RVA against each section's RAW size) --
    def rva2off(self, rva):
        for s in self.pe.sections:
            if s.VirtualAddress <= rva < s.VirtualAddress + s.SizeOfRawData:
                return rva - s.VirtualAddress + s.PointerToRawData
        return None

    def off2rva(self, off):
        for s in self.pe.sections:
            if s.PointerToRawData <= off < s.PointerToRawData + s.SizeOfRawData:
                return off - s.PointerToRawData + s.VirtualAddress
        return None

    def rva_field_off(self, rid):
        t = self.md.MethodDef
        return t.file_offset + t.row_size * (rid - 1)  # RVA is column 0

    def rva_of(self, rid, data=None):
        return struct.unpack_from("<I", data if data is not None else self.data, self.rva_field_off(rid))[0]


def body_at(data, off):
    """Parse a method body at file offset. -> dict(hdr, fat, il, size, end, eh, flags, maxstack, lvsig)."""
    b0 = data[off]
    if b0 & 3 == 2:
        return dict(hdr=off, fat=False, il=off + 1, size=b0 >> 2, end=off + 1 + (b0 >> 2), eh=[], flags=2,
                    maxstack=8, lvsig=0)
    if b0 & 3 != 3: raise ValueError(f"no method header at {off:#x}")
    flags, ms, size, lv = struct.unpack_from("<HHII", data, off)
    il = off + (flags >> 12) * 4; end = il + size; eh = []
    if flags & 8:
        p = (end + 3) & ~3
        while True:
            kind = data[p]
            if kind & 0x40:
                n = struct.unpack_from("<I", data, p)[0] >> 8
                for k in range((n - 4) // 24): eh.append(struct.unpack_from("<IIIIII", data, p + 4 + 24 * k))
            else:
                n = data[p + 1]
                for k in range((n - 4) // 12): eh.append(struct.unpack_from("<HHBHBI", data, p + 4 + 12 * k))
            end = p + n
            if not kind & 0x80: break
            p = (end + 3) & ~3
    return dict(hdr=off, fat=True, il=il, size=size, end=end, eh=eh, flags=flags, maxstack=ms, lvsig=lv)


def tok(t):
    return struct.pack("<I", t)


def il_of(data, b):
    return bytes(data[b["il"]:b["il"] + b["size"]])


def text_slack(px, nbytes, data):
    """First 4-aligned run of `nbytes` zero bytes past .text's VirtualSize (linker file-alignment padding),
    verified unreferenced: no MethodDef/FieldRVA/PE-or-CLI data directory/debug data points into it."""
    s = px.pe.sections[0]
    if not bytes(s.Name).startswith(b".text"): die("first section is not .text")
    start = (s.PointerToRawData + s.Misc_VirtualSize + 3) & ~3
    end = s.PointerToRawData + s.SizeOfRawData
    if start + nbytes > end: die(f".text tail slack is {end - start} B, need {nbytes}")
    if any(data[start:start + nbytes]): die(f".text tail slack at {start:#x} is not zero")
    lo, hi = px.off2rva(start), px.off2rva(start) + nbytes
    refs = [r.Rva for r in px.md.MethodDef.rows if r.Rva]
    if px.md.FieldRva: refs += [r.Rva for r in px.md.FieldRva.rows]
    for dd in px.pe.OPTIONAL_HEADER.DATA_DIRECTORY:
        if dd.VirtualAddress: refs += [dd.VirtualAddress, dd.VirtualAddress + max(dd.Size, 1) - 1]
    cli = px.pe.net.struct
    for f in ("MetaDataRva", "ResourcesRva", "StrongNameSignatureRva", "VTableFixupsRva"):
        v = getattr(cli, f, 0)
        if v: refs += [v, v + max(getattr(cli, f.replace("Rva", "Size"), 1), 1) - 1]
    for d in getattr(px.pe, "DIRECTORY_ENTRY_DEBUG", []) or []:
        if d.struct.AddressOfRawData: refs += [d.struct.AddressOfRawData, d.struct.AddressOfRawData + d.struct.SizeOfData - 1]
    text_end = s.VirtualAddress + s.SizeOfRawData
    bad = [hex(r) for r in refs if lo <= r < text_end]
    if bad: die(f".text slack RVA {lo:#x}.. is referenced or followed by referenced data ({bad})")
    return start, lo
def ensure_text_vsize(px, data):
    """Map the relocated body by the PE spec too: raise .text VirtualSize to SizeOfRawData.
    Mono maps RVAs against raw size, so the body already loads (1.6.0f1 shipped that way and
    downloads worked), but a spec-following loader maps only VirtualSize. Raising it costs nothing:
    the bytes are already on disk, and the section's aligned end must not move (checked).
    Suggested in cs2 #15 (jvyoralek). Returns True if the header changed."""
    s = px.pe.sections[0]
    if s.Misc_VirtualSize >= s.SizeOfRawData: return False
    align = px.pe.OPTIONAL_HEADER.SectionAlignment
    up = lambda v: (v + align - 1) & ~(align - 1)
    nxt = px.pe.sections[1].VirtualAddress if len(px.pe.sections) > 1 else None
    if up(s.VirtualAddress + s.SizeOfRawData) != up(s.VirtualAddress + s.Misc_VirtualSize):
        die(".text VirtualSize raise would change the section's aligned end")
    if nxt is not None and s.VirtualAddress + s.SizeOfRawData > nxt:
        die(".text VirtualSize raise would overlap the next section")
    struct.pack_into("<I", data, s.get_file_offset() + 8, s.SizeOfRawData)
    return True


def match(px, il, pos, template):
    """template items: bytes (literal) | (name,) a 4-byte token that must resolve to `name` |
    (name, key) same, captured into the result dict. -> (dict | None, reason)"""
    got = {}
    for it in template:
        if isinstance(it, (bytes, bytearray)):
            if il[pos:pos + len(it)] != it: return None, f"IL {pos:#x}: want {bytes(it).hex()} got {il[pos:pos + len(it)].hex()}"
            pos += len(it)
        else:
            if pos + 4 > len(il): return None, f"IL {pos:#x}: token runs off body"
            t = struct.unpack_from("<I", il, pos)[0]; nm = px.tokname(t)
            if nm != it[0]: return None, f"IL {pos:#x}: token {t:#010x} is {nm}, want {it[0]}"
            if len(it) > 1:
                if it[1] in got and got[it[1]] != t: return None, f"IL {pos:#x}: {it[1]} token differs"
                got[it[1]] = t
            pos += 4
    return got, pos
def sig_types(px, sig):
    """Minimal ECMA-335 II.23.2 method-sig reader -> (callconv, [ret, param...]) as readable names."""
    p = [0]
    def cu():
        x = sig[p[0]]
        if x & 0x80 == 0: p[0] += 1; return x
        if x & 0xC0 == 0x80: p[0] += 2; return ((x & 0x3F) << 8) | sig[p[0] - 1]
        p[0] += 4; return ((x & 0x1F) << 24) | (sig[p[0] - 3] << 16) | (sig[p[0] - 2] << 8) | sig[p[0] - 1]
    def ty():
        e = sig[p[0]]; p[0] += 1
        if e in (0x11, 0x12):
            c = cu(); tag, rid = c & 3, c >> 2
            kw = "class " if e == 0x12 else "valuetype "
            if tag == 1: return kw + px.trname(px.md.TypeRef.rows[rid - 1])
            if tag == 0: return kw + px.tdname(rid)
            return kw + "<typespec>"
        return {0x01: "void", 0x02: "bool", 0x08: "int32", 0x0E: "string", 0x18: "native int", 0x1C: "object"}.get(e, f"<et {e:#x}>")
    cc = sig[0]; p[0] = 1; n = cu()
    out = [ty() for _ in range(n + 1)]
    if p[0] != len(sig): return cc, out + ["<trailing bytes>"]
    return cc, out
# ---- end shared block ----

TYPE = r"PDX\.SDK\.Internal\.Util\.IO\.DiskIODefaultWindows"
T = "PDX.SDK.Internal.Util.IO.DiskIODefaultWindows::"
ORIG = [b"\x02\x03\x28", (T + "IsLongPath",), b"\x2d\x11\x02\x03\x28", (T + "GetCleanPath",),
        b"\x04\x05\x0e\x04\x73", ("System.IO.FileStream::.ctor",),
        b"\x2a\x02\x03\x04\x05\x0e\x04\x28", (T + "CreateLongPathFileStream",), b"\x2a"]
ORIG_LEN = 38


def prelude(px):
    gdn = px.memberref("System.IO.Path", "GetDirectoryName", bytes.fromhex("00010e0e"))
    hits = []
    for i, r in enumerate(px.md.MemberRef.rows):
        if str(r.Name) == "CreateDirectory" and px.trname(r.Class.row) == "System.IO.Directory":
            if sig_types(px, px.sig(r)) == (0x00, ["class System.IO.DirectoryInfo", "string"]):
                hits.append(0x0A000001 + i)
    if not hits: die("no MemberRef System.IO.Directory::CreateDirectory(string) -> DirectoryInfo")
    # returns DirectoryInfo (non-void) -> the trailing `pop` keeps the stack empty
    return b"\x03\x28" + tok(gdn) + b"\x28" + tok(hits[0]) + b"\x26"


def main():
    if len(sys.argv) < 2:
        print("usage: patch_mkparent.py <PDX.SDK.dll | game-dir>"); sys.exit(2)
    p = find_dll(sys.argv[1])
    data = bytearray(open(p, "rb").read())
    px = PDX(data)
    rid = px.method(TYPE, "CreateFileStream")
    rva = px.rva_of(rid); off = px.rva2off(rva)
    if off is None: die(f"MethodDef#{rid} RVA {rva:#x} maps to no section")
    b = body_at(data, off); il = il_of(data, b)
    pre = prelude(px)

    if not b["fat"] and b["size"] == len(pre) + ORIG_LEN and il[:len(pre)] == pre:
        got, end = match(px, il, len(pre), ORIG)
        if got is not None and end == len(il):
            if ensure_text_vsize(px, data):
                backup_and_write(p, data)
                print(f"already relocated (MethodDef#{rid} -> {rva:#x}); raised .text VirtualSize to SizeOfRawData.")
            else:
                print(f"already patched (RVA repointed: MethodDef#{rid} -> {rva:#x})."); return
            return
    if b["fat"] or b["size"] != ORIG_LEN:
        die(f"MethodDef#{rid} body at RVA {rva:#x} is {'fat' if b['fat'] else 'tiny'} size {b['size']} (want tiny 38)")
    got, why = match(px, il, 0, ORIG)
    if got is None or why != ORIG_LEN: die(f"original CreateFileStream IL differs: {why}")
    check_body(il, [])

    new_il = pre + il
    check_body(new_il, [])
    body = bytes([(len(new_il) << 2) | 0x02]) + new_il
    if len(new_il) >= 64: die("new body no longer fits a tiny header")
    start, new_rva = text_slack(px, len(body), data)
    data[start:start + len(body)] = body
    struct.pack_into("<I", data, px.rva_field_off(rid), new_rva)
    ensure_text_vsize(px, data)

    # re-resolve from the modified image before writing anything to disk
    v = PDX(data); r2 = v.method(TYPE, "CreateFileStream")
    b2 = body_at(data, v.rva2off(v.rva_of(r2)))
    if r2 != rid or b2["fat"] or il_of(data, b2) != new_il or bytes(data[off:off + 1 + ORIG_LEN]) != bytes([b["flags"] | (ORIG_LEN << 2)]) + il:
        die("post-write verification failed")
    check_body(il_of(data, b2), [])

    backup_and_write(p, data)
    print(f"patched: relocated CreateFileStream body to file {start:#x} / RVA {new_rva:#x} (+CreateDirectory prelude);"
          f" MethodDef#{rid} RVA {rva:#x} -> {new_rva:#x}")


if __name__ == "__main__":
    main()
