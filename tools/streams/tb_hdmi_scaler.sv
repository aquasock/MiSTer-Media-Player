`timescale 1ps/1ps
// The ascal module is synthesized DIRECTLY from sys/ascal.vhd by GHDL.
// This gives the finite-width arithmetic used in hardware (the behavioral
// VHDL contains natural-range underflows in otherwise unused pipeline values).
// No scaler equation, reset, buffer transition or field decision is rewritten.
module tb_hdmi_scaler;
    tb_hdmi_scaler_stimulus #(.TRACE_ONLY(0)) source();
    reg oclk = 0, aclk = 0, reset_n = 0;
    integer half_period = 18500;
    integer width = 720, height = 480, ht = 858, vt = 525;
    integer hsstart = 739, hsend = 801, vsstart = 489, vsend = 495;
    reg bob = 0;
    reg backpressure = 0;
    always #(half_period) oclk = ~oclk;
    always #5000 aclk = ~aclk;
    initial begin
        bob = $test$plusargs("BOB");
        backpressure = $test$plusargs("BACKPRESSURE");
        if ($test$plusargs("720P")) begin
            width=1280; height=720; ht=1650; vt=750;
            hsstart=1390; hsend=1430; vsstart=725; vsend=730;
            half_period=6734;
        end
        if ($test$plusargs("1080P")) begin
            width=1920; height=1080; ht=2200; vt=1125;
            hsstart=2008; hsend=2052; vsstart=1084; vsend=1089;
            half_period=3367;
        end
        #200000 reset_n=1;
    end
    wire [7:0] r,g,b;
    wire hs,vs,de,vbl,brd;
    wire [15:0] ll;
    wire [11:0] hdmax, vdmax;
    reg waitreq = 0, rdvalid = 0;
    reg [127:0] rdata = 0;
    wire [127:0] wdata;
    wire [27:0] address;
    wire [7:0] burst;
    wire [15:0] be;
    wire rd,wr;
    ascal dut (
        .i_r(source.out_rgb[23:16]), .i_g(source.out_rgb[15:8]), .i_b(source.out_rgb[7:0]),
        .i_hs(source.out_hs), .i_vs(source.out_vs), .i_fl(source.field),
        .i_de(source.out_de), .i_ce(source.out_ce), .i_clk(source.clk),
        .o_r(r), .o_g(g), .o_b(b), .o_hs(hs), .o_vs(vs), .o_de(de),
        .o_vbl(vbl), .o_brd(brd), .o_ce(1'b1), .o_clk(oclk),
        .o_border(24'd0), .o_fb_ena(1'b0), .o_fb_hsize(12'd0), .o_fb_vsize(12'd0),
        .o_fb_format(6'b000100), .o_fb_base(32'd0), .o_fb_stride(14'd0),
        .pal1_clk(1'b0), .pal1_dw(48'd0), .pal1_a(7'd0), .pal1_wr(1'b0),
        .pal_n(1'b0), .pal2_clk(1'b0), .pal2_dw(24'd0), .pal2_a(8'd0), .pal2_wr(1'b0),
        .iauto(1'b1), .himin(12'd0), .himax(12'd0), .vimin(12'd0), .vimax(12'd0),
        .run(1'b1), .freeze(1'b0), .mode(5'b01000), .bob_deint(bob),
        .htotal(12'(ht)), .hsstart(12'(hsstart)), .hsend(12'(hsend)),
        .hdisp(12'(width)), .hmin(12'd0), .hmax(12'(width)),
        .vtotal(12'(vt)), .vsstart(12'(vsstart)), .vsend(12'(vsend)),
        .vdisp(12'(height)), .vmin(12'd0), .vmax(12'(height)),
        .vrr(1'b0), .vrrmax(12'd0), .swblack(1'b0), .format(2'b01),
        .poly_clk(aclk), .poly_dw(10'd0), .poly_a(12'd0), .poly_wr(1'b0),
        .o_lltune(ll), .i_hdmax(hdmax), .i_vdmax(vdmax),
        .avl_clk(aclk), .avl_waitrequest(waitreq), .avl_readdata(rdata),
        .avl_readdatavalid(rdvalid), .avl_burstcount(burst),
        .avl_writedata(wdata), .avl_address(address), .avl_write(wr),
        .avl_read(rd), .avl_byteenable(be), .reset_na(reset_n)
    );

    // Model the complete production allocation. During mode detection, BFF
    // can transiently report twice the eventual height; a 2 MiB per-bank
    // shortcut would reject legal accesses within the real 8 MiB bank.
    localparam BANK_WORDS=524288, USED_WORDS=BANK_WORDS;
    reg [127:0] memory [0:3*USED_WORDS-1];
    function automatic integer mem_index(input integer a);
        integer offset, bank, word_offset;
        begin
            if (a < 'h2000000) $fatal(1,"Avalon address below scaler allocation: %h",a);
            offset=a-'h2000000; bank=offset/BANK_WORDS; word_offset=offset%BANK_WORDS;
            if (bank>=3 || word_offset>=USED_WORDS)
                $fatal(1,"Avalon address outside modeled allocation: %h",a);
            mem_index=bank*USED_WORDS+word_offset;
        end
    endfunction
    integer qa[0:15], qn[0:15];
    integer head=0, tail=0, count=0, delay_count=0;
    integer write_base=0, write_left=0, write_beat=0, write_length=0;
    integer writes=0, reads=0, beats=0;
    integer memory_cycles=0;
    integer writes_by_bank[0:2];
    integer a,idx,lane;
    always @(posedge aclk) begin
        rdvalid<=0;
        memory_cycles++;
        waitreq<=backpressure && ((memory_cycles%53)<7);
        if (reset_n) begin
            if (rd && wr) $fatal(1,"Simultaneous read/write command");
            if (wr && !waitreq) begin
                a=int'(address);
                if (write_left==0) begin
                    write_length=int'(burst);
                    if (write_length==0) $fatal(1,"Empty write burst");
                    write_base=a; write_left=write_length; write_beat=0;
                    writes=writes+1;
                    writes_by_bank[(a-'h2000000)/BANK_WORDS]++;
                end
                if (a!=write_base || int'(burst)!=write_length)
                    $fatal(1,"Write burst address/count changed");
                idx=mem_index(write_base+write_beat);
                for (lane=0;lane<16;lane++)
                    if (be[lane]) memory[idx][lane*8 +: 8]=wdata[lane*8 +: 8];
                write_left--; write_beat++;
            end
            if (rd && !waitreq) begin
                if (count==16) $fatal(1,"Read queue overflow");
                qa[tail]=int'(address); qn[tail]=int'(burst);
                if (qn[tail]==0) $fatal(1,"Empty read burst");
                tail=(tail+1)%16; count++; reads++;
                if (count==1) delay_count=7;
            end
            if (count>0) begin
                if (delay_count>0) delay_count--;
                else begin
                    rdata<=memory[mem_index(qa[head])]; rdvalid<=1; beats++;
                    qa[head]++; qn[head]--;
                    if (qn[head]==0) begin head=(head+1)%16; count--; delay_count=7; end
                end
            end
        end
    end

    integer fd, frames=0, pixels=0, bad=0, green0=0, green1=0;
    integer red0[0:255],red1[0:255];
    integer peak0,peak1,k,min0,max0,min1,max1;
    reg [63:0] frame_hash=64'hcbf29ce484222325;
    integer bad_blue=0;
    integer dump_fd=0, dump_start=20, dump_count=0;
    string dump_prefix;
    reg prev_vs=0;
    reg prev_input_vs=0;
    integer input_syncs=0;
    always @(posedge source.clk) begin
        if (source.out_ce) begin
            if (source.out_vs && !prev_input_vs) input_syncs++;
            prev_input_vs<=source.out_vs;
        end
    end
    string report_path;
    initial begin
        if (!$value$plusargs("REPORT=%s",report_path)) $fatal(1,"REPORT required");
        if ($value$plusargs("DUMP=%s",dump_prefix)) dump_count=8;
        if ($value$plusargs("DUMP_START=%d",dump_start)) begin end
        if ($value$plusargs("DUMP_COUNT=%d",dump_count)) begin end
        fd=$fopen(report_path,"w");
        if (!fd) $fatal(1,"Cannot open report");
        wait(source.done);
        #35000000000;
        $display("MEMORY writes=%0d reads=%0d returned=%0d bank_writes=%0d,%0d,%0d input_syncs=%0d source_fields=%0d generation_resets=%0d", writes,reads,beats,writes_by_bank[0],writes_by_bank[1],writes_by_bank[2],input_syncs,source.fields,source.reset_events);
        $fclose(fd);
        $finish;
    end
    always @(posedge oclk) begin
        if (de) begin
            pixels++;
            frame_hash=(frame_hash ^ {40'd0,r,g,b}) * 64'h100000001b3;
            if (b!=96 && b!=224) bad_blue++;
            if (dump_fd!=0) $fwrite(dump_fd,"%c%c%c",r,g,b);
            if (g==64) begin red0[r]++; green0++; end
            else if (g==192) begin red1[r]++; green1++; end
            else if ({r,g,b}!=0) bad++;
        end
        if (vs && !prev_vs) begin
            peak0=0;peak1=0;
            min0=256;min1=256;max0=0;max1=0;
            for (k=0;k<256;k++) begin
                if (red0[k]>red0[peak0]) peak0=k;
                if (red1[k]>red1[peak1]) peak1=k;
                if (red0[k]>0) begin
                    if (k<min0) min0=k;
                    if (k>max0) max0=k;
                end
                if (red1[k]>0) begin
                    if (k<min1) min1=k;
                    if (k>max1) max1=k;
                end
            end
            $fdisplay(fd,"frame=%0d time_ns=%0d source_r=%0d pictures=%0d pixels=%0d field0_r=%0d field0_pixels=%0d field0_peak=%0d field0_min=%0d field0_max=%0d field1_r=%0d field1_pixels=%0d field1_peak=%0d field1_min=%0d field1_max=%0d bad=%0d bad_blue=%0d hash=%016h input_width=%0d input_lines=%0d inter=%0d finished=%0d",frames,$time/1000,32+source.logical_generation*2,source.pictures,pixels,peak0,green0,red0[peak0],min0,max0,peak1,green1,red1[peak1],min1,max1,bad,bad_blue,frame_hash,hdmax+1,vdmax+1,ll[2],source.done);
            $fflush(fd);
            if (dump_fd!=0) begin $fclose(dump_fd);dump_fd=0;end
            frames++;pixels=0;bad=0;bad_blue=0;green0=0;green1=0;
            frame_hash=64'hcbf29ce484222325;
            if (frames>=dump_start && frames<dump_start+dump_count) begin
                dump_fd=$fopen($sformatf("%s%04d.ppm",dump_prefix,frames),"wb");
                if (!dump_fd) $fatal(1,"Cannot open frame dump");
                $fwrite(dump_fd,"P6\n%0d %0d\n255\n",width,height);
            end
            for (k=0;k<256;k++) begin red0[k]=0;red1[k]=0;end
        end
        prev_vs<=vs;
    end
endmodule
