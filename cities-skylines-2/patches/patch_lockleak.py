#!/usr/bin/env python3
"""
patch_lockleak.py — release the per-path file lock that PdxSdk leaks on any IO exception.

ROOT CAUSE (verified 2026-08-21 by disassembly + EH-table read, supersedes the
"reader->writer upgrade deadlock" theory in change-ledger.txt):

  PDX.SDK.dll  <CreateFileStream>d__25.MoveNext   (FileIO::CreateFileStream state machine)

  IL 0x6c-0x87:  if (access == Read) AcquireReaderLock else AcquireWriterLock
                 -> the two are MUTUALLY EXCLUSIVE branches. There is no reader->writer
                    upgrade, so there is no self-deadlock. All four prior lock patches
                    (locksem / writenowait / readerinit / readerskip) targeted a bug that
                    does not exist, which is why each failed or broke boot.

  The lock is NOT released by this method on success -- it is wrapped into the returned
  stream (IL 0x197-0x19e) and released when the caller disposes that stream.

  Exception-handler table for the method:
      [0] CATCH try 0x0049..0x01a6  handler 0x01a6..0x01d6  (Exception)
      [1] CATCH try 0x000e..0x01d6  handler 0x01d6..0x01ef  (Exception)
      -> NO finally clause anywhere.

  The lock is acquired at 0x78/0x82, INSIDE try[0]. The FileNotFound path disposes it
  correctly (IL 0x11e-0x120: ldloc.s 5; callvirt Dispose). The CATCH handler does NOT.

  So when Wine's garbage-errno makes CreateDirectory (0x16f) or the real
  CreateFileStream (0x192) throw, the per-path lock is leaked forever. Every later
  operation on that same path then waits on a lock nobody holds a release for; because
  FileIO::GetLockToken builds a CancellationTokenSource(TimeSpan.FromSeconds(N)) --
  a TIMEOUT -- the wait is cancelled and SemaphoreSlim.WaitAsync THROWS. That is exactly
  the observed Player.log stack:
      AcquireWriterLockInner d__8 -> SemaphoreSlim.WaitUntilCountOrTimeoutAsync -> SetException

  It also explains why manifests/thumbnails wrote fine (different paths, never leaked)
  and why neutering the lock globally crashed boot (Colossal.IO.AssetDatabase relies on
  real locking -- the locking is correct, only the leak is the bug).

THE FIX (in-place, no relocation, no EH edits, stack-neutral):

  Overwrite the catch handler's redundant inner Log call (IL 0x1af..0x1cc, 30 bytes)
  with a null-guarded dispose of the lock + nop padding:

      ldloc.s   5              11 05      ; the AcquireLockResult (null if we threw before 0xe9)
      brfalse.s +7             2c 07      ; skip if never acquired
      ldloc.s   5              11 05
      callvirt  Dispose        6f <tok>   ; same token the 0x120 path already uses
      nop * 19                 00 ...

  Exactly 30 bytes in, 30 bytes out -> every IL offset, branch target and EH clause
  offset is unchanged. The error still propagates: CreateIoResultFromException (0x1aa)
  already ran, and the caller logs the failure, so diagnosis is preserved.

RE-DERIVED for 1.6.2f1 (2026-10-10): no hardcoded offsets. The state machine is resolved BY NAME
(nested type FileIO/<CreateFileStream>d__<n>, method MoveNext; n was 25 in both 1.6.0f1 and 1.6.2f1).
The catch handler is located through the method's EH table: the one CATCH clause whose handler IL is
  stloc.s 8; ldloc.s 8; call ResultFactory::CreateIoResultFromException;
  [ldloc.1; ldfld _logger; ldloc.s 8; callvirt Object::ToString; ldc.i4.3; ldarg.0; ldfld flowData;
   ldstr "CreateFileStream"; callvirt ILoggingService::Log]   <- the 30-byte run
  ldnull; call CastTo<..>; ...
with every token resolved by name. The lock local and the Dispose token are taken from the method's own
`ldloc.s N; callvirt AcquireLockResult::Dispose` site(s), found by decoding (all such sites must agree).
No branch target or EH boundary may fall inside the run, and the patched body is strictly decoded before
writing. 1.6.0f1: run at file 0x2fbff. 1.6.2f1: run at file 0x31d5f, Dispose 0x06000e39.
--revert restores the run from .bak only if .bak resolves to the pristine form at the same offset.

Usage:  patch_lockleak.py <game-dir-or-PDX.SDK.dll> [--dry-run] [--revert]
Idempotent. Writes PDX.SDK.dll.bak on first run if absent.
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

ENC = r"PDX\.SDK\.Internal\.Util\.IO\.FileIO/<CreateFileStream>d__\d+"
LOG_LEN = 30
DISPOSE = "PDX.SDK.Internal.Service.DataStorage.Results.AcquireLockResult::Dispose"
HANDLER = [b"\x13\x08\x11\x08\x28", ("PDX.SDK.Internal.Results.ResultFactory::CreateIoResultFromException",)]
RUN = [b"\x07\x7b", ("field _logger",), b"\x11\x08\x6f", ("System.Object::ToString",), b"\x19\x02\x7b",
       ("field flowData",), b"\x72", ('"CreateFileStream"',), b"\x6f",
       ("PDX.SDK.Contracts.Logging.ILoggingService::Log",)]
AFTER = b"\x14\x28"  # ldnull; call CastTo  (token checked separately)


def build_patch(loc, dispose_tok):
    body = bytes([0x11, loc,               # ldloc.s <lock>
                  0x2C, 0x07,              # brfalse.s -> skip (7 bytes ahead)
                  0x11, loc]) + \
           bytes([0x6F]) + dispose_tok     # callvirt Dispose
    assert len(body) == 11, len(body)
    return body + b"\x00" * (LOG_LEN - len(body))


def locate(px, data):
    """-> (body, log_start_file_off, lock_local, dispose_tok_bytes, state)"""
    rid = px.method(ENC, "MoveNext")
    off = px.rva2off(px.rva_of(rid))
    if off is None: die("MoveNext RVA maps to no section")
    b = body_at(data, off); il = il_of(data, b)
    if not b["fat"] or not b["eh"]: die("MoveNext has no EH table")
    ins = check_body(il, b["eh"])
    # lock local + Dispose token from the method's own Dispose call site(s)
    sites = set()
    for k in range(1, len(ins)):
        po, popc, parg, _, _ = ins[k - 1]; o, opc, arg, _, _ = ins[k]
        if opc == 0x6F and px.tokname(arg) == DISPOSE and popc == 0x11:
            sites.add((parg, arg))
    if len(sites) != 1: die(f"AcquireLockResult::Dispose call sites (ldloc.s N; callvirt) = {sites}")
    loc, dtok = sites.pop()
    cands = []
    for (flags, toff, tlen, hoff, hlen, _x) in b["eh"]:
        if flags != 0: continue
        got, pos = match(px, il, hoff, HANDLER)
        if got is None: continue
        cands.append((hoff, hlen, pos))
    if len(cands) != 1: die(f"{len(cands)} catch handlers start with CreateIoResultFromException")
    hoff, hlen, run = cands[0]
    end = run + LOG_LEN
    if end + 2 > hoff + hlen or il[end:end + 2] != AFTER: die(f"IL {end:#x} is not ldnull; call (handler layout changed)")
    bounds_inside = [t for o, *_, tg in ins if not run <= o < end for t in tg if run < t < end]  # our own brfalse.s excluded
    for (_f, to, tl, ho, hl, _x) in b["eh"]:
        bounds_inside += [x for x in (to, to + tl, ho, ho + hl) if run < x < end]
    if bounds_inside: die(f"branch/EH boundary inside the Log run: {bounds_inside}")
    patched = build_patch(loc, struct.pack("<I", dtok))
    if il[run:end] == patched:
        state = "patched"
    else:
        got, pos = match(px, il, run, RUN)
        if got is None or pos != end: die(f"Log run at IL {run:#x} differs: {pos}")
        state = "pristine"
    new = il[:run] + patched + il[end:]
    check_body(new, b["eh"])
    return b, b["il"] + run, loc, struct.pack("<I", dtok), state, patched


def find_dll2(arg):
    return find_dll(arg)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    dry = "--dry-run" in sys.argv
    revert = "--revert" in sys.argv
    if not args:
        sys.exit(__doc__)
    dll = find_dll2(args[0])
    data = bytearray(open(dll, "rb").read())
    px = PDX(data)
    b, LOG_START, loc, dispose_tok, state, patched = locate(px, data)
    run = bytes(data[LOG_START:LOG_START + LOG_LEN])

    if state == "patched":
        print(f"already patched: {dll}")
        if not revert:
            return
    if revert:
        bak = dll + ".bak"
        if not os.path.exists(bak):
            sys.exit("ERROR: no .bak to revert from")
        orig = bytearray(open(bak, "rb").read())
        ob = locate(PDX(orig), orig)
        if ob[1] != LOG_START or ob[4] != "pristine":
            sys.exit("ERROR: .bak is not the pristine form of this build — refusing to revert from it")
        data[LOG_START:LOG_START + LOG_LEN] = orig[LOG_START:LOG_START + LOG_LEN]
        if not dry:
            open(dll, "wb").write(bytes(data))
        print(f"reverted lockleak region from .bak: {dll}")
        return

    bak = dll + ".bak"
    if not os.path.exists(bak) and not dry:
        shutil.copy2(dll, bak)
        print(f"wrote backup: {bak}")

    print(f"  MoveNext run  : file {LOG_START:#x}, lock local {loc}")
    print(f"  Dispose token : {dispose_tok[::-1].hex()} (from the method's own Dispose call site)")
    print(f"  replacing     : {run.hex()}")
    print(f"  with          : {patched.hex()}")
    if dry:
        print("DRY RUN — no bytes written.")
        return
    data[LOG_START:LOG_START + LOG_LEN] = patched
    open(dll, "wb").write(bytes(data))
    print(f"PATCHED: {dll}  (catch handler now releases the leaked per-path file lock)")


if __name__ == "__main__":
    main()
