// Entry 599: prove immediate grants preserve the two-bank writer contract,
// including delayed grants, full-word data, pressure, reset and invalid input.
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
wire capture_blocked_debug;
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
 .capture_blocked_debug(capture_blocked_debug),
 .write_seen(write_seen),.store_error(store_error),
 .ddram_busy(ddram_busy),.ddram_burstcnt(ddram_burstcnt),.ddram_addr(ddram_addr),
 .ddram_rd(ddram_rd),.ddram_din(ddram_din),.ddram_be(ddram_be),.ddram_we(ddram_we),
 .luma_word_debug(luma_word_debug),.luma_region_debug(luma_region_debug),
 .luma_row_parity_debug(luma_row_parity_debug),
 .luma_picture_start_debug(luma_picture_start_debug),
 .luma_picture_complete_debug(luma_picture_complete_debug),
 .luma_position_fingerprint_debug(luma_position_fingerprint_debug));

// Compare every accepted row, including all byte lanes, against the source
// transaction. The scoreboard does not depend on the writer's bank state.
localparam integer MAX_WORDS=4096;
reg [28:0] expected_addr [0:MAX_WORDS-1];
reg [63:0] expected_data [0:MAX_WORDS-1];
integer expected_words=0,nwr=0,captures=0,grants=0,stores=0;
integer immediate_grants=0,delayed_grants=0,blocked_cycles=0;
integer cycles=0,last_capture_cycle=0,max_grant_latency=0;
reg grant_d=0,stalled_d=0,allow_error=0;
reg [28:0] stalled_addr;
reg [63:0] stalled_data;
reg forced_busy=0,random_busy=0;
reg [31:0] pressure_lfsr=32'h599a1234;
integer pressure_cycle=0;
always @(negedge clk) begin
    pressure_cycle=pressure_cycle+1;
    pressure_lfsr={pressure_lfsr[30:0],pressure_lfsr[31]^pressure_lfsr[21]^pressure_lfsr[1]^pressure_lfsr[0]};
end
always @* ddram_busy=forced_busy ||
    (random_busy && ((pressure_cycle%997<600) || pressure_lfsr[2:0]!=0));

always @(posedge clk) begin
    if(reset) begin
        nwr=0;captures=0;grants=0;stores=0;
        immediate_grants=0;delayed_grants=0;blocked_cycles=0;
        grant_d=0;stalled_d=0;cycles=0;last_capture_cycle=0;max_grant_latency=0;
        if(block_accepted) $fatal(1,"grant during reset");
    end else begin
        cycles=cycles+1;
        if(store_error && !allow_error) $fatal(1,"unexpected writer error");
        if(stalled_d && (ddram_addr!==stalled_addr || ddram_din!==stalled_data || !ddram_we))
            $fatal(1,"writer word changed while stalled");
        stalled_d=ddram_we && ddram_busy;
        stalled_addr=ddram_addr;stalled_data=ddram_din;
        if(ddram_we && !ddram_busy) begin
            if(nwr>=expected_words || ddram_addr!==expected_addr[nwr] ||
               ddram_din!==expected_data[nwr] || ddram_be!==8'hff ||
               ddram_burstcnt!==1 || ddram_rd)
                $fatal(1,"row mismatch index=%0d addr=%h expected=%h data=%h expected=%h",
                    nwr,ddram_addr,expected_addr[nwr],ddram_din,expected_data[nwr]);
            nwr=nwr+1;
        end
        if(block_stored) stores=stores+1;
        if(block_complete && !allow_error) begin
            captures=captures+1;last_capture_cycle=cycles;
        end
        if(capture_blocked_debug) blocked_cycles=blocked_cycles+1;
        if(block_accepted) begin
            grants=grants+1;
            if(grants>captures || grant_d || capture_blocked_debug)
                $fatal(1,"premature, duplicate, or capacity-blocked grant");
            if(block_complete) immediate_grants=immediate_grants+1;
            else delayed_grants=delayed_grants+1;
            if(cycles-last_capture_cycle>max_grant_latency)
                max_grant_latency=cycles-last_capture_cycle;
        end
        grant_d=block_accepted;
    end
