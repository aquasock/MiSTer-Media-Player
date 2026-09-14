"""Small offline RFC 9639 oracle for extracting native CD FLAC subframes.
Not player code. Reconstructed stereo must also match the original WAV PCM.
"""
class Reader:
 def __init__(self,data):self.data=data;self.pos=0
 def u(self,n):
  if self.pos+n>len(self.data)*8:raise ValueError('truncated')
  v=0
  for _ in range(n):
   v=(v<<1)|((self.data[self.pos//8]>>(7-self.pos%8))&1);self.pos+=1
  return v
 def s(self,n):
  v=self.u(n);return v-(1<<n) if n and v&(1<<(n-1)) else v
 def unary(self):
  n=0
  while not self.u(1):n+=1
  return n

def crc(data,width,poly):
 v=0
 for b in data:
  v^=b<<(width-8)
  for _ in range(8):v=((v<<1)^poly if v&(1<<(width-1)) else v<<1)&((1<<width)-1)
 return v

def subframe(r,n,bps):
 start=r.pos
 assert r.u(1)==0
 kind=r.u(6);wasted=r.unary()+1 if r.u(1) else 0;width=bps-wasted
 assert width>0
 if kind==0:samples=[r.s(width)]*n
 elif kind==1:samples=[r.s(width) for _ in range(n)]
 else:
  assert 8<=kind<=12 or kind>=32
  order=kind-31 if kind>=32 else kind-8
  samples=[r.s(width) for _ in range(order)];shift=0
  if kind>=32:
   precision=r.u(4)+1;assert precision<=15
   shift=r.s(5);assert shift>=0
   coeff=[r.s(precision) for _ in range(order)]
  else:coeff={0:[],1:[1],2:[2,-1],3:[3,-3,1],4:[4,-6,4,-1]}[order]
  method=r.u(2);assert method<=1
  po=r.u(4);assert n%(1<<po)==0 and (n>>po)>order
  for part in range(1<<po):
   parameter=r.u(4+method);escape=parameter==(1<<(4+method))-1
   raw_width=r.u(5) if escape else 0
   for _ in range((n>>po)-(order if part==0 else 0)):
    if escape:residual=r.s(raw_width)
    else:
     value=(r.unary()<<parameter)|r.u(parameter);residual=-(value//2)-1 if value&1 else value//2
    assert -(1<<31)<residual<(1<<31)
    samples.append(residual+(sum(c*samples[-j-1] for j,c in enumerate(coeff))>>shift))
 samples=[v<<wasted for v in samples]
 assert all(-(1<<(bps-1))<=v<(1<<(bps-1)) for v in samples)
 return {'start':start,'end':r.pos,'kind':kind,'bps':bps,'samples':samples}

def frames(data):
 assert data[:4]==b'fLaC';pos=4;last=False;info=None
 while not last:
  last=bool(data[pos]&128);kind=data[pos]&127;size=int.from_bytes(data[pos+1:pos+4],'big')
  block=data[pos+4:pos+4+size];assert len(block)==size
  if kind==0:info=block
  pos+=4+size
 assert info is not None
 packed=int.from_bytes(info[10:18],'big');rate=packed>>44;channels=((packed>>41)&7)+1;depth=((packed>>36)&31)+1
 assert (rate,channels,depth)==(44100,2,16)
 r=Reader(data);r.pos=pos*8
 while r.pos<len(data)*8:
  frame_start=r.pos//8
  assert r.u(14)==0x3ffe and r.u(1)==0
  variable=r.u(1);bc=r.u(4);sr=r.u(4);ch=r.u(4);sc=r.u(3);assert r.u(1)==0
  first=r.u(8)
  if first&128:
   leading=0
   while first&(128>>leading):leading+=1
   assert 2<=leading<=7
   for _ in range(leading-1):assert r.u(8)&0xc0==0x80
  assert bc!=0
  n=192 if bc==1 else 576<<(bc-2) if bc<=5 else r.u(8)+1 if bc==6 else r.u(16)+1 if bc==7 else 256<<(bc-8)
  if sr==12:frame_rate=r.u(8)*1000
  elif sr==13:frame_rate=r.u(16)
  elif sr==14:frame_rate=r.u(16)*10
  else:frame_rate={0:rate,9:44100,10:48000}.get(sr)
  assert frame_rate==44100 and sc in (0,4) and ch in (1,8,9,10)
  r.u(8);assert crc(data[frame_start:r.pos//8],8,7)==0
  widths=[16,17] if ch in (8,10) else [17,16] if ch==9 else [16,16]
  sf=[subframe(r,n,b) for b in widths]
  left,right=[x['samples'] for x in sf]
  if ch==8:right=[l-s for l,s in zip(left,right)]
  elif ch==9:left=[s+rr for s,rr in zip(left,right)]
  elif ch==10:
   mid=[(m<<1)|(s&1) for m,s in zip(left,right)]
   left,right=[(m+s)>>1 for m,s in zip(mid,right)],[(m-s)>>1 for m,s in zip(mid,right)]
  if r.pos%8:assert r.u(8-r.pos%8)==0
  r.u(16);assert crc(data[frame_start:r.pos//8],16,0x8005)==0
  yield sf,list(zip(left,right)),{'block_size':n,'assignment':ch,'variable':variable}
