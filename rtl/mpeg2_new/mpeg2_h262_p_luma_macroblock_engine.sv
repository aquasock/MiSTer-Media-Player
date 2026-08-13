//============================================================================
// MiSTer Media Player - controlled implicit-zero P luma macroblock engine
// H.262 7.6.8: decoded pel = clip(prediction + spatial residual, 0..255).
// kate - Phase 1T-p reconstructs Y0..Y3 serially and verifies all 32 DDR words.
//============================================================================
module mpeg2_h262_p_luma_macroblock_engine
(
    input  wire        clk,
    input  wire        reset,
    input  wire        request,
    input  wire        residual_valid,
    input  wire [5:0]  residual_index,
    input  wire signed [15:0] residual_value,
    input  wire        reference_valid,
    input  wire        reference_bank,
    input  wire        destination_bank,
    input  wire        store_block_stored,
    input  wire        ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire        ddram_dout_ready,
    output wire [7:0]  ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire        ddram_rd,
    output wire        store_select,
    output wire [7:0]  store_pixel_value,
    output wire [11:0] store_pixel_x,
    output wire [11:0] store_pixel_y,
    output wire        store_pixel_valid,
    output wire        store_block_start,
    output wire        store_block_complete,
    output reg         read_seen,
    output reg  [7:0]  sample_value,
    output reg         sample_nonzero,
    output reg         reconstructed_seen,
    output reg  [7:0]  reconstructed_value,
    output reg         persisted_seen,
    output reg  [7:0]  persisted_value,
    output reg         error
);

localparam [28:0] DDR_Y_BASE=29'h06000000, DDR_BANK_WORDS=29'h00010000;
localparam [1:0] READ_REFERENCE=2'd0, READ_VERIFY=2'd1;