end

task reset_session;
begin
    @(negedge clk);reset=1;block_start=0;block_complete=0;pixel_valid=0;
    forced_busy=0;random_busy=0;allow_error=0;expected_words=0;
    repeat(4)@(negedge clk);
    reset=0;
    repeat(4)@(negedge clk);
    if(block_accepted || store_error || grants || stores || nwr)
        $fatal(1,"reset leaked a grant, error, or write");
end
endtask

// Encoding 0 is ordinary Y/Cb/Cr, 1 is the P chroma X tag, 2/3 are wide
// B scratch banks, and 4 is the legacy B scratch tag. Expected addresses
// use the decoded geometry supplied to the task, not internal DUT signals.
task feed_block;
    input [1:0] bank,component;
    input [11:0] ox,oy;
    input [7:0] tag;
    input integer encoding;
    input integer expected_immediate; // -1: latency determined by pressure
    integer row,lane,index;
    reg [28:0] plane,offset,stride;
    reg [63:0] word_value;
    reg [11:0] px,py;
begin
    plane=component==0 ? 29'h06000000 : component==1 ? 29'h0600A8C0 : 29'h0600D2F0;
    stride=component==0 ? 90 : 45;
    offset=encoding==2 || encoding==4 ? 29'h00020000 : encoding==3 ? 29'h00030000 :
        bank==1 ? 29'h00010000 : bank==2 ? 29'h00040000 : 0;
    if(expected_words+8>MAX_WORDS)$fatal(1,"scoreboard capacity");
    for(row=0;row<8;row=row+1)begin
        word_value=0;
        for(lane=0;lane<8;lane=lane+1)word_value[lane*8 +: 8]=tag+row*8+lane;
        expected_addr[expected_words]=plane+offset+(oy+row)*stride+(ox>>3);
        expected_data[expected_words]=word_value;expected_words=expected_words+1;
    end
    @(negedge clk);frame_bank=bank;pixel_component=component;pixel_x=ox;pixel_y=oy;
    if(encoding==1)begin pixel_component=0;pixel_x=ox | (component==1 ? 12'h400 : 12'h800);end
    if(encoding==2 || encoding==3)begin
        pixel_component=0;pixel_x=ox | 12'hc00;
        pixel_y=oy | (encoding==2 ? 12'h800 | (component<<9) : ((component+1)<<9));
    end
    if(encoding==4)begin pixel_component=0;pixel_x=ox | 12'hc00 | (component<<8);end
    block_start=1;
    @(negedge clk);block_start=0;
    for(row=0;row<8;row=row+1)
        for(lane=0;lane<8;lane=lane+1)begin
            px=ox+lane;py=oy+row;
            if(encoding==1)px=px | (component==1 ? 12'h400 : 12'h800);
            if(encoding==2 || encoding==3)begin
                px=px | 12'hc00;
                py=py | (encoding==2 ? 12'h800 | (component<<9) : ((component+1)<<9));
            end
            if(encoding==4)px=px | 12'hc00 | (component<<8);
            pixel_x=px;pixel_y=py;pixel_value=tag+row*8+lane;pixel_valid=1;
            @(negedge clk);
        end
    pixel_valid=0;block_complete=1;
    #1;
    if(expected_immediate>=0 && block_accepted!==expected_immediate[0])
        $fatal(1,"capture-edge grant expected=%0d actual=%0d",expected_immediate,block_accepted);
    @(negedge clk);block_complete=0;
end
endtask

task wait_grant;
    integer timeout_count;
begin
    timeout_count=0;
    while(grants<captures && timeout_count<10000)begin
        @(negedge clk);timeout_count=timeout_count+1;
    end
    if(grants!=captures)$fatal(1,"missing delayed grant");
end
endtask

task drain;
    integer timeout_count;
begin
    forced_busy=0;random_busy=0;timeout_count=0;
    while((nwr<expected_words || stores<captures || grants<captures) && timeout_count<10000)begin
        @(negedge clk);timeout_count=timeout_count+1;
    end
    repeat(8)@(negedge clk);
    if(nwr!=expected_words || stores!=captures || grants!=captures)
        $fatal(1,"drain mismatch words=%0d/%0d stores=%0d captures=%0d grants=%0d",
            nwr,expected_words,stores,captures,grants);
end
endtask

integer i,mode,c,round;
integer all_words=0,all_grants=0;
initial begin
    reset_session();
    // First capture has a free alternate bank even while DDR is blocked.
    forced_busy=1;
    feed_block(0,0,0,0,8'h10,0,1);
    if(grants!=1 || captures!=1 || nwr!=0 || capture_blocked_debug)
        $fatal(1,"first capture did not receive exactly one immediate grant");
    // The second fills both banks. No grant until actual capacity returns.
    feed_block(0,0,0,8,8'h20,0,0);
    repeat(40)@(negedge clk);
    if(grants!=1 || !capture_blocked_debug || nwr!=0)
        $fatal(1,"full queue granted capacity");
    drain();
    if(immediate_grants!=1 || delayed_grants!=1 || max_grant_latency<40)
        $fatal(1,"immediate/delayed grant coverage missing");
    all_words=all_words+nwr;all_grants=all_grants+grants;

    // Deterministic bursts plus pseudorandom wait states, all planes/banks
    // and supported writer coordinate encodings. Every byte is scored.
    for(round=0;round<3;round=round+1)begin
        reset_session();random_busy=1;pressure_lfsr=32'h599a1234+round;
        for(i=0;i<80;i=i+1)begin
            mode=i%5;c=(i/5)%3;
            if(mode==1 && c==0)c=1;
            feed_block(i%3,c,((i*7)%30)*8,((i*3)%20)*8,i+round*71,mode,-1);
            wait_grant();
        end
        drain();
        if(!immediate_grants || !delayed_grants || !blocked_cycles)
            $fatal(1,"random pressure did not exercise both grant paths");
        all_words=all_words+nwr;all_grants=all_grants+grants;
    end

    // Last valid ordinary row/word in every component and frame bank.
    reset_session();
    for(i=0;i<3;i=i+1)begin
        feed_block(i,0,712,472,8'h90+i,0,1);wait_grant();
        feed_block(i,1,352,232,8'hb0+i,0,1);wait_grant();
        feed_block(i,2,352,232,8'hd0+i,0,1);wait_grant();
    end
    drain();all_words=all_words+nwr;all_grants=all_grants+grants;

    // Reset discards a retained request and both queued stores. No stale
    // acknowledgement may leak into the next playback/session.
    reset_session();forced_busy=1;
    feed_block(0,0,0,0,1,0,1);
    feed_block(0,0,0,8,2,0,0);
    if(!capture_blocked_debug || grants!=1)$fatal(1,"reset case not pending");
    reset_session();
    feed_block(2,2,16,16,8'h55,0,1);wait_grant();drain();
    all_words=all_words+nwr;all_grants=all_grants+grants;

    // Preserve malformed completion and third-capture error detection.
    reset_session();allow_error=1;
    @(negedge clk);block_complete=1;
    #1;if(block_accepted)$fatal(1,"uncaptured block acknowledged");
    @(negedge clk);block_complete=0;
    if(!store_error)$fatal(1,"uncaptured completion was not rejected");
    reset_session();forced_busy=1;
    feed_block(0,0,0,0,1,0,1);
    feed_block(0,0,0,8,2,0,0);
    allow_error=1;
    @(negedge clk);block_start=1;
    @(negedge clk);block_start=0;
    if(!store_error || grants!=1)$fatal(1,"third capture was not rejected");
    reset_session();
    $display("DDRAM_STORE_OVERLAP_PASS words=%0d grants=%0d immediate_delayed_random_tags_reset_errors=PASS",all_words,all_grants);
    $finish;
end

initial begin #100000000; $fatal(1,"timeout"); end
endmodule
