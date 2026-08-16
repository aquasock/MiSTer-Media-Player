//============================================================================
// MiSTer Media Player - generalized 8x6 P prediction+residual raster engine
//
// Sideband protocol in generalized mode:
//   * 48 ordered motion words at residual_index 0x3e: {mvx[7:0],mvy[7:0]}
//   * optional Bxxx residual block descriptor + 64 signed spatial samples
//   * A2FF terminator
// Motion components are reconstructed luminance half-sample vectors.  4:2:0
// chroma components use truncation-toward-zero /2 before half-sample prediction.
//============================================================================
module mpeg2_h262_p_motion_residual_raster_engine
(
    input wire clk,
    input wire reset,
    input wire capture_enable,
    input wire request,
    input wire [47:0] shift_right_map, // historical compatibility, unused
    input wire residual_valid,
    input wire [5:0] residual_index,
    input wire signed [15:0] residual_value,
    input wire reference_valid,
    input wire reference_bank,
    input wire destination_bank,
    input wire store_block_stored,
    input wire ddram_busy,
    input wire [63:0] ddram_dout,
    input wire ddram_dout_ready,
    output wire [7:0] ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire ddram_rd,
    output wire store_select,
    output wire [7:0] store_pixel_value,
    output wire [11:0] store_pixel_x,
    output wire [11:0] store_pixel_y,
    output wire store_pixel_valid,
    output wire store_block_start,
    output wire store_block_complete,
    output reg active,
    output reg read_seen,
    output reg [7:0] sample_value,
    output reg sample_nonzero,
    output reg half_sample_seen,
    output reg reconstructed_seen,
    output reg [7:0] reconstructed_value,
    output reg persisted_seen,
    output reg [7:0] persisted_value,
    output reg error
);

localparam [28:0] Y_BASE=29'h06000000, CB_BASE=29'h0600A8C0, CR_BASE=29'h0600D2F0, BANK_OFF=29'h00010000;
localparam [15:0] MB_COUNT=16'd48;
localparam [8:0] MB_WIDTH=9'd8;
localparam integer MAX_BLOCKS=16;

