from pathlib import Path
import subprocess,json,time,hashlib
root=Path('/run/media/vash/GIT/MiSTer-Media-Player');base=Path('/home/vash/mister-builds/entry599')
tb=(root/'tools/streams/tb_h262_interlaced_i_reconstruction.sv').read_text().replace('tb_h262_interlaced_i_reconstruction','tb_entry599_writer_pixels')
tb=tb.replace('.pipeline_block_done(recon_block_complete)','.pipeline_block_done(writer_accepted)')
# The inherited realtime bound assumes ready memory; this extra test deliberately
# stalls DDR for 60% of clocks and checks correctness, not playback throughput.
tb=tb.replace('if(!expect_progressive&&', 'if(!expect_progressive&&writer_busy_length==0&&')
tb=tb.replace('if(syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error)','if(syntax_error||probe_error||iq_error||unsupported_matrix||idct_error||recon_error||writer_error)')
tb=tb.replace('pixel_mismatches!=0||max_pixel_delta>1)','pixel_mismatches!=0||max_pixel_delta>1||written_words!=FRAME_COUNT*64800||stored_blocks!=FRAME_COUNT*8100)')
extra='''
    wire writer_accepted,writer_error,writer_we,writer_stored,capacity_blocked;
    wire [28:0] writer_addr;
    wire [63:0] writer_data;
    integer written_words=0,stored_blocks=0,writer_delta=0,writer_index=0,lane=0;
    integer writer_busy_period=997,writer_busy_length=600;
    integer blocked_clocks=0;
    wire writer_busy=(total_cycles%writer_busy_period)<writer_busy_length;
    mpeg2_h262_ddram_store writer(
        .clk(clk),.reset(reset),.frame_bank(2'd0),.pixel_value(recon_pixel_value),
        .pixel_component(recon_pixel_component),.pixel_x(recon_pixel_x),.pixel_y(recon_pixel_y),
        .pixel_valid(recon_pixel_valid),.block_start(recon_block_start),
        .block_complete(recon_block_complete),.block_accepted(writer_accepted),
        .store_error(writer_error),.capture_blocked_debug(capacity_blocked),
        .ddram_busy(writer_busy),.ddram_we(writer_we),.ddram_addr(writer_addr),
        .ddram_din(writer_data),.block_stored(writer_stored));
    always @(posedge clk) if(!reset)begin
        if(capacity_blocked)blocked_clocks=blocked_clocks+1;
        if(writer_stored)stored_blocks=stored_blocks+1;
        if(writer_we&&!writer_busy)begin
            if(writer_addr<29'h06000000||writer_addr>=29'h06000000+64800)
                $fatal(1,"invalid writer address %h",writer_addr);
            writer_index=(written_words/64800)*FRAME_BYTES+(writer_addr-29'h06000000)*8;
            for(lane=0;lane<8;lane=lane+1)begin
                writer_delta=$signed({1'b0,writer_data[lane*8 +:8]})-$signed({1'b0,pixel_oracle[writer_index+lane]});
                if(writer_delta>1||writer_delta< -1)$fatal(1,"DDR oracle mismatch word=%0d lane=%0d addr=%h delta=%0d",written_words,lane,writer_addr,writer_delta);
            end
            written_words=written_words+1;
            if(written_words==FRAME_COUNT*64800)begin
                if(!blocked_clocks)$fatal(1,"writer capacity pressure missing");
                $display("WRITER_PIXEL_PASS words=%0d lanes=%0d capacity_blocked=%0d",written_words,written_words*8,blocked_clocks);
            end
        end
    end
'''
tb=tb.replace('endmodule',extra+'\nendmodule');path=base/'tb_entry599_writer_pixels.sv';path.write_text(tb)
files=[str(root/l.split()[3]) for l in (root/'files.qip').read_text().splitlines() if len(l.split())==4 and l.split()[2]=='SYSTEMVERILOG_FILE' and l.split()[3].startswith('rtl/mpeg2_new/')]
cmd=['verilator','--binary','--timing','-j','6','-CFLAGS','-O3','-Wno-fatal','-Wno-PINMISSING','-Wno-WIDTH','-Wno-UNOPTFLAT','-Wno-BLKANDNBLK','-I'+str(root/'rtl/mpeg2_new'),'--top-module','tb_entry599_writer_pixels','--Mdir',str(base/'writer_pixels_obj'),'-o','writer_pixels',str(path)]+files
with (base/'writer_pixels_compile.log').open('w') as f:subprocess.run(cmd,cwd=root,check=True,stdout=f,stderr=subprocess.STDOUT)
results=[]
for order in ('tff','bff','progressive'):
 name='test_i_baseline' if order=='progressive' else 'test_interlaced_i_'+order
 generated=root/'simulation/interlaced_i'
 hexf=generated/(name+'.hex');pixels=generated/(name+'_pixels.hex');length=len(bytes.fromhex(hexf.read_text()))
 cmd=[str(base/'writer_pixels_obj/writer_pixels'),'+HEX='+str(hexf),'+LEN='+str(length),'+PIXELS='+str(pixels)]
 if order=='tff':cmd+=['+TFF']
 if order=='progressive':cmd+=['+PROGRESSIVE']
 start=time.monotonic();log=base/('writer_pixels_'+order+'.log')
 with log.open('w') as f:r=subprocess.run(cmd,cwd=root,stdout=f,stderr=subprocess.STDOUT)
 result={'case':order,'command':cmd,'exit_code':r.returncode,'seconds':time.monotonic()-start,'sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'pass_lines':[l for l in log.read_text().splitlines() if 'PASS' in l or 'RESULT' in l]}
 results.append(result);print(json.dumps(result),flush=True)
 assert r.returncode==0 and 'WRITER_PIXEL_PASS' in log.read_text()
(base/'writer_pixels.json').write_text(json.dumps({'source_commit':'f615ce02ba8a96ac198b26c24ff5c4b7cecfd1b4','all_passed':True,'checks':results,'scope':'12 pictures: all reconstructed samples and all accepted DDR byte lanes against FFmpeg within established +/-1 IDCT tolerance; actual candidate acknowledgement with 600/997 modeled DDR busy clocks.'},indent=2)+'\n')
