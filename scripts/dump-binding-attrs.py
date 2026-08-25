#!/usr/bin/env python3
"""Dump CS2 mod keybinding defaults from .NET attribute metadata.

Mods declare their default keybindings declaratively:

    [SettingsUIKeyboardBinding(BindingKeyboard.F, kSearchAction, ctrl: true)]

The chords never appear as strings anywhere — they are enum + bool arguments
serialized into CustomAttribute blobs, which is why grep/strings can't recover
them and the in-game UI is normally the only place they're visible. This tool
parses the blobs directly so a collision table can be built offline.

Usage:
    dump-binding-attrs.py <Game.dll> <mod.dll> [...]

<Game.dll> (from Cities2_Data/Managed) supplies the BindingKeyboard /
BindingMouse enum value->name maps. Bool args are printed positionally
(b1/b2/b3) — calibrate their meaning against one known chord (e.g. Find It
search = Ctrl+F) before reading modifiers off unfamiliar rows.

Requires dnfile (the repo's RE venv: ~/cs2-patch/revenv). Written against
dnfile 0.18, whose lazy row loading returns None for most row attributes —
hence every name/blob below resolves through row.struct indices + the heaps.
"""
import sys
import dnfile


def read_compressed_uint(b, i):
    v = b[i]
    if v & 0x80 == 0:
        return v, i + 1
    if v & 0xC0 == 0x80:
        return ((v & 0x3F) << 8) | b[i + 1], i + 2
    return ((v & 0x1F) << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3], i + 4


def read_serstring(b, i):
    if b[i] == 0xFF:
        return None, i + 1
    n, i = read_compressed_uint(b, i)
    return b[i:i + n].decode("utf-8", "replace"), i + n


class Assembly:
    def __init__(self, path):
        self.pe = dnfile.dnPE(path)
        self.t = self.pe.net.mdtables

    def sget(self, idx):
        try:
            s = self.pe.net.strings.get(idx)
            return s.value.decode() if isinstance(getattr(s, "value", s), bytes) else str(
                getattr(s, "value", s))
        except Exception:
            return f"<str:{idx}>"

    def bget(self, idx):
        try:
            b = self.pe.net.blobs.get(idx)
            v = getattr(b, "value", b)
            return bytes(v) if v is not None else b""
        except Exception:
            return b""

    def field_name(self, field_row):
        return self.sget(field_row.struct.Name_StringIndex)

    def enum_map(self, name):
        """value -> field name for enum TypeDef `name`."""
        t = self.t
        for td in t.TypeDef.rows:
            if str(td.TypeName) != name:
                continue
            by_index = {f.row_index: self.field_name(f.row) for f in (td.FieldList or [])}
            fields = {}
            for c in t.Constant.rows:
                try:
                    if c.Parent.table.name != "Field":
                        continue
                    ri = c.Parent.row_index
                    if ri not in by_index:
                        continue
                    blob = c.Value if isinstance(c.Value, (bytes, bytearray)) else \
                        self.bget(c.struct.Value_BlobIndex)
                    v = int.from_bytes(bytes(blob)[:4], "little", signed=True)
                    fields[v] = by_index[ri]
                except Exception:
                    continue
            if fields:
                return fields
        return {}

    def memberref_info(self, mr_row):
        """(declaring type name, member name, sig blob) for a MemberRef row."""
        st = mr_row.struct
        name = self.sget(st.Name_StringIndex)
        sig = self.bget(st.Signature_BlobIndex)
        tname = "?"
        try:
            cls = mr_row.Class
            if cls.table.name == "TypeRef":
                tr = self.t.TypeRef.rows[cls.row_index - 1]
                tname = self.sget(tr.struct.TypeName_StringIndex)
        except Exception:
            pass
        return tname, name, sig

    def attr_parent_name(self, ca_row):
        """Best-effort short name of the attribute's parent (property/method/type)."""
        try:
            p = ca_row.Parent
            tbl = p.table.name
            row = getattr(p, "row", None)
            st = getattr(row, "struct", None)
            for f in ("Name_StringIndex", "TypeName_StringIndex"):
                if st is not None and hasattr(st, f):
                    return f"{tbl}:{self.sget(getattr(st, f))}"
            return tbl
        except Exception:
            return "?"


