import struct, pathlib, json, sys
MAGICS={0xfeedfacf:'64',0xcffaedfe:'64-be',0xfeedface:'32',0xcefaedfe:'32-be'}
LC_ENCRYPTION_INFO=0x21; LC_ENCRYPTION_INFO_64=0x2c; LC_CODE_SIGNATURE=0x1d; LC_LOAD_DYLIB=0xc; LC_LOAD_WEAK_DYLIB=0x80000018; LC_REEXPORT_DYLIB=0x8000001f

def one(p):
 b=p.read_bytes()
 if len(b) < 4: return None
 le=True; magic=struct.unpack_from('<I',b)[0]
 if magic not in MAGICS:
  magic=struct.unpack_from('>I',b)[0]; le=False
 if magic not in MAGICS:return None
 e='<' if le else '>'; is64=MAGICS[magic].startswith('64'); off=32 if is64 else 28
 if is64: cputype,cpusubtype,filetype,ncmds,sizeofcmds,flags,res=struct.unpack_from(e+'iiIIIII',b,4)
 else: cputype,cpusubtype,filetype,ncmds,sizeofcmds,flags=struct.unpack_from(e+'iiIIII',b,4)
 enc=[]; sig=[]; dylibs=[]; pos=off
 for _ in range(ncmds):
  cmd,sz=struct.unpack_from(e+'II',b,pos)
  if cmd in (LC_ENCRYPTION_INFO,LC_ENCRYPTION_INFO_64): enc.append({'cryptoff':struct.unpack_from(e+'I',b,pos+8)[0],'cryptsize':struct.unpack_from(e+'I',b,pos+12)[0],'cryptid':struct.unpack_from(e+'I',b,pos+16)[0]})
  if cmd==LC_CODE_SIGNATURE: sig.append({'dataoff':struct.unpack_from(e+'I',b,pos+8)[0],'datasize':struct.unpack_from(e+'I',b,pos+12)[0]})
  if cmd in (LC_LOAD_DYLIB,LC_LOAD_WEAK_DYLIB,LC_REEXPORT_DYLIB):
   no=struct.unpack_from(e+'I',b,pos+8)[0]; dylibs.append(b[pos+no:pos+sz].split(b'\0',1)[0].decode(errors='replace'))
  pos+=sz
 return {'path':str(p),'size':len(b),'magic':hex(magic),'arch':'arm64' if cputype==0x100000c else hex(cputype),'filetype':filetype,'ncmds':ncmds,'encryption':enc,'code_signature':sig,'dylibs':dylibs}
root=pathlib.Path(sys.argv[1]); out=[]
for p in root.rglob('*'):
 if p.is_file():
  x=one(p)
  if x: out.append(x)
print(json.dumps(out,indent=2))
