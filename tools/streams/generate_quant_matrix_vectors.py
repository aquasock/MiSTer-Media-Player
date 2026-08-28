#!/usr/bin/env python3
"""Independent integer IQ vectors; no codec or RTL tables imported."""
from pathlib import Path
import argparse,itertools
Z=[0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63]
A=[0,8,16,24,1,9,2,10,17,25,32,40,48,56,57,49,41,33,26,18,3,11,4,12,19,27,34,42,50,58,35,43,51,59,20,28,5,13,6,14,21,29,36,44,52,60,37,45,53,61,22,30,7,15,23,31,38,46,54,62,39,47,55,63]
D=[8,16,19,22,26,27,29,34,16,16,22,24,27,29,34,37,19,22,26,27,29,34,34,38,22,22,26,27,29,34,37,40,22,26,27,29,32,35,40,48,26,27,29,32,35,40,48,58,26,27,29,34,38,46,56,69,27,29,35,38,46,56,69,83]
N=[0,1,2,3,4,5,6,7,8,10,12,14,16,18,20,22,24,28,32,36,40,44,48,52,56,64,72,80,88,96,104,112]
def trunc(n,d): return (abs(n)//d)*(-1 if n<0 else 1)
def main():
 p=argparse.ArgumentParser();p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 controls=[];levels=[];expected=[];headers=[]
 for mode in range(3):
  wi=D if mode==0 else ([8]*64 if mode==1 else [8]+[(i*37+19)%255+1 for i in range(1,64)])
  wn=[16]*64 if mode==0 else ([8]*64 if mode==1 else [(i*53+11)%255+1 for i in range(64)])
  bits='1'*62+('00' if mode==0 else '1'+''.join(f'{wi[i]:08b}' for i in Z)+'1'+''.join(f'{wn[i]:08b}' for i in Z))
  header=b'\0\0\1\xb3'+int(bits,2).to_bytes(len(bits)//8,'big')
  headers.extend(header+b'\xff'*(140-len(header)))
  for dc,intra,qt,alt,qs in itertools.product(range(4),range(2),range(2),range(2),(1,2,8,31)):
   controls.append((mode<<10)|(dc<<8)|(intra<<7)|(qt<<6)|(alt<<5)|qs)
   # Coefficients include signs, zero, small fractions and saturation extremes.
   natural=[(0,1,-1,7,-9,511,-1024,2047)[(i*3+dc)%8] for i in range(64)]
   natural[0]=1023 if intra else -7
   levels.extend(natural[i]&8191 for i in (A if alt else Z))
   out=[];scale=N[qs] if qt else 2*qs
   for i,q in enumerate(natural):
    if intra and i==0:v=q*(8>>dc)
    else:v=trunc((2*q+(0 if intra else (q>0)-(q<0)))*(wi[i] if intra else wn[i])*scale,32)
    out.append(max(-2048,min(2047,v)))
   if sum(out)%2==0:out[-1]^=1
   expected.extend(v&4095 for v in out)
 for name,values,width in [('controls',controls,3),('levels',levels,4),('expected',expected,3),('headers',headers,2)]:
  (a.output/(name+'.hex')).write_text(''.join(f'{v:0{width}x}\n' for v in values))
 print(f'IQ vectors: {len(controls)} cases, {len(expected)} coefficients, default/two custom matrices, both scans and quantizer mappings')
if __name__=='__main__':main()
