//============================================================================
// MiSTer Media Player - generalized progressive 4:2:0 B-picture raster engine
//
// kate - Commit 169: widen the established bidirectional B reconstruction path
// through the 720x480 / 45x30 macroblock envelope. Ordered B motion metadata is
// retained in synchronous M10K-oriented RAM; sparse residual storage remains
// bounded to four Y0 blocks. B output remains in the non-reference scratch
// frame and is verified by DDR readback before persisted_seen.
//
// Sideband protocol:
//   0x38/0x39/0x3a: first motion word, forward/backward/interpolated direction
//   0x3c:           geometry {4'b0, mb_width[5:0], mb_height[5:0]}
//   0x3b:           second motion word, backward vector
//   0x3f, 11xxxxxxxxxxxbbb: residual descriptor (11-bit MB + block)
//   0x00..0x3f:     64 signed residual samples after a descriptor
//   0x3f, A3FF:     metadata terminator
//============================================================================
module mpeg2_h262_b_bidirectional_raster_engine
(
    input  wire clk,
    input  wire reset,
    input  wire capture_enable,
    input  wire request,
    input  wire sideband_valid,
    input  wire [5:0] sideband_index,
    input  wire signed [15:0] sideband_value,
    input  wire reference_valid,
    input  wire future_reference_bank,
    input  wire store_block_stored,
    input  wire ddram_busy,
    input  wire [63:0] ddram_dout,
    input  wire ddram_dout_ready,
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
    output reg  active,
    output reg  read_seen,
    output reg  sample_nonzero,
    output reg  half_sample_seen,
    output reg  reconstructed_seen,
    output reg  persisted_seen,
    output reg  error
);

localparam [28:0]
    Y_BASE      = 29'h06000000,
    CB_BASE     = 29'h0600A8C0,
    CR_BASE     = 29'h0600D2F0,
    BANK_OFF    = 29'h00010000,
    SCRATCH_OFF = 29'h00020000;
localparam integer MAX_MB=1350;
localparam integer MAX_BLOCKS=4;

