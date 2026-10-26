#!/usr/bin/env python3
import struct, pathlib, json, sys
p=pathlib.Path(sys.argv[1]); b=p.read_bytes(); e='<'
if struct.unpack_from('<I',b)[0] != 0xfeedfacf: raise SystemExit('expected arm64 Mach-O')
ncmds=struct.unpack_from('<I',b,16)[0]; sections=[]; segments=[]; pos=32
for _ in range(ncmds):
 cmd,sz=struct.unpack_from(e+'II',b,pos)
 if cmd==0x19:
  seg=b[pos:pos+sz]; name=seg[8:24].split(b'\0',1)[0].decode(errors='replace'); vmaddr,vmsize,fileoff,filesize=struct.unpack_from(e+'QQQQ',seg,24); n=struct.unpack_from(e+'I',seg,64)[0]; segments.append({'name':name,'vmaddr':vmaddr,'vmsize':vmsize,'fileoff':fileoff,'filesize':filesize}); q=pos+72
  for i in range(n):
   s=b[q:q+80]; sn=s[:16].split(b'\0',1)[0].decode(errors='replace'); sg=s[16:32].split(b'\0',1)[0].decode(errors='replace'); addr,size,off=struct.unpack_from(e+'QQI',s,32); sections.append({'seg':sg,'name':sn,'addr':addr,'size':size,'off':off}); q+=80
 pos+=sz
def sec(name): return next((x for x in sections if x['name']==name),None)
def vm(a):
 for s in segments:
  if s['vmaddr']<=a<s['vmaddr']+s['vmsize']: return s['fileoff']+a-s['vmaddr']
def cstr(a):
 o=vm(a)
 if o is None or o>=len(b): return None
 z=b.find(b'\0',o); return b[o:z].decode(errors='replace')
def ptr(o): return struct.unpack_from(e+'Q',b,o)[0]
classes=[]; cl=sec('__objc_classlist')
for i in range(0,cl['size'],8):
 c=ptr(cl['off']+i); co=vm(c)
 if not co: continue
 isa,superc,cache,vtable,data=struct.unpack_from(e+'QQQQQ',b,co); ro=vm(data&~7)
 if not ro: continue
 vals=struct.unpack_from(e+'IIIIQQQQQQQ',b,ro); nameptr=vals[5]; base=vals[6]; cls={'name':cstr(nameptr),'methods':[],'address':hex(c),'super_address':hex(superc) if superc else None}
 if base:
  mo=vm(base); ent,count=struct.unpack_from(e+'II',b,mo); rel=bool(ent&0x80000000); ent&=0x7fffffff
  if ent<12 or ent>64: ent=24; rel=False
  for j in range(count):
   q=mo+8+j*ent
   if rel:
    a,t,imp=struct.unpack_from(e+'iii',b,q); basej=base+8+j*ent; a=basej+a; t=basej+t; imp=basej+imp
   else: a,t,imp=struct.unpack_from(e+'QQQ',b,q)
   cls['methods'].append({'name':cstr(a),'types':cstr(t),'imp_vm':hex(imp)})
 classes.append(cls)
by={c['address']:c['name'] for c in classes}
for c in classes: c['super_name']=by.get(c['super_address'])
print(json.dumps({'segments':segments,'sections':sections,'classes':[c for c in classes if c['name'] in ['SampleHandler','IESSampleHandler','IESBroadcastVideoBufferProcessor','IESBroadcastAppCommunicator']]},indent=2))
