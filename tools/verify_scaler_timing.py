#!/usr/bin/env python3
"""Compare changed scaler pipelines against the accepted pre-change RTL in GHDL.

Extracts production VHDL verbatim; compares every consumed fraction cycle and
resolution-blanking flag. This is arithmetic/control equivalence, not HDMI capture.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--ghdl',default='ghdl')
p.add_argument('--baseline',default='a0f153a')
a=p.parse_args()
old=subprocess.check_output(['git','show',a.baseline+':sys/ascal.vhd'],cwd=root,text=True)
new=(root/'sys/ascal.vhd').read_text()
assert "IF o_newres_blank THEN\n\t\t\t\t\thpix_v" in new
header='''library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
'''
def unit(src,name,updated):
    start=src.index('HSCAL:PROCESS(o_clk) IS')
    end=src.index('o_copyv(1 TO 14)',start)
    body=src[start:end]+'END IF; END PROCESS;\n'
    blank_start=src.index("IF o_vsv(1)='1' AND o_vsv(0)='0' AND o_bufup1='1' THEN")
    blank_end=src.index('-- Simultaneous change',blank_start)
    blank=src[blank_start:blank_end]
    # Discard unrelated frame-bank updates; retain the actual enable and both
    # prioritized counter/blank-flag updates.
    begin=blank.index('IF (o_newres > 0)')
    blank=blank[:blank.index('\n',0)+1]+blank[begin:]
    return header+f'''entity {name} is
 generic(FRAC: integer:=8);
 port(o_clk:in std_logic; o_hacc:in natural; o_hsize:in natural;
 o_vsv:in std_logic_vector(1 downto 0); o_bufup1,swblack,o_fb_ena:in std_logic;
 o_ihsize,i_hrsize,o_ivsize,i_vrsize:in natural;
 fractions:out unsigned(95 downto 0); blanked:out boolean);
end;
architecture rtl of {name} is
 type arr_frac is array(natural range <>) of unsigned(11 downto 0);
 type arr_div is array(natural range <>) of unsigned(20 downto 0);
 signal o_div:arr_div(0 to {3 if updated else 2});
 signal o_dir:arr_frac(0 to 2);
 signal o_hfrac:arr_frac(0 to 9);
 signal o_hdiv_last:unsigned(20 downto 0);
 signal o_newres:integer range 0 to 3;
 signal o_newres_blank:boolean;
begin
''' + body + '''process(o_clk) begin
if rising_edge(o_clk) then
'''+blank+'''end if; end process;
gen:for i in 2 to 9 generate
 fractions((i-1)*12-1 downto (i-2)*12)<=o_hfrac(i);
end generate;
blanked <= '''+('o_newres_blank' if updated else 'o_newres > 0')+''';
end;
'''
bench=header+'''entity test_scaler_timing is end;
architecture test of test_scaler_timing is
signal clk:std_logic:='0';
signal acc,size:natural:=0;
signal vs:std_logic_vector(1 downto 0):="00";
signal buf,sw,fb:std_logic:='0';
signal iw,ir,vw,vr:natural:=0;
type frac_outputs is array(0 to 2) of unsigned(95 downto 0);
signal before_f,after_f:frac_outputs;
signal before_b,after_b:std_logic_vector(0 to 2);
begin
clk<=not clk after 5 ns;
gen:for i in 0 to 2 generate
signal b0,b1:boolean;
begin
old:entity work.scaler_before generic map(FRAC=>4+i*2)
port map(clk,acc,size,vs,buf,sw,fb,iw,ir,vw,vr,before_f(i),b0);
newer:entity work.scaler_after generic map(FRAC=>4+i*2)
port map(clk,acc,size,vs,buf,sw,fb,iw,ir,vw,vr,after_f(i),b1);
before_b(i)<='1' when b0 else '0'; after_b(i)<='1' when b1 else '0';
end generate;
process
variable rng:unsigned(31 downto 0):=x"5a17c931";
begin
for n in 0 to 250000 loop
 wait until falling_edge(clk);
 if n>15 then
 assert before_f=after_f report "fraction value/cycle changed" severity failure;
 assert before_b=after_b report "resolution blanking cycle changed" severity failure;
 end if;
 rng:=rng xor shift_left(rng,13); rng:=rng xor shift_right(rng,17); rng:=rng xor shift_left(rng,5);
 acc<=to_integer(rng(12 downto 0));
 size<=to_integer(rng(24 downto 13));
 vs<=std_logic_vector(rng(1 downto 0)); buf<=rng(2);sw<=rng(3);fb<=rng(4);
 iw<=to_integer(rng(6 downto 5));ir<=to_integer(rng(8 downto 7));
 vw<=to_integer(rng(10 downto 9));vr<=to_integer(rng(12 downto 11));
end loop;
report "PASS scaler: 250000 cycles, FRAC 4/6/8, all consumed fraction stages and exact blanking transitions";
std.env.stop;
wait;
end process;
end;
'''
with tempfile.TemporaryDirectory(prefix='scaler-equivalence-') as tmp:
    path=Path(tmp)/'test.vhd';path.write_text(unit(old,'scaler_before',False)+unit(new,'scaler_after',True)+bench)
    for opts in (['-a','--std=08',str(path)],['-e','--std=08','test_scaler_timing'],['-r','--std=08','test_scaler_timing','--assert-level=error','--ieee-asserts=disable']):
        subprocess.run([a.ghdl,*opts],cwd=tmp,check=True)
