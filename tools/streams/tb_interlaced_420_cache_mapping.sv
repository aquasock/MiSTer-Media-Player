`timescale 1ns/1ps

module altsyncram #(
    parameter operation_mode="",width_a=1,widthad_a=1,numwords_a=1,
    width_b=1,widthad_b=1,numwords_b=1,outdata_reg_b="",address_reg_b="",
    read_during_write_mode_mixed_ports="",ram_block_type="",
    intended_device_family=""
)(input clock0,input clock1,input [widthad_a-1:0] address_a,
  input [width_a-1:0] data_a,input wren_a,
  input [widthad_b-1:0] address_b,output [width_b-1:0] q_b,
  input aclr0,input aclr1,input addressstall_a,input addressstall_b,
  input byteena_a,input byteena_b,input [width_b-1:0] data_b,input wren_b,
  output [width_a-1:0] q_a);
assign q_b={width_b{1'b0}};
assign q_a={width_a{1'b0}};
endmodule

module tb_interlaced_420_cache_mapping;
reg clk=0;
reg [11:0] h_pos=0,v_pos=0;
wire [7:0] burst;wire [28:0] addr;wire rd;
wire ready,seen,error;wire [7:0] r,g,b;wire de,hs,vs;
integer i;
integer lane;
reg [31:0] raw_fingerprint;
reg [31:0] display_fingerprint;
reg [31:0] corrupt_fingerprint;
reg [63:0] fingerprint_word_0;
reg [63:0] fingerprint_word_1;

always #5 clk=~clk;

mpeg2_luma_framebuffer dut(
        .progressive_chroma(1'b0),
 .reset(1'b1),.mem_clk(clk),.picture_complete(1'b0),
 .horizontal_size(14'd720),.vertical_size(14'd480),
 .native_interlaced(1'b1),.top_field_first(1'b1),
 .framebuffer_generation(8'd0),
 .write_read_expected_region(3'd0),.write_read_expected_valid(1'b0),
 .write_read_expected_even_fingerprint(32'd0),
 .write_read_expected_odd_fingerprint(32'd0),
 .ddram_busy(1'b0),.ddram_dout(64'd0),.ddram_dout_ready(1'b0),
 .ddram_burstcnt(burst),.ddram_addr(addr),.ddram_rd(rd),
 .cache_ready(ready),.read_seen(seen),.cache_error(error),
 .rd_clk(clk),.h_pos(h_pos),.v_pos(v_pos),.pixel_ce(1'b1),
 .pixel_en(1'b0),.h_sync(1'b1),.v_sync(1'b1),
 .video_r(r),.video_g(g),.video_b(b),.video_de(de),.video_hs(hs),.video_vs(vs));

task check_luma(input first_field,input integer seq,input integer expected);
begin
 if(dut.interlaced_luma_row(seq[8:0],first_field)!==expected[10:0])
   $fatal(1,"luma first=%0d seq=%0d got=%0d expected=%0d",first_field,seq,
          dut.interlaced_luma_row(seq[8:0],first_field),expected);
end endtask

task check_chroma(input first_field,input integer pair,input integer expected);
begin
 if(dut.interlaced_chroma_row(pair[7:0],first_field)!==expected[10:0])
   $fatal(1,"chroma first=%0d pair=%0d got=%0d expected=%0d",first_field,pair,
          dut.interlaced_chroma_row(pair[7:0],first_field),expected);
end endtask

task check_fingerprint(input first_field);
begin
 fingerprint_word_0=first_field?64'h8877665544332211:
                                64'h1122334455667788;
 fingerprint_word_1=first_field?64'h1020304050607080:
                                64'h8070605040302010;
 raw_fingerprint=0;
 raw_fingerprint=dut.luma_fingerprint_word(raw_fingerprint,
                                            fingerprint_word_0);
 raw_fingerprint=dut.luma_fingerprint_word(raw_fingerprint,
                                            fingerprint_word_1);
 display_fingerprint=0;
 for(lane=0;lane<8;lane=lane+1)
   display_fingerprint=dut.luma_fingerprint_byte(
       display_fingerprint,fingerprint_word_0[lane*8+:8]);
 for(lane=0;lane<8;lane=lane+1)
   display_fingerprint=dut.luma_fingerprint_byte(
       display_fingerprint,fingerprint_word_1[lane*8+:8]);
 if(raw_fingerprint!==display_fingerprint)
   $fatal(1,"fingerprint match failed first_field=%0d raw=%h display=%h",
          first_field,raw_fingerprint,display_fingerprint);

 corrupt_fingerprint=0;
 for(lane=0;lane<8;lane=lane+1)
   corrupt_fingerprint=dut.luma_fingerprint_byte(
       corrupt_fingerprint,
       fingerprint_word_0[lane*8+:8]^(lane==3?8'h01:8'h00));
 for(lane=0;lane<8;lane=lane+1)
   corrupt_fingerprint=dut.luma_fingerprint_byte(
       corrupt_fingerprint,fingerprint_word_1[lane*8+:8]);
 if(raw_fingerprint===corrupt_fingerprint)
   $fatal(1,"corrupted cache byte did not change fingerprint first_field=%0d",
          first_field);
end endtask

initial begin
 for(i=0;i<240;i=i+1)begin
   check_luma(0,i,2*i);
   check_luma(0,i+240,2*i+1);
   check_luma(1,i,2*i+1);
   check_luma(1,i+240,2*i);
 end
 for(i=0;i<120;i=i+1)begin
   check_chroma(0,i,2*i);
   check_chroma(0,i+120,2*i+1);
   check_chroma(1,i,2*i+1);
   check_chroma(1,i+120,2*i);
 end

 force dut.native_interlaced_mem=1'b1;
 force dut.progressive_chroma_mem=1'b0;
 force dut.first_field_mem=1'b0;
 force dut.refill_event_line=11'd0;#1;
 if(dut.y_refill_line!==11'd4||dut.y_refill_bank!==1'b0)
   $fatal(1,"TFF Y refill after seq0 wrong");
 force dut.refill_event_line=11'd1;#1;
 if(dut.y_refill_line!==11'd6||dut.y_refill_bank!==1'b1||
    dut.c_refill_line!==11'd4||dut.c_refill_bank!==1'b0)
   $fatal(1,"TFF refill after seq1 wrong");
 force dut.refill_event_line=11'd479;#1;
 if(dut.y_refill_line!==11'd2||dut.y_refill_bank!==1'b1||
    dut.c_refill_line!==11'd2||dut.c_refill_bank!==1'b1)
   $fatal(1,"TFF frame-wrap refill wrong");

 force dut.first_field_mem=1'b1;
 force dut.refill_event_line=11'd479;#1;
 if(dut.y_refill_line!==11'd3||dut.c_refill_line!==11'd3)
   $fatal(1,"BFF frame-wrap refill wrong");

 // Film chroma walks all 240 rows once per field, regardless of parity.
 force dut.progressive_chroma_mem=1'b1;
 for(i=0;i<480;i=i+1)begin
   force dut.refill_event_line=i;#1;
   if(dut.c_refill_line!==((i+2)%240)||dut.c_refill_bank!==((i+2)%2))
     $fatal(1,"film chroma row/bank at sequence %0d",i);
 end
 if(dut.prefill_c0!==0||dut.prefill_c1!==1)$fatal(1,"film chroma prefill");

 check_fingerprint(1'b0);
 check_fingerprint(1'b1);

 $display({"RESULT luma_sequences=960 chroma_sequences=480 ",
           "tff_refill=PASS bff_refill=PASS fingerprints=PASS PASS"});
 $finish;
end
endmodule
