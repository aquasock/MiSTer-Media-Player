"""Engineering model of MPEG-1 Layer II; serial RTL arithmetic oracle."""
from pathlib import Path
import re, math
import numpy as np
BITRATES=[0,32,48,56,64,80,96,112,128,160,192,224,256,320,384]
ROWS=[[0,1,2,17],[0,1,2,3,4,5,6,17],[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,17],[0,1,3,5,6,7,8,9,10,11,12,13,14,15,16,17]]
LEVELS=[0,3,5,7,9]+[(1<<n)-1 for n in range(4,17)]
BITS=[0,5,7,3,10]+list(range(4,17))
class Bits:
    def __init__(self,b): self.b=b; self.p=0
    def get(self,n):
        assert self.p+n<=len(self.b)*8
        v=0
        for _ in range(n):
            v=(v<<1)|((self.b[self.p//8]>>(7-self.p%8))&1); self.p+=1
        return v

def decode_subbands(data):
    pos=0
    while pos<len(data):
        h=int.from_bytes(data[pos:pos+4],'big')
        assert h>>21==2047 and ((h>>19)&3)==3 and ((h>>17)&3)==2
        kbps=BITRATES[(h>>12)&15]; mode=(h>>6)&3
        assert ((h>>10)&3)==1 and kbps>=112
        size=3*kbps+((h>>9)&1)
        b=Bits(data[pos:pos+size]); b.get(32)
        if not ((h>>16)&1): b.get(16)
        nch=1 if mode==3 else 2
        bound=min(27, (((h>>4)&3)+1)*4 if mode==1 else (0 if mode==3 else 32))
        alloc=np.zeros((32,2),int); scfsi=alloc.copy(); sf=np.zeros((32,2,3),int)
        for sb in range(27):
            row=3 if sb<3 else 2 if sb<11 else 1 if sb<23 else 0
            nb=4 if sb<11 else 3 if sb<23 else 2
            alloc[sb,0]=ROWS[row][b.get(nb)]
            alloc[sb,1]=ROWS[row][b.get(nb)] if sb<bound else alloc[sb,0]
        for sb in range(27):
            for ch in range(nch):
                if alloc[sb,ch]: scfsi[sb,ch]=b.get(2)
        for sb in range(27):
            for ch in range(nch):
                if not alloc[sb,ch]: continue
                sel=scfsi[sb,ch]; a=b.get(6)
                if sel==0: sf[sb,ch]=[a,b.get(6),b.get(6)]
                elif sel==1: sf[sb,ch]=[a,a,b.get(6)]
                elif sel==2: sf[sb,ch]=[a,a,a]
                else:
                    z=b.get(6); sf[sb,ch]=[a,z,z]
        if nch==1: sf[:,1]=sf[:,0]
        for part in range(3):
            for gran in range(4):
                out=np.zeros((3,2,32))
                for sb in range(27):
                    for ch in range(2 if sb<bound else 1):
                        q=alloc[sb,ch]
                        if not q: continue
                        lev=LEVELS[q]
                        if q in (1,2,4):
                            code=b.get(BITS[q]); vals=[]
                            for _ in range(3): vals.append(code%lev-lev//2); code//=lev
                        else: vals=[b.get(BITS[q])-lev//2 for _ in range(3)]
                        for dst in ([ch] if sb<bound else [0,1]):
                            s=sf[sb,dst,part]
                            scale=0 if s==63 else 4*2**(-s/3)/lev
                            out[:,dst,sb]=np.array(vals)*scale
                yield out
        pos+=size


def tables():
    src=(Path(__file__).parent/'reference/pl_mpeg.h').read_text()
    a=src.split('static const float PLM_AUDIO_SYNTHESIS_WINDOW[] = {')[1].split('};')[0]
    window=np.array([float(x) for x in re.findall(r'-?\d+\.\d+',a)])/32768
    matrix=np.cos(np.pi/64*(np.arange(64)[:,None]+16)*(2*np.arange(32)[None,:]+1))
    return matrix,window

def synthesize(blocks):
    matrix,window=tables(); v=np.zeros((2,1024)); pcm=[]
    for block in blocks:
        for sample in block:
            v[:,64:]=v[:,:-64].copy(); v[:,:64]=sample@matrix.T
            u=np.zeros((2,512))
            for i in range(8):
                u[:,i*64:i*64+32]=v[:,i*128:i*128+32]
                u[:,i*64+32:i*64+64]=v[:,i*128+96:i*128+128]
            pcm.extend(((u*window).reshape(2,16,32).sum(axis=1).T*32768).tolist())
    return np.array(pcm)
if __name__=='__main__':
    import sys
    a=synthesize(decode_subbands(Path(sys.argv[1]).read_bytes()))
    np.rint(a).clip(-32768,32767).astype('<i2').tofile(sys.argv[2])
    if len(sys.argv)>3:
        ref=np.fromfile(sys.argv[3],'<i2').reshape(-1,2).astype(float)
        print(a.shape,ref.shape,'gain',np.sum(a*ref)/np.sum(a*a),'error',np.max(np.abs(a-ref)), 'SNR',10*np.log10(np.sum(ref**2)/np.sum((a-ref)**2)))
