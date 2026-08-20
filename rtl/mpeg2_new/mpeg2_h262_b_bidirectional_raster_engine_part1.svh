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

// Commit 232 timing repair: execution begins two cycles after motion_word is
// loaded. Capture block-normalized motion fields in a separate preserved stage
// during residual_load. The prelaunch address path then starts here instead of
// crossing the live B-sideband select and vector normalization in one cycle.
(* preserve *) reg [1:0] exec_direction;
(* preserve *) reg signed [7:0] exec_fmvx,exec_fmvy;
(* preserve *) reg signed [7:0] exec_bmvx,exec_bmvy;
(* preserve *) reg signed [7:0] phase_mvx,phase_mvy;
(* preserve *) reg phase_backward;
(* preserve *) reg [28:0] bidir_prelaunch_addr,next_prelaunch_addr;
(* preserve *) reg [2:0] bidir_prelaunch_byte,next_prelaunch_byte;
(* preserve *) reg bidir_prelaunch_valid,next_prelaunch_valid;
(* preserve *) reg [28:0] phase_base_addr;
(* preserve *) reg [2:0] phase_base_byte;
(* preserve *) reg [28:0] miss_prelaunch_addr;
(* preserve *) reg [2:0] miss_prelaunch_byte;
(* preserve *) reg [6:0] phase_row_words;
(* preserve *) reg phase_bounds_ok;

// Commit 203: descriptors use synchronous M10K storage while P and B share
// the 2048-block sparse spatial-sample RAM in their parent wrapper.
(* ramstyle = "M10K" *) reg [13:0] desc_mem [0:2047];
reg [13:0] desc_word;
reg [10:0] bank_desc_count [0:1];
reg [13:0] bank_last_desc_word [0:1];
reg [10:0] bank_motion_base [0:1];
reg [10:0] bank_motion_end [0:1];
reg [5:0] bank_row [0:1];
reg [1:0] bank_ready;
reg capture_bank,execute_bank;
wire [10:0] capture_desc_count=bank_desc_count[capture_bank];
wire [13:0] capture_last_desc_word=bank_last_desc_word[capture_bank];
wire [10:0] capture_motion_base=bank_motion_base[capture_bank];
wire [5:0] capture_row=bank_row[capture_bank];
wire execute_ready=bank_ready[execute_bank];
// Preserve the established internal proof name used by focused regressions;
// it now means that the oldest execution bank contains a complete row.
wire metadata_done=execute_ready;
reg [9:0] current_desc_slot;
reg desc_active;
reg [5:0] sample_expected;
reg [9:0] exec_desc_slot;
reg [10:0] exec_desc_count_latched;
reg [10:0] exec_motion_end;
reg row_final_latched;

reg pending,started;
reg future_bank_latched;
reg req,waitresp,lookup_wait;
reg [10:0] mbi;
reg [5:0] col,mrow;
reg [2:0] blk;
reg [25:0] timeout;
reg emit,wait_store,pixel_setup,residual_load,residual_load_wait;
reg [5:0] ei;
reg pred_direction;
reg [1:0] tap_index;
// kate - Commit 182 timing closure.  src_x_tap[2:0] selects the byte of the
// returned 64-bit DDR word, but the data does not arrive until several cycles
// after the request is accepted.  Computing that select combinationally put the
// whole motion-vector address chain in series with the prediction/clip datapath
// inside one 54 MHz cycle.  Capture it when the request is accepted instead;
// every input to src_x_tap is held constant across the DDR wait, so the
// registered copy is the same value the address itself was formed from.
reg [2:0] tap_byte_sel;
reg [10:0] pred_sum;
reg [7:0] forward_prediction;
reg [7:0] out_reg;
reg emit_advanced;
reg [11:0] emit_x,emit_y;
reg emit_block_start,emit_block_complete;
reg block_fetch_start;
reg [2:0] block_phase0_base_byte,block_phase1_base_byte;
wire fast_pixel_advance,slow_pixel_advance,precompute_after_advance;
wire block_lookup_request,block_lookup_phase;
wire [3:0] block_lookup_row;
wire block_lookup_column;
wire block_lookup_ready,block_lookup_valid;
wire [63:0] block_lookup_data;
wire block_fetch_active,block_fetch_complete,block_fetch_error;
wire [28:0] block_fetch_addr;
wire block_fetch_rd;
wire [6:0] block_fetch_issued,block_fetch_returned;
wire [2:0] block_fetch_outstanding;

wire [28:0] future_off=future_bank_latched?BANK_OFF:29'd0;
wire [28:0] past_off=future_bank_latched?29'd0:BANK_OFF;
wire [2:0] er=ei[5:3],el=ei[2:0];
wire signed [7:0] exec_mvx=phase_mvx;
wire signed [7:0] exec_mvy=phase_mvy;
wire signed [8:0] exec_int_x=$signed(exec_mvx)>>>1;
wire signed [8:0] exec_int_y=$signed(exec_mvy)>>>1;
wire half_x=exec_mvx[0];
wire half_y=exec_mvy[0];

wire [11:0] luma_x=({6'd0,col}<<4)+{8'd0,blk[0],el};
wire [11:0] luma_y=({6'd0,mrow}<<4)+{8'd0,blk[1],er};
wire [11:0] chroma_x=({6'd0,col}<<3)+{9'd0,el};
