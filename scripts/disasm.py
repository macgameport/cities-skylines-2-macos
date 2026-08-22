import sys, struct
import dnfile

path = sys.argv[1]
target_type = "LongFile"
target_methods = ["GetFileHandle", "Open", "OpenRead"]

pe = dnfile.dnPE(path)
md = pe.net.metadata
tables = pe.net.mdtables

def us_string(index):
    # user string (#US) heap
    try:
        return pe.net.user_strings.get(index).value
    except Exception:
        try:
            data = md.streams.get(b'#US').get_bytes()
            # parse blob at index
            i = index
            b0 = data[i]; i+=1
            if b0 & 0x80:
                if b0 & 0x40:
                    ln = ((b0&0x1f)<<24)|(data[i]<<16)|(data[i+1]<<8)|data[i+2]; i+=3
                else:
                    ln = ((b0&0x3f)<<8)|data[i]; i+=1
            else:
                ln = b0
            raw = data[i:i+ln]
            return raw[:-1].decode('utf-16-le', 'replace') if ln%2==1 else raw.decode('utf-16-le','replace')
        except Exception as e:
            return f"<us:{index:#x}>"

def token_name(tok):
    tbl = (tok >> 24) & 0xff
    rid = tok & 0xffffff
    try:
        if tbl == 0x0a:  # MemberRef
            r = tables.MemberRef.rows[rid-1]
            cls = ""
            try:
                cls = r.Class.row.TypeName + "."
            except Exception:
                pass
            return cls + r.Name
        if tbl == 0x06:  # MethodDef
            r = tables.MethodDef.rows[rid-1]
            return r.Name
        if tbl == 0x2b:  # MethodSpec
            return "methodspec"
        if tbl == 0x01:  # TypeRef
            r = tables.TypeRef.rows[rid-1]
            return r.TypeName
    except Exception as e:
        return f"<tok {tok:#x} err {e}>"
    return f"<tok {tok:#x}>"

# opcode table (subset, enough for method bodies)
OPS = {
0x00:("nop",0),0x01:("break",0),0x02:("ldarg.0",0),0x03:("ldarg.1",0),0x04:("ldarg.2",0),0x05:("ldarg.3",0),
0x06:("ldloc.0",0),0x07:("ldloc.1",0),0x08:("ldloc.2",0),0x09:("ldloc.3",0),0x0a:("stloc.0",0),0x0b:("stloc.1",0),
0x0c:("stloc.2",0),0x0d:("stloc.3",0),0x0e:("ldarg.s",1),0x0f:("ldarga.s",1),0x10:("starg.s",1),0x11:("ldloc.s",1),
0x12:("ldloca.s",1),0x13:("stloc.s",1),0x14:("ldnull",0),0x15:("ldc.i4.m1",0),0x16:("ldc.i4.0",0),0x17:("ldc.i4.1",0),
0x18:("ldc.i4.2",0),0x19:("ldc.i4.3",0),0x1a:("ldc.i4.4",0),0x1b:("ldc.i4.5",0),0x1c:("ldc.i4.6",0),0x1d:("ldc.i4.7",0),
0x1e:("ldc.i4.8",0),0x1f:("ldc.i4.s",1),0x20:("ldc.i4",4),0x21:("ldc.i8",8),0x22:("ldc.r4",4),0x23:("ldc.r8",8),
0x25:("dup",0),0x26:("pop",0),0x27:("jmp",4),0x28:("call",4),0x29:("calli",4),0x2a:("ret",0),0x2b:("br.s",1),
0x2c:("brfalse.s",1),0x2d:("brtrue.s",1),0x2e:("beq.s",1),0x2f:("bge.s",1),0x30:("bgt.s",1),0x31:("ble.s",1),
0x32:("blt.s",1),0x33:("bne.un.s",1),0x34:("bge.un.s",1),0x35:("bgt.un.s",1),0x36:("ble.un.s",1),0x37:("blt.un.s",1),
0x38:("br",4),0x39:("brfalse",4),0x3a:("brtrue",4),0x3b:("beq",4),0x3c:("bge",4),0x3d:("bgt",4),0x3e:("ble",4),
0x3f:("blt",4),0x40:("bne.un",4),0x41:("bge.un",4),0x42:("bgt.un",4),0x43:("ble.un",4),0x44:("blt.un",4),
0x45:("switch",-1),0x46:("ldind.i1",0),0x47:("ldind.u1",0),0x48:("ldind.i2",0),0x49:("ldind.u2",0),0x4a:("ldind.i4",0),
0x4b:("ldind.u4",0),0x4c:("ldind.i8",0),0x4d:("ldind.i",0),0x4e:("ldind.r4",0),0x4f:("ldind.r8",0),0x50:("ldind.ref",0),
0x58:("add",0),0x59:("sub",0),0x5a:("mul",0),0x5b:("div",0),0x61:("xor",0),0x62:("shl",0),0x63:("shr",0),
0x65:("neg",0),0x66:("not",0),0x67:("conv.i1",0),0x68:("conv.i2",0),0x69:("conv.i4",0),0x6a:("conv.i8",0),
0x6f:("callvirt",4),0x70:("cpobj",4),0x71:("ldobj",4),0x72:("ldstr",4),0x73:("newobj",4),0x74:("castclass",4),
0x75:("isinst",4),0x79:("unbox",4),0x7a:("throw",0),0x7b:("ldfld",4),0x7c:("ldflda",4),0x7d:("stfld",4),
0x7e:("ldsfld",4),0x7f:("ldsflda",4),0x80:("stsfld",4),0x81:("stobj",4),0x8c:("box",4),0x8d:("newarr",4),
0x8e:("ldlen",0),0x9a:("ldelem.ref",0),0xa2:("stelem.ref",0),0x25:("dup",0),0xdd:("leave",4),0xde:("leave.s",1),
}

