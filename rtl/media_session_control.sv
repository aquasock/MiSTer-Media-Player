// Four-phase restart handshake. Stop DDR grants, drain accepted responses,
// then reset clients. FIFO reset precedes start; source waits for decoder reset
// acknowledgement AND host response retirement. Raster clocks never stop.
module media_session_control #(parameter ENABLE_START_READY=0)(
    input wire clk_sys,clk_mpeg2,reset,restart,
    input wire reader_idle,ddr_idle,
    output wire reader_cancel,fifo_reset,
    output reg reader_start=0,
    output wire quiesce,
    output reg decoder_reset=1,
    output reg [31:0] generation=0,
    input wire start_ready
);
localparam WAIT_RESET=0,WAIT_RELEASE=1,SETTLE=2,RUN=3;
reg [1:0] state=WAIT_RESET;
reg request=1;
reg flush=1;
reg [4:0] delay_count=0;
(* preserve, altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] req_sync=3'b111,ack_sync=3'b111;
assign reader_cancel=state!=RUN || restart || reset;
assign fifo_reset=flush || reset;
assign quiesce=req_sync[2] || decoder_reset;
always @(posedge clk_mpeg2) begin
    req_sync<={req_sync[1:0],request};
    if(reset) begin req_sync<=3'b111;decoder_reset<=1;end
    else if(!req_sync[2]) decoder_reset<=0;
    else if(ddr_idle) decoder_reset<=1;
end
always @(posedge clk_sys) begin
    ack_sync<={ack_sync[1:0],decoder_reset};
    reader_start<=0;
    if(reset || restart) begin
        request<=1;flush<=1;state<=WAIT_RESET;delay_count<=0;
        if(reset) begin generation<=0;ack_sync<=3'b111;end
        else generation<=generation+1'b1;
    end else case(state)
    WAIT_RESET: if(ack_sync[2] && reader_idle && (!ENABLE_START_READY || start_ready)) begin
        if(delay_count==15) begin request<=0;flush<=0;state<=WAIT_RELEASE;delay_count<=0;end
        else delay_count<=delay_count+1'b1;
    end else delay_count<=0;
    WAIT_RELEASE: if(!ack_sync[2]) begin state<=SETTLE;delay_count<=0;end
    SETTLE: if(delay_count==15) begin state<=RUN;reader_start<=1;end
        else delay_count<=delay_count+1'b1;
    RUN: ;
    endcase
end
endmodule
