# Walk all FVs of a BIOS-region dump, decompress sections, dump PE/TE images to outdir.
import sys,struct,uuid,os,lzma
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from efidecomp import decompress
rom=open(sys.argv[1],'rb').read(); out=sys.argv[2]; os.makedirs(out,exist_ok=True)
names={}
def sections(d,fguid,ftype,depth=0):
    p=0
    while p+4<=len(d):
        ss=d[p]|d[p+1]<<8|d[p+2]<<16; st=d[p+3]
        if ss<4 or p+ss>len(d): break
        body=d[p+4:p+ss]
        if st==0x01:
            ul,ct=struct.unpack_from('<IB',body,0)
            if ct==0: sections(body[5:],fguid,ftype,depth+1)
            else:
                for pb in (5,4):
                    try: sections(decompress(body[5:],pb),fguid,ftype,depth+1); break
                    except Exception: pass
        elif st==0x02:
            g=uuid.UUID(bytes_le=body[:16]); do,attr=struct.unpack_from('<HH',body,16)
            sub=d[p+do:p+ss]
            if str(g)=='ee4e5898-3914-4259-9d6e-dc7bd79403cf':
                try: sub=lzma.decompress(sub,format=lzma.FORMAT_ALONE)
                except Exception as e: print('lzma fail',fguid,e); sub=b''
            sections(sub,fguid,ftype,depth+1)
        elif st in (0x10,0x12,0x11):
            fn=os.path.join(out,'%s_%02x_%02x.efi'%(fguid,ftype,st)); 
            k=0
            while os.path.exists(fn): k+=1; fn=os.path.join(out,'%s_%02x_%02x_%d.efi'%(fguid,ftype,st,k))
            open(fn,'wb').write(body)
        elif st==0x15: names[fguid]=body.decode('utf-16le','ignore').rstrip('\0')
        elif st==0x17:  # FV image
            fvs(body)
        p=(p+ss+3)&~3
def fvs(img,base=0):
    i=0
    while True:
        i=img.find(b'_FVH',i+1)
        if i<0: return
        fv=i-40
        if fv<0: continue
        ln=struct.unpack_from('<Q',img,fv+32)[0]; hl=struct.unpack_from('<H',img,fv+48)[0]
        if ln>len(img)-fv or ln<0x48 or hl>ln: continue
        p=fv+hl
        ext=struct.unpack_from('<H',img,fv+52)[0]
        while p+24<=fv+ln:
            g=img[p:p+16]
            if g==b'\xff'*16: break
            fs=img[p+20]|img[p+21]<<8|img[p+22]<<16; ft=img[p+18]
            if fs<24 or p+fs>fv+ln: break
            fguid=str(uuid.UUID(bytes_le=g)).upper()
            if ft not in (0xf0,0x02 if False else 0xff):
                if ft in (0x02,0x0b): sections(img[p+24:p+fs],fguid,ft) if ft==0x0b else None
                else: sections(img[p+24:p+fs],fguid,ft)
            p=(p+fs+7)&~7
        i=fv+ln-1
fvs(rom)
open(os.path.join(out,'names.txt'),'w').write('\n'.join('%s %s'%kv for kv in sorted(names.items())))
print(len(os.listdir(out)),'files',len(names),'names')