def disasm(il, base_off):
    i = 0
    out = []
    while i < len(il):
        off = i
        op = il[i]; i += 1
        if op == 0xfe:
            op2 = il[i]; i += 1
            names = {0x01:"ceq",0x02:"cgt",0x03:"cgt.un",0x04:"clt",0x05:"clt.un",0x09:"ldarg",0x0a:"ldarga",0x0b:"starg",0x0c:"ldloc",0x0d:"ldloca",0x0e:"stloc",0x15:"initobj",0x16:"constrained.",0x1e:"readonly."}
            nm = names.get(op2, f"fe{op2:02x}")
            operand=""
            if op2 in (0x09,0x0a,0x0b,0x0c,0x0d,0x0e):
                v=struct.unpack_from('<H',il,i)[0]; i+=2; operand=str(v)
            elif op2 in (0x15,0x16):
                t=struct.unpack_from('<I',il,i)[0]; i+=4; operand=token_name(t)
            out.append((off, f"{nm} {operand}".strip(), None))
            continue
        nm, sz = OPS.get(op, (f"?{op:02x}", 0))
        operand=""; extra=None
        if sz == 1:
            v = il[i];
            if nm in ("br.s","brfalse.s","brtrue.s","beq.s","bge.s","bgt.s","ble.s","blt.s","bne.un.s","leave.s") or nm.endswith(".s") and nm[:-2] in ("br","brfalse","brtrue","beq","bge","bgt","ble","blt"):
                sv = v-256 if v>127 else v
                extra = i+1+sv
                operand=f"-> {base_off+extra:04x}"
            else:
                operand=str(v)
            i+=1
        elif sz == 4:
            v=struct.unpack_from('<I',il,i)[0]; i+=4
            if nm in ("call","callvirt","newobj"):
                operand=token_name(v)
            elif nm=="ldstr":
                operand='"'+us_string(v & 0xffffff)+'"'
            elif nm in ("br","brfalse","brtrue","beq","bge","bgt","ble","blt","bne.un","leave"):
                sv=struct.unpack('<i',struct.pack('<I',v))[0]; extra=i+sv; operand=f"-> {base_off+extra:04x}"
            else:
                operand=f"{v:#x}"
        elif sz == 8:
            i+=8
        out.append((off, f"{nm} {operand}".strip(), None))
    return out

for t in tables.TypeDef.rows:
    if t.TypeName != target_type: continue
    for m in t.MethodList:
        mm = m.row
        if mm.Name not in target_methods: continue
        rva = mm.Rva
        if not rva: continue
        foff = pe.get_offset_from_rva(rva)
        b0 = pe.get_data(rva,1)[0]
        if (b0 & 0x3) == 0x2:  # tiny header
            codesize = b0 >> 2
            il_foff = foff+1
        else:  # fat header (12 bytes)
            hdr = pe.get_data(rva,12)
            codesize = struct.unpack_from('<I',hdr,4)[0]
            il_foff = foff+12
        il = pe.get_data(pe.get_rva_from_offset(il_foff), codesize)
        print(f"\n===== {target_type}.{mm.Name}  (IL file offset {il_foff:#x}, size {codesize}) =====")
        for off, text, _ in disasm(bytes(il), 0):
            print(f"  {off:04x}: {text}    [file {il_foff+off:#x}]")