reg [5:0] mb_width,mb_height;
reg geometry_seen;
wire geometry_ok=(mb_width!=0)&&(mb_width<=6'd45)&&(mb_height!=0)&&(mb_height<=6'd30);
wire [11:0] padded_luma_width={6'd0,mb_width}<<4;
wire [11:0] padded_luma_height={6'd0,mb_height}<<4;
wire [11:0] padded_chroma_width={6'd0,mb_width}<<3;
wire [11:0] padded_chroma_height={6'd0,mb_height}<<3;

function automatic [28:0] r90;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r90=(x<<6)+(x<<4)+(x<<3)+(x<<1); end
endfunction
function automatic [28:0] r45;
    input [11:0] r; reg [28:0] x;
    begin x={17'd0,r}; r45=(x<<5)+(x<<3)+(x<<2)+x; end
endfunction
function automatic [28:0] block_addr;
    input [5:0] c; input [5:0] mr; input [2:0] b; input [2:0] rr;
    reg [11:0] lr,lw,cr;
    begin
        if(b<4) begin
            lr=({6'd0,mr}<<4)+{8'd0,b[1],rr};
            lw=({6'd0,c}<<1)+{11'd0,b[0]};
            block_addr=Y_BASE+SCRATCH_OFF+r90(lr)+{17'd0,lw};
        end else begin
            cr=({6'd0,mr}<<3)+{9'd0,rr};
            block_addr=(b==4?CB_BASE:CR_BASE)+SCRATCH_OFF+r45(cr)+{20'd0,c};
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
    begin s=$signed({9'd0,p})+{f[15],f};if(s<0)clip=0;else if(s>255)clip=255;else clip=s[7:0];end
endfunction
function automatic signed [7:0] chroma_half_vector;
    input signed [7:0] v; reg signed [8:0] a;
    begin if(v<0)begin a=-$signed(v);chroma_half_vector=-(a>>>1);end else chroma_half_vector=$signed(v)>>>1;end
endfunction
function automatic [7:0] round_prediction;
    input [10:0] sum; input hx; input hy;
    begin if(hx&&hy)round_prediction=(sum+11'd2)>>2;else if(hx||hy)round_prediction=(sum+11'd1)>>1;else round_prediction=sum[7:0];end
endfunction

// {direction[1:0], fmvx, fmvy, bmvx, bmvy}. No reset loop: capture and
// execution are disjoint phases, allowing synchronous block-RAM inference.
(* ramstyle = "M10K" *) reg [33:0] motion_mem [0:MAX_MB-1];
reg [10:0] motion_count;
reg [33:0] motion_word;
reg motion_load;
reg motion_first_pending;
reg [1:0] pending_direction;
reg signed [7:0] pending_fmvx,pending_fmvy;
wire [1:0] mb_direction=motion_word[33:32];
wire signed [7:0] mb_fmvx=$signed(motion_word[31:24]);
wire signed [7:0] mb_fmvy=$signed(motion_word[23:16]);
wire signed [7:0] mb_bmvx=$signed(motion_word[15:8]);
wire signed [7:0] mb_bmvy=$signed(motion_word[7:0]);

reg signed [15:0] rm [0:255];
reg [10:0] desc_mb [0:3];
reg [2:0] desc_block [0:3];
reg [2:0] desc_count;
reg [1:0] current_desc_slot;
reg desc_active;
reg [5:0] sample_expected;
reg metadata_done;
reg [2:0] exec_desc_slot;

reg pending,started;
reg future_bank_latched;
reg req,waitresp,req_kind;
reg [10:0] mbi;
reg [5:0] col,mrow;
reg [2:0] blk;
reg [25:0] timeout;
reg [63:0] resrows [0:7];
reg emit,wait_store,pixel_setup;
reg [5:0] ei;
reg [2:0] verify_row;
reg pred_direction;
reg [1:0] tap_index;
reg [10:0] pred_sum;
reg [7:0] forward_prediction;
reg [7:0] out_reg;
integer i;

wire [28:0] future_off=future_bank_latched?BANK_OFF:29'd0;
wire [28:0] past_off=future_bank_latched?29'd0:BANK_OFF;
wire [2:0] er=ei[5:3],el=ei[2:0];
wire use_backward=(mb_direction==2'd2)||((mb_direction==2'd3)&&pred_direction);
wire signed [7:0] selected_luma_mvx=use_backward?mb_bmvx:mb_fmvx;
wire signed [7:0] selected_luma_mvy=use_backward?mb_bmvy:mb_fmvy;
wire signed [7:0] exec_mvx=(blk<4)?selected_luma_mvx:chroma_half_vector(selected_luma_mvx);
wire signed [7:0] exec_mvy=(blk<4)?selected_luma_mvy:chroma_half_vector(selected_luma_mvy);
wire signed [8:0] exec_int_x=$signed(exec_mvx)>>>1;
wire signed [8:0] exec_int_y=$signed(exec_mvy)>>>1;
wire half_x=exec_mvx[0];
wire half_y=exec_mvy[0];

wire [11:0] luma_x=({6'd0,col}<<4)+{8'd0,blk[0],el};
wire [11:0] luma_y=({6'd0,mrow}<<4)+{8'd0,blk[1],er};
wire [11:0] chroma_x=({6'd0,col}<<3)+{9'd0,el};
wire [11:0] chroma_y=({6'd0,mrow}<<3)+{9'd0,er};
wire [11:0] dest_x=(blk<4)?luma_x:chroma_x;
wire [11:0] dest_y=(blk<4)?luma_y:chroma_y;
wire signed [13:0] src_base_x=$signed({1'b0,dest_x})+$signed(exec_int_x);
wire signed [13:0] src_base_y=$signed({1'b0,dest_y})+$signed(exec_int_y);
wire [11:0] plane_width=(blk<4)?padded_luma_width:padded_chroma_width;
wire [11:0] plane_height=(blk<4)?padded_luma_height:padded_chroma_height;
wire signed [13:0] src_last_x=src_base_x+(half_x?14'sd1:14'sd0);
wire signed [13:0] src_last_y=src_base_y+(half_y?14'sd1:14'sd0);
wire source_bounds_ok=(src_base_x>=0)&&(src_base_y>=0)&&
    (src_last_x<$signed({2'b00,plane_width}))&&(src_last_y<$signed({2'b00,plane_height}));

wire tap_dx=(half_x&&half_y)?tap_index[0]:(half_x?tap_index[0]:1'b0);
wire tap_dy=(half_x&&half_y)?tap_index[1]:(half_y?tap_index[0]:1'b0);
wire tap_last=(half_x&&half_y)?(tap_index==2'd3):((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire signed [13:0] src_x_tap_signed=src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire [28:0] selected_reference_off=use_backward?future_off:past_off;

wire residual_hit=(exec_desc_slot<desc_count)&&(desc_mb[exec_desc_slot[1:0]]==mbi)&&(desc_block[exec_desc_slot[1:0]]==blk);
wire [7:0] residual_mem_index={exec_desc_slot[1:0],6'b000000}+{2'd0,ei};
wire signed [15:0] residual_pel=residual_hit?rm[residual_mem_index]:16'sd0;
wire [7:0] current_tap_sample=bat(ddram_dout,src_x_tap[2:0]);
wire [10:0] pred_sum_with_current=pred_sum+{3'd0,current_tap_sample};
wire [7:0] selected_prediction=round_prediction(pred_sum_with_current,half_x,half_y);
wire [8:0] bidir_sum={1'b0,forward_prediction}+{1'b0,selected_prediction}+9'd1;
wire [7:0] bidir_prediction=bidir_sum[8:1];
wire [7:0] final_prediction=(mb_direction==2'd3)?bidir_prediction:selected_prediction;
wire [7:0] reconstructed_current=clip(final_prediction,residual_pel);

assign ddram_burstcnt=req?8'd1:8'd0;
assign ddram_addr=req?(req_kind?block_addr(col,mrow,blk,verify_row):pixel_addr(selected_reference_off,blk,src_x_tap,src_y_tap)):29'd0;
assign ddram_rd=req;
assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&(ei==0);
assign store_block_complete=emit&&(ei==63);
// Wide B scratch tag: X[11:10]=11 identifies scratch; Y[11:9]
// identifies Y/Cb/Cr while preserving 10-bit X and 9-bit Y coordinates.
assign store_pixel_x={2'b11,dest_x[9:0]};
assign store_pixel_y=(blk<4)?{3'b100,luma_y[8:0]}:(blk==4)?{3'b101,chroma_y[8:0]}:{3'b110,chroma_y[8:0]};

wire descriptor_order_error=(desc_count!=0)&&
    ({sideband_value[13:3],sideband_value[2:0]}<={desc_mb[(desc_count-1'b1)&3'h3],desc_block[(desc_count-1'b1)&3'h3]});
wire first_direction_word=(sideband_index==6'h38)||(sideband_index==6'h39)||(sideband_index==6'h3a);
wire [1:0] direction_word=(sideband_index==6'h38)?2'd1:(sideband_index==6'h39)?2'd2:2'd3;
wire geometry_word=(sideband_index==6'h3c)&&(sideband_value[15:12]==4'd0);
wire descriptor_word=(sideband_index==6'h3f)&&(sideband_value[15:14]==2'b11);

always @(posedge clk) begin
    if(reset) begin
        mb_width<=0;mb_height<=0;geometry_seen<=0;motion_count<=0;motion_word<=0;motion_load<=0;
        motion_first_pending<=0;pending_direction<=0;pending_fmvx<=0;pending_fmvy<=0;
        desc_count<=0;current_desc_slot<=0;desc_active<=0;sample_expected<=0;metadata_done<=0;exec_desc_slot<=0;
        pending<=0;started<=0;active<=0;future_bank_latched<=0;req<=0;waitresp<=0;req_kind<=0;
        mbi<=0;col<=0;mrow<=0;blk<=0;timeout<=0;emit<=0;wait_store<=0;pixel_setup<=0;ei<=0;verify_row<=0;
        pred_direction<=0;tap_index<=0;pred_sum<=0;forward_prediction<=0;out_reg<=0;
        read_seen<=0;sample_nonzero<=0;half_sample_seen<=0;reconstructed_seen<=0;persisted_seen<=0;error<=0;
        for(i=0;i<4;i=i+1)begin desc_mb[i]<=0;desc_block[i]<=0;end
        for(i=0;i<8;i=i+1)resrows[i]<=0;
    end else begin
        if(capture_enable&&sideband_valid) begin
            if(desc_active) begin
                if(sideband_index!=sample_expected)error<=1;
                else begin
                    rm[{current_desc_slot,6'b000000}+sideband_index]<=sideband_value;
                    if(sideband_index==6'd63)desc_active<=0;else sample_expected<=sample_expected+1'b1;
                end
            end else if(first_direction_word) begin
                if(metadata_done||motion_first_pending||(motion_count>=MAX_MB)||(desc_count!=0))error<=1;
                else begin pending_direction<=direction_word;pending_fmvx<=sideband_value[15:8];pending_fmvy<=sideband_value[7:0];motion_first_pending<=1;end
            end else if(geometry_word) begin
                if(metadata_done||geometry_seen||!motion_first_pending||(motion_count!=0)||
                   (sideband_value[11:6]==0)||(sideband_value[11:6]>6'd45)||(sideband_value[5:0]==0)||(sideband_value[5:0]>6'd30))error<=1;
                else begin mb_width<=sideband_value[11:6];mb_height<=sideband_value[5:0];geometry_seen<=1;end
            end else if(sideband_index==6'h3b) begin
                if(metadata_done||!motion_first_pending||(motion_count>=MAX_MB)||!geometry_seen)error<=1;
                else begin
                    motion_mem[motion_count]<={pending_direction,pending_fmvx,pending_fmvy,sideband_value[15:8],sideband_value[7:0]};
                    motion_count<=motion_count+1'b1;motion_first_pending<=0;
                end
            end else if(descriptor_word) begin
                if((motion_count==0)||motion_first_pending||metadata_done||(desc_count>=MAX_BLOCKS)||
                   (sideband_value[13:3]>=MAX_MB)||(sideband_value[2:0]>=6)||descriptor_order_error)error<=1;
                else begin
                    current_desc_slot<=desc_count[1:0];desc_mb[desc_count]<=sideband_value[13:3];desc_block[desc_count]<=sideband_value[2:0];
                    desc_count<=desc_count+1'b1;desc_active<=1;sample_expected<=0;
                end
            end else if((sideband_index==6'h3f)&&(sideband_value==16'shA3FF)) begin
                if((motion_count==0)||motion_first_pending||metadata_done||!geometry_seen)error<=1;else metadata_done<=1;
            end else error<=1;
        end

        if(request&&!started)pending<=1;
        if(pending&&!started&&metadata_done) begin
            pending<=0;started<=1;active<=1;future_bank_latched<=future_reference_bank;timeout<=26'h3ffffff;
            mbi<=0;col<=0;mrow<=0;blk<=0;ei<=0;exec_desc_slot<=0;pred_direction<=0;motion_load<=1;pixel_setup<=0;persisted_seen<=0;
            if(!reference_valid||!geometry_ok||(motion_count==0))begin error<=1;active<=0;persisted_seen<=1;timeout<=0;motion_load<=0;end
        end

        if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)error<=1;end

        if(motion_load) begin
            motion_load<=0;
            if((mbi>=motion_count)||(mbi>=MAX_MB))begin error<=1;active<=0;persisted_seen<=1;timeout<=0;end
            else begin motion_word<=motion_mem[mbi];pixel_setup<=1;end
        end

        if(pixel_setup) begin
            pixel_setup<=0;pred_sum<=0;tap_index<=0;
            if((mb_direction==0)||!source_bounds_ok)begin error<=1;active<=0;persisted_seen<=1;timeout<=0;end
            else begin if(half_x||half_y)half_sample_seen<=1;req_kind<=0;req<=1;end
        end

        if(req&&!ddram_busy)begin req<=0;waitresp<=1;end

        if(ddram_dout_ready) begin
            if(!waitresp)error<=1;
            else begin
                waitresp<=0;
                if(!req_kind) begin
                    if(tap_last) begin
                        if((mb_direction==2'd3)&&!pred_direction) begin
                            forward_prediction<=selected_prediction;pred_direction<=1;pred_sum<=0;tap_index<=0;pixel_setup<=1;
                        end else begin
                            out_reg<=reconstructed_current;emit<=1;
                            if((mbi==0)&&(blk==0)&&(ei==0))begin read_seen<=1;sample_nonzero<=|final_prediction;end
                        end
                    end else begin pred_sum<=pred_sum_with_current;tap_index<=tap_index+1'b1;req<=1;end
                end else begin
                    if(ddram_dout!=resrows[verify_row])error<=1;
                    if(verify_row==7) begin
                        if(residual_hit)exec_desc_slot<=exec_desc_slot+1'b1;
                        if(blk==5) begin
                            if((col+1'b1>=mb_width)&&(mrow+1'b1>=mb_height)) begin
                                if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=desc_count)error<=1;
                                if(mbi+1'b1!=motion_count)error<=1;
                                persisted_seen<=1;reconstructed_seen<=1;active<=0;timeout<=0;
                            end else begin
                                mbi<=mbi+1'b1;if(col+1'b1>=mb_width)begin col<=0;mrow<=mrow+1'b1;end else col<=col+1'b1;
                                blk<=0;ei<=0;pred_direction<=0;motion_load<=1;
                            end
                        end else begin blk<=blk+1'b1;ei<=0;pred_direction<=0;pixel_setup<=1;end
                    end else begin verify_row<=verify_row+1'b1;req<=1;end
                end
            end
        end

        if(emit) begin
            resrows[er][{el,3'b000}+:8]<=out_reg;emit<=0;
            if(ei==63)wait_store<=1;else begin ei<=ei+1'b1;pred_direction<=0;pixel_setup<=1;end
        end

        if(wait_store&&store_block_stored)begin wait_store<=0;req_kind<=1;verify_row<=0;req<=1;end
    end
end
endmodule
