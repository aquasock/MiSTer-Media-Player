// Three independent, one-outstanding-block clients share unchanged IDCT math.
// Request: {start, valid, index[5:0], signed coefficient[11:0], end}.
// Response: {complete, error, valid, index[5:0], signed sample[15:0]}.
// Each producer must wait for its own completion before starting another block.
// One M10K staging bank per client absorbs concurrent coefficient strobes;
// round-robin service cannot drop or interleave a block. Reset cancels all work.
module mpeg2_h262_shared_idct(
 input wire clk,reset,
 input wire [62:0] requests,
 output wire [74:0] responses
);
wire [2:0] starts,valids,ends;
wire [5:0] indices[0:2];
wire [11:0] values[0:2];
reg [2:0] occupied=0,capturing=0,ready=0,complete=0,errors=0;
reg [63:0] written[0:2];
wire [11:0] read_value[0:2];
reg [2:0] state=5;
reg [1:0] owner=0,next_owner=0;
reg [5:0] replay_index=0;
localparam IDLE=0,PRIME=1,STREAM=2,WAIT=3,LIVE=4,CLEAR=5;
wire [5:0] read_address=state==STREAM?replay_index+6'd1:6'd0;
wire engine_complete,engine_error,engine_valid;
wire [5:0] engine_index;
wire signed [15:0] engine_value;
wire finishing=state==WAIT && engine_valid && engine_index==63;
reg selected_valid;
reg [1:0] selected;
integer offset,candidate;
always @* begin
 selected_valid=0;selected=0;
 for(offset=0;offset<3;offset=offset+1) begin
  candidate=next_owner+offset;
  if(candidate>=3)candidate=candidate-3;
  if(!selected_valid && ready[candidate])begin selected_valid=1;selected=candidate[1:0];end
 end
end
reg direct_valid;
reg [1:0] direct_owner;
integer direct_offset,direct_candidate;
always @* begin
 direct_valid=0;direct_owner=0;
 for(direct_offset=0;direct_offset<3;direct_offset=direct_offset+1)begin
  direct_candidate=next_owner+direct_offset;
  if(direct_candidate>=3)direct_candidate=direct_candidate-3;
  if(!direct_valid && starts[direct_candidate] && !occupied[direct_candidate])begin
   direct_valid=1;direct_owner=direct_candidate[1:0];
  end
 end
end
wire direct_grant=state==IDLE && !selected_valid && direct_valid;
wire [1:0] live_owner=direct_grant?direct_owner:owner;
wire live=direct_grant || state==LIVE;
// An idle engine accepts a producer's strobes immediately, preserving normal
// single-client latency. Staging/replay is used only if another client owns it.
for(genvar g=0;g<3;g=g+1) begin: client
 assign {starts[g],valids[g],indices[g],values[g],ends[g]}=requests[g*21+:21];
 (* ramstyle="M10K" *) reg [11:0] coefficients[0:63];
 reg [11:0] read_data;
 always @(posedge clk) begin
  if(!reset && valids[g] && (capturing[g] || (starts[g] && !occupied[g])))
   coefficients[indices[g]]<=values[g];
  read_data<=coefficients[read_address];
 end
 assign read_value[g]=read_data;
 wire routed=state==WAIT && owner==g && !reset;
 assign responses[g*25+:25]={complete[g]||(routed&&finishing),
  errors[g]||(routed&&engine_error),routed&&engine_valid,engine_index,engine_value};
end
mpeg2_h262_idct engine(
 .clk(clk),.reset(reset || state==CLEAR || (state==IDLE && !direct_grant) || state==PRIME),
 .coeff_block_start(direct_grant || (state==STREAM && replay_index==0)),
 .coeff_valid(live?valids[live_owner]:state==STREAM),.coeff_index(live?indices[live_owner]:replay_index),
 .coeff_value(live?values[live_owner]:(written[owner][replay_index]?read_value[owner]:12'd0)),
 .coeff_block_end(live?ends[live_owner]:(state==STREAM && replay_index==63)),
 .block_complete(engine_complete),.idct_error(engine_error),
 .sample_valid(engine_valid),.sample_index(engine_index),.sample_value(engine_value),
 .first_luma_sample00(),.first_luma_sample77()
);
integer n;
always @(posedge clk) begin
 if(reset) begin
  occupied<=0;capturing<=0;ready<=0;complete<=0;errors<=0;
  state<=CLEAR;owner<=0;next_owner<=0;replay_index<=0;
  for(n=0;n<3;n=n+1)written[n]<=0;
 end else begin
  for(n=0;n<3;n=n+1) begin
   if(starts[n])begin
    if(occupied[n])errors[n]<=1;
    else begin occupied[n]<=1;capturing[n]<=1;complete[n]<=0;written[n]<=0;end
   end
   if(valids[n])begin
    if(capturing[n] || (starts[n]&&!occupied[n]))written[n][indices[n]]<=1;
    else errors[n]<=1;
   end
   if(ends[n])begin
    if(capturing[n] || (starts[n]&&!occupied[n]))begin capturing[n]<=0;ready[n]<=1;end
    else errors[n]<=1;
   end
  end
  case(state)
   CLEAR:state<=IDLE;
   IDLE:if(selected_valid)begin owner<=selected;ready[selected]<=0;state<=PRIME;end
    else if(direct_grant)begin
     owner<=direct_owner;ready[direct_owner]<=0;state<=ends[direct_owner]?WAIT:LIVE;
    end
   LIVE:if(ends[owner])begin ready[owner]<=0;state<=WAIT;end
   PRIME:begin replay_index<=0;state<=STREAM;end
   STREAM:if(replay_index==63)state<=WAIT;else replay_index<=replay_index+1'b1;
   WAIT:begin
    if(engine_error)errors[owner]<=1;
    if(finishing)begin
     if(!engine_complete)errors[owner]<=1;
     complete[owner]<=1;occupied[owner]<=0;
     next_owner<=owner==2?0:owner+1'b1;state<=CLEAR;
    end
   end
  endcase
 end
end
`ifdef H262_IDCT_TRACE
integer trace_cycle=0;
always @(posedge clk)begin
 trace_cycle<=trace_cycle+1;
 if(!reset)for(integer t=0;t<3;t=t+1)begin
  if(starts[t])$display("IDCT_CLIENT_REQUEST client=%0d cycle=%0d queued=%0d",t,trace_cycle,!(direct_grant && direct_owner==t));
  if(responses[t*25+22] && responses[t*25+16+:6]==63)
   $display("IDCT_CLIENT_FINISH client=%0d cycle=%0d",t,trace_cycle);
 end
end
`endif
endmodule
