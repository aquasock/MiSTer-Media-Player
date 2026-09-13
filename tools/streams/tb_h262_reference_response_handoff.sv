`timescale 1ns/1ps
module tb_h262_reference_response_handoff;
reg clk=0;always #5 clk=~clk;
reg reset=1,valid=0,mixed_select=0,b_select=0;
reg [63:0] data=0;
wire mv=valid&&mixed_select&&!b_select;
wire bv=valid&&b_select;
wire [63:0] mixed_word,b_word;
wire mixed_ready,b_ready;
mpeg2_h262_reference_response_handoff dut(clk,reset,data,mv,bv,mixed_word,b_word,mixed_ready,b_ready);
// The accepted ebf372e/9fd1829 handoff, retained as the equivalence oracle.
reg [63:0] legacy_word;
reg legacy_mixed_ready,legacy_b_ready;
always @(posedge clk) begin
    if(reset) begin legacy_word<=0;legacy_mixed_ready<=0;legacy_b_ready<=0;end
    else begin legacy_word<=data;legacy_mixed_ready<=mv;legacy_b_ready<=bv;end
end
integer cycle=0,mixed_count=0,b_count=0,owner_changes=0;
reg last_owner=0;
reg [31:0] rng=32'h7351abc9;
always @(posedge clk) begin
    #1;
    if(mixed_ready!==legacy_mixed_ready||b_ready!==legacy_b_ready)
        $fatal(1,"response cycle or owner differs at %0d",cycle);
    if(mixed_ready) begin
        if(mixed_word!==legacy_word) $fatal(1,"mixed word mismatch");
        mixed_count=mixed_count+1;
    end
    if(b_ready) begin
        if(b_word!==legacy_word) $fatal(1,"B word mismatch");
        b_count=b_count+1;
    end
    if(reset&&(mixed_word!==0||b_word!==0)) $fatal(1,"reset data mismatch");
end
initial begin
    repeat(3) @(negedge clk);
    for(cycle=0;cycle<10000;cycle=cycle+1) begin
        rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
        reset=(cycle%127)==0;
        valid=rng[0]||rng[1];mixed_select=rng[2];b_select=rng[3];
        data={rng,rng^32'hdeadbeef};
        if(valid&&b_select!=last_owner) owner_changes=owner_changes+1;
        last_owner=b_select;
        @(negedge clk);
    end
    if(mixed_count<1000||b_count<2000||owner_changes<2000) $fatal(1,"coverage");
    $display("REFERENCE_HANDOFF_PASS cycles=%0d mixed=%0d B=%0d owner_changes=%0d reset_period=127 latency=unchanged",cycle,mixed_count,b_count,owner_changes);
    $finish;
end
endmodule
