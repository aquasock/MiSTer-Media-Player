#!/usr/bin/env python3
"""Prove the production scaler carry-select sum matches its original wrap/clip."""
from pathlib import Path
import subprocess,tempfile,os
root=Path(__file__).resolve().parents[1]
s=(root/'sys/ascal.vhd').read_text()
def extract(name):
 start=s.index('\tFUNCTION '+name+'(');end=s.index('END FUNCTION',start);end=s.index(';',end)+1
 return s[start:end]
bench='''library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity test_poly_sum is end;
architecture test of test_poly_sum is
'''+extract('bound')+'\n'+extract('poly_sum_bound')+'''
begin
process
 variable rng:unsigned(31 downto 0):=x"a123b45c";
 variable a,b:signed(26 downto 0);
 variable old_value,new_value:unsigned(7 downto 0);
 procedure check(a,b:signed(26 downto 0)) is
 begin
 assert poly_sum_bound(a,b)=bound(unsigned(a(26 downto 8)+b(26 downto 8)),15)
 report "polyphase sum/truncation/saturation mismatch" severity failure;
 end procedure;
begin
 -- Exercise every upper sum and both low carry outcomes, including sign,
 -- upper-sum wrap, the last fractional bit and both clipping thresholds.
 for hi in 0 to 4095 loop
 for lo in 0 to 255 loop
 a:=signed(to_unsigned(hi*32768+(lo mod 128)*256,27));
 b:=signed(to_unsigned((lo/128)*32768+127*256,27));
 check(a,b);
 end loop;
 end loop;
 for n in 0 to 999999 loop
 rng:=rng xor shift_left(rng,13);rng:=rng xor shift_right(rng,17);rng:=rng xor shift_left(rng,5);
 a:=signed(rng(26 downto 0));
 rng:=rng xor shift_left(rng,13);rng:=rng xor shift_right(rng,17);rng:=rng xor shift_left(rng,5);
 b:=signed(rng(26 downto 0));check(a,b);
 end loop;
 report "PASS polyphase sum: 1048576 boundary/carry cases and 1000000 random pairs, exact 19-bit wrap, clipping and truncation";
 std.env.stop;wait;
end process;
end;
'''
with tempfile.TemporaryDirectory(prefix='scaler-poly-') as d:
 p=Path(d)/'test.vhd';p.write_text(bench)
 for opts in (['-a','--std=08',str(p)],['-e','--std=08','test_poly_sum'],['-r','--std=08','test_poly_sum','--assert-level=error']):
  subprocess.run([os.environ.get('GHDL','ghdl'),*opts],cwd=d,check=True)
