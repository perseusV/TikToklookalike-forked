#!/usr/bin/env python3
import json, pathlib, sys
from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM

binary=pathlib.Path(sys.argv[1]); meta=json.load(open(sys.argv[2])); b=binary.read_bytes(); md=Cs(CS_ARCH_ARM64,CS_MODE_ARM); md.detail=False
methods=[]
for c in meta['classes']:
    if c['name'] in ('IESSampleHandler','IESBroadcastVideoBufferProcessor','IESBroadcastAppCommunicator'):
        for m in c['methods']:
            if m.get('name') and m.get('imp_vm','0') not in ('0x0','0x0'):
                methods.append((c['name'],m['name'],int(m['imp_vm'],16)))
methods.sort(key=lambda x:x[2])
for idx,(cls,name,addr) in enumerate(methods):
    if name not in {'broadcastStartedWithSetupInfo:','processSampleBuffer:withType:','processVideoSampleBuffer:','processMicAudioSampleBuffer:','processAppAudioSampleBuffer:','launchWithConfig:','processVideoSampleBuffer:','processPauseBuffer:','sendToEncode:pts_ms:','didEncodeData:timestamp:dts:videoFrameType:sourceBuffer:','tellContainerAppEncodedVideoData:','tellContainerAppAudioBinaryData:length:','passMessage:forKey:','listenMessageWithKey:handler:'}: continue
    end=methods[idx+1][2] if idx+1<len(methods) else addr+0x400
    size=min(max(end-addr,4),0x800)
    off=addr-0x100000000
    print(f'\n### {cls} {name} vm={hex(addr)} fileoff={hex(off)} size={hex(size)}')
    for ins in md.disasm(b[off:off+size],addr):
        print(f'{ins.address:016x}: {ins.mnemonic:8} {ins.op_str}')