function automatic [28:0] r90;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r90=(x<<6)+(x<<4)+(x<<3)+(x<<1); end
endfunction
function automatic [28:0] r45;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r45=(x<<5)+(x<<3)+(x<<2)+x; end
endfunction
function automatic [28:0] block_addr;
    input [28:0] off; input [8:0] c; input [8:0] mr; input [2:0] b; input [2:0] rr;
    reg [11:0] lr,lw,cr;
    begin
        if(b<4) begin
            lr=({3'd0,mr}<<4)+{8'd0,b[1],rr};
            lw=({3'd0,c}<<1)+{11'd0,b[0]};
            block_addr=Y_BASE+off+r90(lr)+{17'd0,lw};
        end else begin
            cr=({3'd0,mr}<<3)+{9'd0,rr};
            block_addr=(b==4?CB_BASE:CR_BASE)+off+r45(cr)+{20'd0,c};
        end
    end
endfunction
function automatic [28:0] pixel_addr;
    input [28:0] off; input [2:0] b; input [11:0] x; input [11:0] y;
    begin
        if(b<4) pixel_addr=Y_BASE+off+r90(y)+{20'd0,x[11:3]};
        else pixel_addr=(b==4?CB_BASE:CR_BASE)+off+r45(y)+{20'd0,x[11:3]};
    end
endfunction
function automatic [7:0] bat;
    input [63:0] w; input [2:0] n;
    begin case(n)
        0:bat=w[7:0];1:bat=w[15:8];2:bat=w[23:16];3:bat=w[31:24];
        4:bat=w[39:32];5:bat=w[47:40];6:bat=w[55:48];default:bat=w[63:56];
    endcase end
endfunction
function automatic [7:0] clip;
    input [7:0] p; input signed [15:0] f; reg signed [16:0] s;
    begin
        s=$signed({9'd0,p})+{f[15],f};
        if(s<0) clip=0; else if(s>255) clip=255; else clip=s[7:0];
    end
endfunction
function automatic signed [7:0] chroma_half_vector;
    input signed [7:0] v; reg signed [8:0] a;
    begin
        if(v<0) begin a=-$signed(v); chroma_half_vector=-(a>>>1); end
        else chroma_half_vector=$signed(v)>>>1;
    end
endfunction
function automatic [7:0] round_prediction;
    input [10:0] sum; input hx; input hy;
    begin
        if(hx&&hy) round_prediction=(sum+11'd2)>>2;
        else if(hx||hy) round_prediction=(sum+11'd1)>>1;
        else round_prediction=sum[7:0];
    end
endfunction

reg signed [7:0] mvx [0:47];
reg signed [7:0] mvy [0:47];
reg [5:0] motion_count;
reg signed [15:0] rm [0:1023];
reg [5:0] desc_mb [0:15];
reg [2:0] desc_block [0:15];
reg [4:0] desc_count;
reg [3:0] current_desc_slot;
reg desc_active;
reg [5:0] sample_expected;
reg metadata_done;
reg [4:0] exec_desc_slot;

reg pending, started;
reg reference_bank_latched, destination_bank_latched;
reg req, waitresp, req_kind; // 0 prediction pixel, 1 persistence row verify
reg [15:0] mbi;
reg [8:0] col, mrow;
reg [2:0] blk;
reg [23:0] timeout;
reg [63:0] resrows [0:7];
reg emit, wait_store, pixel_setup;
reg [5:0] ei;
reg [2:0] verify_row;
reg [1:0] tap_index;
reg [10:0] pred_sum;
reg [7:0] out_reg;
// kate - Commit 154 observer-only failure cause.  This register does not feed
// any engine control.  While nonzero, the existing sample/reconstruction proof
// outputs carry E?/D? signatures so the top-level USER diagnostic can classify
// the first generalized-P error without adding another functional interface.
reg [3:0] diag_error_cause;
// kate - Commit 160 observer-only timeout phase.  The live phase tracks the
// four transaction regions that can consume the watchdog; the latched phase is
// captured only when cause 6 first wins.  Neither register feeds engine control.
// 1 prediction DDR request issue/accept, 2 prediction response wait,
// 3 reconstructed block output/store completion, 4 persistence readback.
reg [2:0] diag_timeout_phase;
reg [2:0] diag_timeout_phase_latched;
integer i;

wire [28:0] roff=reference_bank_latched?BANK_OFF:0;
wire [28:0] doff=destination_bank_latched?BANK_OFF:0;
wire [2:0] er=ei[5:3], el=ei[2:0];

wire signed [7:0] mb_mvx=mvx[mbi[5:0]];
wire signed [7:0] mb_mvy=mvy[mbi[5:0]];
wire signed [7:0] exec_mvx=(blk<4)?mb_mvx:chroma_half_vector(mb_mvx);
wire signed [7:0] exec_mvy=(blk<4)?mb_mvy:chroma_half_vector(mb_mvy);
wire signed [8:0] exec_int_x=$signed(exec_mvx)>>>1;
wire signed [8:0] exec_int_y=$signed(exec_mvy)>>>1;
wire half_x=exec_mvx[0];
wire half_y=exec_mvy[0];

wire [11:0] luma_x=({3'd0,col}<<4)+{8'd0,blk[0],el};
wire [11:0] luma_y=({3'd0,mrow}<<4)+{8'd0,blk[1],er};
wire [11:0] chroma_x=({3'd0,col}<<3)+{9'd0,el};
wire [11:0] chroma_y=({3'd0,mrow}<<3)+{9'd0,er};
wire [11:0] dest_x=(blk<4)?luma_x:chroma_x;
wire [11:0] dest_y=(blk<4)?luma_y:chroma_y;
wire signed [13:0] src_base_x=$signed({1'b0,dest_x})+$signed(exec_int_x);
wire signed [13:0] src_base_y=$signed({1'b0,dest_y})+$signed(exec_int_y);
wire [11:0] plane_width=(blk<4)?12'd128:12'd64;
wire [11:0] plane_height=(blk<4)?12'd96:12'd48;
wire signed [13:0] src_last_x=src_base_x+(half_x?14'sd1:14'sd0);
wire signed [13:0] src_last_y=src_base_y+(half_y?14'sd1:14'sd0);
wire signed [13:0] plane_width_s=$signed({2'b00,plane_width});
wire signed [13:0] plane_height_s=$signed({2'b00,plane_height});
wire source_bounds_ok=(src_base_x>=0)&&(src_base_y>=0)&&
    (src_last_x<plane_width_s)&&(src_last_y<plane_height_s);

wire tap_dx=(half_x&&half_y)?tap_index[0]:(half_x?tap_index[0]:1'b0);
wire tap_dy=(half_x&&half_y)?tap_index[1]:(half_y?tap_index[0]:1'b0);
wire tap_last=(half_x&&half_y)?(tap_index==2'd3):((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire signed [13:0] src_x_tap_signed=src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];

wire residual_hit=(exec_desc_slot<desc_count)&&
    (desc_mb[exec_desc_slot[3:0]]==mbi[5:0])&&
    (desc_block[exec_desc_slot[3:0]]==blk);
wire [9:0] residual_mem_index={exec_desc_slot[3:0],6'b000000}+{4'd0,ei};
wire signed [15:0] residual_pel=residual_hit?rm[residual_mem_index]:16'sd0;

wire [7:0] current_tap_sample=bat(ddram_dout,src_x_tap[2:0]);
wire [10:0] pred_sum_with_current=pred_sum+{3'd0,current_tap_sample};
wire [7:0] predicted_current=round_prediction(pred_sum_with_current,half_x,half_y);
wire [7:0] reconstructed_current=clip(predicted_current,residual_pel);

assign ddram_burstcnt=req?8'd1:0;
assign ddram_addr=req ? (req_kind ? block_addr(doff,col,mrow,blk,verify_row)
                                  : pixel_addr(roff,blk,src_x_tap,src_y_tap)) : 29'd0;
assign ddram_rd=req;

assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&(ei==0);
assign store_block_complete=emit&&(ei==63);
assign store_pixel_x=(blk<4)?luma_x:(blk==4)?{2'b01,chroma_x[9:0]}:{2'b10,chroma_x[9:0]};
assign store_pixel_y=(blk<4)?luma_y:chroma_y;

wire ready_res=metadata_done;
wire descriptor_order_error=(desc_count!=0)&&
    ({residual_value[8:3],residual_value[2:0]}<=
     {desc_mb[(desc_count-1'b1)&5'h0f],desc_block[(desc_count-1'b1)&5'h0f]});
wire new_picture_metadata=capture_enable&&residual_valid&&!desc_active&&
    (residual_index==6'h3e)&&persisted_seen&&!active;
wire unused_shift_map=&{1'b0,shift_right_map};

always @(posedge clk) begin
    if(reset) begin
        motion_count<=0; desc_count<=0; current_desc_slot<=0; desc_active<=0; sample_expected<=0; metadata_done<=0; exec_desc_slot<=0;
        pending<=0; started<=0; active<=0; reference_bank_latched<=0; destination_bank_latched<=0;
        req<=0; waitresp<=0; req_kind<=0; mbi<=0; col<=0; mrow<=0; blk<=0; timeout<=0;
        emit<=0; wait_store<=0; pixel_setup<=0; ei<=0; verify_row<=0; tap_index<=0; pred_sum<=0; out_reg<=0;
        read_seen<=0; sample_value<=0; sample_nonzero<=0; half_sample_seen<=0;
        reconstructed_seen<=0; reconstructed_value<=0; persisted_seen<=0; persisted_value<=0; error<=0;
        diag_error_cause<=0; diag_timeout_phase<=0; diag_timeout_phase_latched<=0;
        for(i=0;i<48;i=i+1) begin mvx[i]<=0; mvy[i]<=0; end
        for(i=0;i<16;i=i+1) begin desc_mb[i]<=0; desc_block[i]<=0; end
        for(i=0;i<8;i=i+1) resrows[i]<=0;
    end else begin
        // Consecutive generalized P picture re-arm.  The first motion word is
        // captured in the same cycle that the prior persistence indication is retired.
        if(new_picture_metadata) begin
            persisted_seen<=0; metadata_done<=0; motion_count<=6'd1; mvx[0]<=residual_value[15:8]; mvy[0]<=residual_value[7:0];
            desc_count<=0; current_desc_slot<=0; desc_active<=0; sample_expected<=0; exec_desc_slot<=0;
            pending<=request; started<=0; req<=0; waitresp<=0; emit<=0; wait_store<=0; pixel_setup<=0;
            mbi<=0; col<=0; mrow<=0; blk<=0; ei<=0; verify_row<=0; half_sample_seen<=0;
            diag_error_cause<=0; diag_timeout_phase<=0; diag_timeout_phase_latched<=0;
        end else if(capture_enable&&residual_valid) begin
            if(desc_active) begin
                if(residual_index!=sample_expected) begin
                    error<=1;
                    if(diag_error_cause==0) diag_error_cause<=4'd1;
                end
                else begin
                    rm[{current_desc_slot,6'b000000}+residual_index]<=residual_value;
                    if(residual_index==6'd63) desc_active<=0;
                    else sample_expected<=sample_expected+1'b1;
                end
            end else if(residual_index==6'h3e) begin
                if(metadata_done||(desc_count!=0)||(motion_count>=6'd48)) begin
                    error<=1;
                    if(diag_error_cause==0) diag_error_cause<=4'd1;
                end
                else begin mvx[motion_count]<=residual_value[15:8]; mvy[motion_count]<=residual_value[7:0]; motion_count<=motion_count+1'b1; end
            end else if((residual_index==6'h3f)&&(residual_value[15:12]==4'hB)) begin
                if((motion_count!=6'd48)||metadata_done||(desc_count>=MAX_BLOCKS)||(residual_value[8:3]>=48)||(residual_value[2:0]>=6)||descriptor_order_error) begin
                    error<=1;
                    if(diag_error_cause==0) diag_error_cause<=4'd1;
                end
                else begin
                    current_desc_slot<=desc_count[3:0]; desc_mb[desc_count]<=residual_value[8:3]; desc_block[desc_count]<=residual_value[2:0];
                    desc_count<=desc_count+1'b1; desc_active<=1; sample_expected<=0;
                end
            end else if((residual_index==6'h3f)&&(residual_value==16'shA2FF)) begin
                if((motion_count!=6'd48)||metadata_done) begin
                    error<=1;
                    if(diag_error_cause==0) diag_error_cause<=4'd1;
                end
                else metadata_done<=1;
            end else begin
                error<=1;
                if(diag_error_cause==0) diag_error_cause<=4'd1;
            end
        end

        if(request&&!started) pending<=1;
        if(pending&&!started&&ready_res) begin
            pending<=0; started<=1; active<=1; reference_bank_latched<=reference_bank; destination_bank_latched<=destination_bank;
            timeout<=24'hffffff; mbi<=0; col<=0; mrow<=0; blk<=0; ei<=0; exec_desc_slot<=0; pixel_setup<=1;
            diag_timeout_phase<=3'd1;
            if(!reference_valid||(reference_bank==destination_bank)||(motion_count!=6'd48)) begin
                error<=1; active<=0; persisted_seen<=1; timeout<=0; pixel_setup<=0;
                if(diag_error_cause==0) diag_error_cause<=4'd2;
            end
        end

        if(started&&!persisted_seen&&timeout!=0) begin
            timeout<=timeout-1'b1;
            if(timeout==1) begin
                error<=1;
                if(diag_error_cause==0) begin
                    diag_error_cause<=4'd6;
                    diag_timeout_phase_latched<=
                        (diag_timeout_phase==3'd0) ? 3'd1 : diag_timeout_phase;
                end
            end
        end

        if(pixel_setup) begin
            pixel_setup<=0; pred_sum<=0; tap_index<=0;
            if(!source_bounds_ok) begin
                error<=1; active<=0; persisted_seen<=1; timeout<=0;
                if(diag_error_cause==0) diag_error_cause<=4'd3;
            end
            else begin
                if(half_x||half_y) half_sample_seen<=1;
                req_kind<=0; req<=1; diag_timeout_phase<=3'd1;
            end
        end

        if(req&&!ddram_busy) begin
            req<=0; waitresp<=1;
            diag_timeout_phase<=req_kind ? 3'd4 : 3'd2;
        end

        if(ddram_dout_ready) begin
            if(!waitresp) begin
                error<=1;
                if(diag_error_cause==0) diag_error_cause<=4'd4;
            end
            else begin
                waitresp<=0;
                if(!req_kind) begin
                    if(tap_last) begin
                        out_reg<=reconstructed_current; emit<=1; diag_timeout_phase<=3'd3;
                        if((mbi==0)&&(blk==0)&&(ei==0)) begin
                            read_seen<=1; sample_value<=predicted_current; sample_nonzero<=|predicted_current;
                        end
                    end else begin
                        pred_sum<=pred_sum_with_current; tap_index<=tap_index+1'b1; req<=1; diag_timeout_phase<=3'd1;
                    end
                end else begin
                    diag_timeout_phase<=3'd4;
                    if(ddram_dout!=resrows[verify_row]) begin
                        error<=1;
                        if(diag_error_cause==0) diag_error_cause<=4'd5;
                    end
                    if((mbi==0)&&(blk==0)&&(verify_row==0)) persisted_value<=ddram_dout[7:0];
                    if(verify_row==3'd7) begin
                        if(residual_hit) exec_desc_slot<=exec_desc_slot+1'b1;
                        if(blk==3'd5) begin
                            if(mbi+1>=MB_COUNT) begin
                                if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=desc_count) begin
                                    error<=1;
                                    if(diag_error_cause==0) diag_error_cause<=4'd7;
                                end
                                persisted_seen<=1; reconstructed_seen<=1; active<=0; timeout<=0;
                            end else begin
                                mbi<=mbi+1'b1;
                                if(col+1>=MB_WIDTH) begin col<=0; mrow<=mrow+1'b1; end else col<=col+1'b1;
                                blk<=0; ei<=0; pixel_setup<=1; diag_timeout_phase<=3'd1;
                            end
                        end else begin
                            blk<=blk+1'b1; ei<=0; pixel_setup<=1; diag_timeout_phase<=3'd1;
                        end
                    end else begin verify_row<=verify_row+1'b1; req<=1; end
                end
            end
        end

        if(emit) begin
            resrows[er][{el,3'b000}+:8]<=out_reg;
            if((mbi==0)&&(blk==0)&&(ei==0)) reconstructed_value<=out_reg;
            emit<=0;
            if(ei==6'd63) begin
                wait_store<=1; diag_timeout_phase<=3'd3;
            end
            else begin ei<=ei+1'b1; pixel_setup<=1; diag_timeout_phase<=3'd1; end
        end

        if(wait_store&&store_block_stored) begin
            wait_store<=0; req_kind<=1; verify_row<=0; req<=1; diag_timeout_phase<=3'd4;
        end

        // Diagnostic carrier only.  No functional control consumes these proof
        // values when error is asserted; normal USER acceptance already rejects
        // probe_error.  Commit 160 remaps timeout cause 6 only: E1/D1..E4/D4
        // encode timeout phase 1..4 for the existing Commit-159 A-B-C display.
        // Thus a timeout-before-writer failure is shown as 1-P-C, while all
        // non-timeout generalized-P causes retain their historical E?/D? codes.
        if(diag_error_cause!=0) begin
            if((diag_error_cause==4'd6) &&
               (diag_timeout_phase_latched>=3'd1) &&
               (diag_timeout_phase_latched<=3'd4)) begin
                sample_value<={4'hE,1'b0,diag_timeout_phase_latched};
                reconstructed_value<={4'hD,1'b0,diag_timeout_phase_latched};
            end
            else begin
                sample_value<={4'hE,diag_error_cause};
                reconstructed_value<={4'hD,diag_error_cause};
            end
        end
    end
end

endmodule