function automatic [28:0] row90;
    input [3:0] r;
    reg [28:0] x;
    begin x={25'd0,r}; row90=(x<<6)+(x<<4)+(x<<3)+(x<<1); end
endfunction
function automatic [28:0] word_addr;
    input [28:0] bankoff; input [4:0] n;
    begin word_addr=DDR_Y_BASE+bankoff+row90(n[4:1])+{28'd0,n[0]}; end
endfunction
function automatic [7:0] byte_at;
    input [63:0] w; input [2:0] lane;
    begin case(lane)
      0:byte_at=w[7:0];1:byte_at=w[15:8];2:byte_at=w[23:16];3:byte_at=w[31:24];
      4:byte_at=w[39:32];5:byte_at=w[47:40];6:byte_at=w[55:48];default:byte_at=w[63:56];
    endcase end
endfunction
function automatic [7:0] addclip;
    input [7:0] p; input signed [15:0] f; reg signed [16:0] s;
    begin s=$signed({9'd0,p})+{f[15],f};
      if(s<0) addclip=0; else if(s>255) addclip=255; else addclip=s[7:0]; end
endfunction

reg signed [15:0] residual_mem[0:255];
reg [8:0] residual_count;
reg [63:0] ref_words[0:31];
reg [63:0] recon_words[0:31];
integer i;

reg started;
reg req_active, response_waiting;
reg [1:0] read_kind;
reg [4:0] word_index;
reg [19:0] timeout;
reg latched_destination_bank;
wire [28:0] ref_off=reference_bank?DDR_BANK_WORDS:29'd0;
wire [28:0] dst_off=latched_destination_bank?DDR_BANK_WORDS:29'd0;

reg reconstruct_active;
reg [7:0] recon_index;
wire [1:0] rb=recon_index[7:6];
wire [5:0] rl=recon_index[5:0];
wire [4:0] rslot={rb[1],rl[5:3],rb[0]};
wire [5:0] rbit={rl[2:0],3'b000};
wire [7:0] rpred=byte_at(ref_words[rslot],rl[2:0]);
wire [7:0] rpel=addclip(rpred,residual_mem[recon_index]);

reg [1:0] emit_block;
reg [5:0] emit_index;
reg emit_active, waiting_store;
wire [4:0] eslot={emit_block[1],emit_index[5:3],emit_block[0]};
wire [63:0] eword=recon_words[eslot];
assign store_select=emit_active;
assign store_pixel_value=byte_at(eword,emit_index[2:0]);
assign store_pixel_x={8'd0,emit_block[0],emit_index[2:0]};
assign store_pixel_y={8'd0,emit_block[1],emit_index[5:3]};
assign store_pixel_valid=emit_active;
assign store_block_start=emit_active&&(emit_index==0);
assign store_block_complete=emit_active&&(emit_index==63);

assign ddram_burstcnt=req_active?8'd1:8'd0;
assign ddram_addr=req_active?word_addr((read_kind==READ_REFERENCE)?ref_off:dst_off,word_index):29'd0;
assign ddram_rd=req_active;

always @(posedge clk) begin
 if(reset) begin
  residual_count<=0; started<=0; req_active<=0; response_waiting<=0; read_kind<=READ_REFERENCE;
  word_index<=0; timeout<=0; latched_destination_bank<=0; reconstruct_active<=0; recon_index<=0;
  emit_block<=0; emit_index<=0; emit_active<=0; waiting_store<=0;
  read_seen<=0; sample_value<=0; sample_nonzero<=0; reconstructed_seen<=0; reconstructed_value<=0;
  persisted_seen<=0; persisted_value<=0; error<=0;
  for(i=0;i<256;i=i+1) residual_mem[i]<=0;
  for(i=0;i<32;i=i+1) begin ref_words[i]<=0; recon_words[i]<=0; end
 end else begin
  if(residual_valid) begin
   if((residual_count>=256)||(residual_index!=residual_count[5:0])) error<=1;
   else begin residual_mem[residual_count[7:0]]<=residual_value; residual_count<=residual_count+1'b1; end
  end

  if(request&&!started) begin
   started<=1; timeout<=20'hfffff; latched_destination_bank<=destination_bank;
   if(!reference_valid||(destination_bank==reference_bank)||(residual_count!=256)) error<=1;
   else begin read_kind<=READ_REFERENCE; word_index<=0; req_active<=1; end
  end
  if(started&&!persisted_seen&&timeout!=0) begin timeout<=timeout-1'b1; if(timeout==1) error<=1; end
  if(req_active&&!ddram_busy) begin req_active<=0; response_waiting<=1; end

  if(ddram_dout_ready) begin
   if(!response_waiting) error<=1;
   else begin
    response_waiting<=0;
    if(read_kind==READ_REFERENCE) begin
     ref_words[word_index]<=ddram_dout;
     if(word_index==0) begin read_seen<=1; sample_value<=ddram_dout[7:0]; sample_nonzero<=|ddram_dout[7:0]; end
     if(word_index==31) begin reconstruct_active<=1; recon_index<=0; end
     else begin word_index<=word_index+1'b1; req_active<=1; end
    end else begin
     if(ddram_dout!=recon_words[word_index]) error<=1;
     if(word_index==0&&ddram_dout==recon_words[0]) persisted_value<=ddram_dout[7:0];
     if(word_index==31) begin
      if(ddram_dout==recon_words[31]) begin persisted_seen<=1; reconstructed_seen<=1; timeout<=0; end
     end else begin word_index<=word_index+1'b1; req_active<=1; end
    end
   end
  end

  if(reconstruct_active) begin
   recon_words[rslot][rbit +: 8]<=rpel;
   if(recon_index==0) reconstructed_value<=rpel;
   if(recon_index==255) begin reconstruct_active<=0; emit_block<=0; emit_index<=0; emit_active<=1; end
   else recon_index<=recon_index+1'b1;
  end

  if(emit_active) begin
   if(emit_index==63) begin emit_active<=0; waiting_store<=1; end
   else emit_index<=emit_index+1'b1;
  end
  if(waiting_store&&store_block_stored) begin
   waiting_store<=0;
   if(emit_block==3) begin read_kind<=READ_VERIFY; word_index<=0; req_active<=1; end
   else begin emit_block<=emit_block+1'b1; emit_index<=0; emit_active<=1; end
  end
 end
end
endmodule