ELEM_STRING, ELEM_BOOL = 0x0E, 0x02


def parse_sig_param_types(sigblob):
    """Element-type list for a MemberRef method signature (subset)."""
    b = sigblob
    i = 1  # calling convention
    n, i = read_compressed_uint(b, i)
    while b[i] in (0x1F, 0x20):  # cmods on return type
        i += 1
        _, i = read_compressed_uint(b, i)
    i += 1  # return type (void expected)
    types = []
    for _ in range(n):
        et = b[i]
        i += 1
        if et in (0x11, 0x12):  # valuetype / class + coded token
            _, i = read_compressed_uint(b, i)
            types.append(0x55 if et == 0x11 else 0x51)
        else:
            types.append(et)
    return types


def parse_blob(b, param_types, enum_maps):
    """Parse a CustomAttribute value blob: fixed args per sig, then named args."""
    out, i = [], 2  # skip 0x0001 prolog
    booln = 0
    for et in param_types:
        if et == ELEM_STRING:
            s, i = read_serstring(b, i)
            out.append(repr(s))
        elif et == ELEM_BOOL:
            booln += 1
            out.append(f"b{booln}={bool(b[i])}")
            i += 1
        elif et in (0x55, 0x08):  # enum (as i4) / int32
            v = int.from_bytes(b[i:i + 4], "little", signed=True)
            i += 4
            name = next((m[v] for m in enum_maps if v in m), None)
            out.append(f"{name or '?'}({v})")
        elif et in (0x04, 0x05):
            out.append(str(b[i]))
            i += 1
        else:
            out.append(f"<et {et:#x}>")
    named = []
    if i + 2 <= len(b):
        nn = int.from_bytes(b[i:i + 2], "little")
        i += 2
        for _ in range(nn):
            i += 1  # FIELD / PROPERTY marker
            ft = b[i]
            i += 1
            if ft in (0x55, 0x51):
                _, i = read_serstring(b, i)  # enum type name
            nm, i = read_serstring(b, i)
            if ft == ELEM_STRING:
                v, i = read_serstring(b, i)
                named.append(f"{nm}={v!r}")
            elif ft == ELEM_BOOL:
                named.append(f"{nm}={bool(b[i])}")
                i += 1
            else:
                v = int.from_bytes(b[i:i + 4], "little", signed=True)
                i += 4
                named.append(f"{nm}={v}")
    return out, named


def main():
    game = Assembly(sys.argv[1])
    enum_maps = [game.enum_map("BindingKeyboard"), game.enum_map("BindingMouse"),
                 game.enum_map("BindingGamepad")]
    print(f"enum maps: kb={len(enum_maps[0])} mouse={len(enum_maps[1])} pad={len(enum_maps[2])}")

    for path in sys.argv[2:]:
        asm = Assembly(path)
        t = asm.t
        print(f"\n=== {path.split('/')[-1]} ===")
        ca = getattr(t, "CustomAttribute", None)
        if ca is None:
            print("  (no CustomAttribute table)")
            continue
        for row in ca.rows:
            try:
                if row.Type.table.name != "MemberRef":
                    continue
                mr = t.MemberRef.rows[row.Type.row_index - 1]
                tname, mname, sig = asm.memberref_info(mr)
            except Exception:
                continue
            if not (tname.startswith("SettingsUI") and "Binding" in tname):
                continue
            parent = asm.attr_parent_name(row)
            try:
                blob = row.Value if isinstance(row.Value, (bytes, bytearray)) else \
                    asm.bget(row.struct.Value_BlobIndex)
                fixed, named = parse_blob(bytes(blob), parse_sig_param_types(sig), enum_maps)
                label = tname.replace("SettingsUI", "").replace("Attribute", "")
                print(f"  {parent:44s} {label:16s} " + ", ".join(fixed)
                      + ("  [" + ", ".join(named) + "]" if named else ""))
            except Exception as e:
                print(f"  {parent:44s} {tname}  <parse error: {e}>")


if __name__ == "__main__":
    main()
