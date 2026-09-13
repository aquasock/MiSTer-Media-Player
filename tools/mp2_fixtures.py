"""Deterministic valid and malformed Layer II fixtures, no binary check-ins."""
from mp2_model import ROWS, BITS, LEVELS
import random
class Writer:
    def __init__(self): self.bits=[]
    def put(self,v,n): self.bits += [(v>>i)&1 for i in reversed(range(n))]
    def bytes(self,size):
        assert len(self.bits)<=size*8
        bits=self.bits+[0]*(size*8-len(self.bits))
        return bytes(sum(bits[i+j]<<(7-j) for j in range(8)) for i in range(0,len(bits),8))
def frame(q,mode=0,extension=0,seed=1):
    rng=random.Random(seed); w=Writer(); bound=(extension+1)*4 if mode==1 else 27
    h=0xfffd0000 | (14<<12) | (1<<10) | (mode<<6) | (extension<<4)
    w.put(h,32)
    alloc=[[0,0] for _ in range(27)]; scfsi=[[0,0] for _ in range(27)]; sf=[[[0]*3 for _ in range(2)] for _ in range(27)]
    band=0 if q in (15,16) else 3
    alloc[band]=[q,q]
    if mode==1: alloc[20]=[4,4]
    alloc[26]=[2,2]
    for sb in range(27):
        row=3 if sb<3 else 2 if sb<11 else 1 if sb<23 else 0
        nb=4 if sb<11 else 3 if sb<23 else 2
        for ch in range(2 if sb<bound else 1): w.put(ROWS[row].index(alloc[sb][ch]),nb)
    for sb in range(27):
        for ch in range(2):
            if alloc[sb][ch]:
                scfsi[sb][ch]=(seed+sb+ch)%4; w.put(scfsi[sb][ch],2)
    for sb in range(27):
        for ch in range(2):
            if not alloc[sb][ch]: continue
            sel=scfsi[sb][ch]; a=12+ch*5; b=15+ch*6; c=18+ch*7
            if sel==0: values=[a,b,c]
            elif sel==1: values=[a,c]
            elif sel==2: values=[a]
            else: values=[a,b]
            for v in values: w.put(v,6)
    for part in range(3):
        for granule in range(4):
            for sb in range(27):
                for ch in range(2 if sb<bound else 1):
                    a=alloc[sb][ch]
                    if not a: continue
                    lev=LEVELS[a]; codes=[rng.randrange(lev) for _ in range(3)]
                    if a in (1,2,4): w.put(codes[0]+lev*(codes[1]+lev*codes[2]),BITS[a])
                    else:
                        for v in codes: w.put(v,BITS[a])
    return w.bytes(1152)
