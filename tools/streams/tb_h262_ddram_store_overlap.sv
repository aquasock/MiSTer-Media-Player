// Entry 546: prove the two-bank capture queue overlaps capture with drain
// without reordering or corrupting DDR row data, and that it still refuses a
// third block while both banks are occupied.
`timescale 1ns/1ps
module tb_h262_ddram_store_overlap;

reg clk=0; always #5 clk=~clk;
reg reset=1;
reg [1:0] frame_bank=0;
reg [7:0] pixel_value=0;
reg [1:0] pixel_component=0;
reg [11:0] pixel_x=0, pixel_y=0;
reg pixel_valid=0, block_start=0, block_complete=0;
reg ddram_busy=0;

wire block_stored, block_accepted, write_seen, store_error;
wire [7:0] ddram_burstcnt; wire [28:0] ddram_addr;
wire ddram_rd; wire [63:0] ddram_din; wire [7:0] ddram_be; wire ddram_we;
wire luma_word_debug; wire [2:0] luma_region_debug;
wire luma_row_parity_debug, luma_picture_start_debug, luma_picture_complete_debug;
wire [31:0] luma_position_fingerprint_debug;

mpeg2_h262_ddram_store dut(
 .clk(clk),.reset(reset),.frame_bank(frame_bank),.pixel_value(pixel_value),
 .pixel_component(pixel_component),.pixel_x(pixel_x),.pixel_y(pixel_y),
 .pixel_valid(pixel_valid),.block_start(block_start),.block_complete(block_complete),
 .block_stored(block_stored),.block_accepted(block_accepted),
 .write_seen(write_seen),.store_error(store_error),
 .ddram_busy(ddram_busy),.ddram_burstcnt(ddram_burstcnt),.ddram_addr(ddram_addr),
 .ddram_rd(ddram_rd),.ddram_din(ddram_din),.ddram_be(ddram_be),.ddram_we(ddram_we),
 .luma_word_debug(luma_word_debug),.luma_region_debug(luma_region_debug),
 .luma_row_parity_debug(luma_row_parity_debug),
 .luma_picture_start_debug(luma_picture_start_debug),
 .luma_picture_complete_debug(luma_picture_complete_debug),
 .luma_position_fingerprint_debug(luma_position_fingerprint_debug));

// Record every accepted write so ordering and payload can be checked.
integer nwr=0;
reg [28:0] seen_addr [0:63];
reg [63:0] seen_data [0:63];
always @(posedge clk) if(!reset && ddram_we && !ddram_busy) begin
    seen_addr[nwr]=ddram_addr; seen_data[nwr]=ddram_din; nwr=nwr+1;
end

integer accepted_while_writing=0;
integer accepted_total=0;
always @(posedge clk) if(!reset && block_accepted) begin
    accepted_total=accepted_total+1;
    if(dut.writing) accepted_while_writing=accepted_while_writing+1;
end

integer bx,by;
// Feed one 8x8 block whose byte values encode the block tag and row.
task feed_block;
    input [11:0] ox; input [11:0] oy; input [7:0] tag;
begin
    @(negedge clk); pixel_x=ox; pixel_y=oy; pixel_component=0; block_start=1;
    @(negedge clk); block_start=0;
    for(by=0;by<8;by=by+1)
        for(bx=0;bx<8;bx=bx+1)begin
            pixel_x=ox+bx[11:0]; pixel_y=oy+by[11:0];
            pixel_value=tag+by[7:0]; pixel_valid=1;
            @(negedge clk);
        end
    pixel_valid=0;
    block_complete=1; @(negedge clk); block_complete=0;
    repeat(4)@(negedge clk); // let the capacity grant propagate
end
endtask

integer i,r;
integer first_block_writes;
initial begin
    repeat(4)@(negedge clk); reset=0; @(negedge clk);

    if(accepted_total!=0)
        $fatal(1,"no grant may be emitted before any block is captured");

    // Block A at row 0, block B at row 8.  Hold DDR busy so A cannot drain,
    // then confirm B is still accepted: that overlap is the whole point.
    ddram_busy=1;
    feed_block(12'd0,12'd0,8'h10);
    if(accepted_total!=1)
        $fatal(1,"exactly one grant expected after the first capture, saw %0d",
               accepted_total);
    feed_block(12'd0,12'd8,8'h20);
    if(accepted_total!=1)
        $fatal(1,"no further grant may be emitted while both banks are full");
    if(store_error) $fatal(1,"overlapped capture must not raise store_error");

    // Release DDR and let both banks drain.
    ddram_busy=0;
    r=0;
    while((nwr<16)&&(r<4000))begin @(negedge clk); r=r+1; end
    if(nwr!=16) $fatal(1,"expected 16 row writes, saw %0d",nwr);
    if(store_error) $fatal(1,"drain must not raise store_error");
    if(accepted_total<2)
        $fatal(1,"a grant must follow each freed bank, saw %0d",accepted_total);

    // Ordering: block A's eight rows must all precede block B's.
    first_block_writes=8;
    for(i=0;i<8;i=i+1)begin
        if(seen_addr[i]!==(29'h06000000+i*90))
            $fatal(1,"block A row %0d address %h",i,seen_addr[i]);
        if(seen_data[i][7:0]!==(8'h10+i[7:0]))
            $fatal(1,"block A row %0d payload %h",i,seen_data[i][7:0]);
    end
    for(i=0;i<8;i=i+1)begin
        if(seen_addr[8+i]!==(29'h06000000+(8+i)*90))
            $fatal(1,"block B row %0d address %h",i,seen_addr[8+i]);
        if(seen_data[8+i][7:0]!==(8'h20+i[7:0]))
            $fatal(1,"block B row %0d payload %h",i,seen_data[8+i][7:0]);
    end
    if(accepted_while_writing==0)
        $fatal(1,"capacity was never granted during a drain: no overlap achieved");

    $display("DDRAM_STORE_OVERLAP_PASS writes=%0d grants=%0d overlap_grants=%0d",
             nwr,accepted_total,accepted_while_writing);
    $finish;
end

initial begin #500000; $fatal(1,"timeout"); end
endmodule
