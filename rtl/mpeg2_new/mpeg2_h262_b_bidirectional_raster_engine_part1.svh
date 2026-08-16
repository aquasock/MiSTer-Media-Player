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

// kate - Commit 170: 16 blocks x 64 spatial samples. This is deliberately
// bounded implementation storage, not an H.262 syntax limit.
reg signed [15:0] rm [0:1023];
reg [10:0] desc_mb [0:15];
reg [2:0] desc_block [0:15];
reg [4:0] desc_count;
reg [3:0] current_desc_slot;
reg desc_active;
reg [5:0] sample_expected;
reg metadata_done;
reg [4:0] exec_desc_slot;

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
