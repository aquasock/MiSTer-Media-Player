//============================================================================
// MiSTer Media Player - generalized H.262 P prediction+residual raster engine
//
// Sideband protocol:
//   * ordered motion words at residual_index 0x3e: {mvx[7:0],mvy[7:0]}
//   * legacy 128x96 residual descriptor: index 0x3f, value Bxxx
//   * Commit-166 wide descriptor: 0x3c -> 11-bit MB, 0x3d -> block
//   * 64 signed spatial samples at indices 0..63
//   * A2FE intermediate-row terminator at index 0x3f
//   * A2FF terminator at index 0x3f
//
// kate - Commit 166: geometry is derived from the live sequence dimensions,
// up to the established 720x480 progressive 4:2:0 envelope. Ordered motion
// words are retained in one synchronous M10K-oriented RAM instead of 48 flops.
// Commit 199 error_source is first-fault-only: 1 sample order, 2 motion
// metadata, 3/4/5 wide descriptor, 6 legacy descriptor, 7 terminator,
// 8 unknown metadata, 9 admission, 10 timeout, 11 motion range, 12 source
// bounds, 13 unexpected DDR response, 14 reserved, 15 descriptor count,
// 16 motion count.
//============================================================================
module mpeg2_h262_p_motion_residual_raster_engine
(
    input wire clk,
    input wire reset,
    input wire capture_enable,
    input wire request,
    input wire [13:0] horizontal_size,
    input wire [13:0] vertical_size,
    input wire [47:0] shift_right_map, // historical compatibility, unused
    input wire residual_valid,
    input wire [5:0] residual_index,
    input wire signed [15:0] residual_value,
    // Entry 304: motion vectors ride a dedicated 13-bit channel rather than
    // the 16-bit residual sideband, which cannot carry two 13-bit components.
    // The sideband index still identifies the record as motion (3e/3b).
    input wire signed [12:0] motion_vector_x,
    input wire signed [12:0] motion_vector_y,
    output wire residual_store_write,
    output wire [15:0] residual_store_write_address,
    output wire signed [15:0] residual_store_write_data,
    output wire [15:0] residual_store_read_address,
    input wire signed [15:0] residual_store_read_data,
    input wire reference_valid,
    input wire [1:0] reference_bank,
    input wire [1:0] destination_bank,
    input wire store_block_stored,
    input wire ddram_busy,
    input wire [63:0] ddram_dout,
    input wire ddram_dout_ready,
    input wire ddram_lookup_ready,
    input wire ddram_lookup_hit,
    input wire [63:0] ddram_lookup_data,
    output wire [7:0] ddram_burstcnt,
    output wire [28:0] ddram_addr,
    output wire ddram_rd,
    output wire ddram_cacheable,
    output wire ddram_lookup_request,
    output wire ddram_lookup_consume,
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
    output reg row_persisted,
    output reg [7:0] persisted_value,
    output reg [3:0] progress_stage,
    output reg error,
    output reg [4:0] error_source
);

localparam [28:0]
    Y_BASE=29'h06000000,
    CB_BASE=29'h0600A8C0,
    CR_BASE=29'h0600D2F0,
    BANK_OFF=29'h00010000;
localparam integer MAX_MB=1350;
localparam integer MAX_BLOCKS=2048;
localparam integer MAX_BANK_BLOCKS=512;
localparam integer MAX_ROW_BLOCKS=270;

wire [14:0] horizontal_rounded =
    {1'b0,horizontal_size}+15'd15;
wire [14:0] vertical_rounded =
    {1'b0,vertical_size}+15'd15;
wire [5:0] mb_width = horizontal_rounded[9:4];
wire [5:0] mb_height = vertical_rounded[9:4];
wire geometry_ok =
    (horizontal_size!=0) &&
    (vertical_size!=0) &&
    (horizontal_size<=14'd720) &&
    (vertical_size<=14'd480) &&
    (mb_width!=0) && (mb_width<=6'd45) &&
    (mb_height!=0) && (mb_height<=6'd30);

wire [11:0] padded_luma_width = {6'd0,mb_width} << 4;
wire [11:0] padded_luma_height = {6'd0,mb_height} << 4;
wire [11:0] padded_chroma_width = {6'd0,mb_width} << 3;
wire [11:0] padded_chroma_height = {6'd0,mb_height} << 3;

function automatic [28:0] r90;
    input [11:0] r;
    reg [28:0] x;
    begin
        x={17'd0,r};
        r90=(x<<6)+(x<<4)+(x<<3)+(x<<1);
    end
endfunction

function automatic [28:0] r45;
    input [11:0] r;
    reg [28:0] x;
    begin
        x={17'd0,r};
        r45=(x<<5)+(x<<3)+(x<<2)+x;
    end
endfunction

function automatic [28:0] pixel_addr;
    input [28:0] off;
    input [2:0] b;
    input [11:0] x;
    input [11:0] y;
    begin
        if(b<4)
            pixel_addr=Y_BASE+off+r90(y)+{20'd0,x[11:3]};
        else
            pixel_addr=(b==4?CB_BASE:CR_BASE)+
                       off+r45(y)+{20'd0,x[11:3]};
    end
endfunction

function automatic [7:0] bat;
    input [63:0] w;
    input [2:0] n;
    begin
        case(n)
        0:bat=w[7:0];
        1:bat=w[15:8];
        2:bat=w[23:16];
        3:bat=w[31:24];
        4:bat=w[39:32];
        5:bat=w[47:40];
        6:bat=w[55:48];
        default:bat=w[63:56];
        endcase
    end
endfunction

function automatic [7:0] clip;
    input [7:0] p;
    input signed [15:0] f;
    reg signed [16:0] s;
    begin
        s=$signed({9'd0,p})+{f[15],f};
        if(s<0) clip=0;
        else if(s>255) clip=255;
        else clip=s[7:0];
    end
endfunction

function automatic signed [12:0] chroma_half_vector;
    input signed [12:0] v;
    reg signed [13:0] a;
    begin
        if(v<0) begin
            a=-$signed(v);
            chroma_half_vector=-(a>>>1);
        end else chroma_half_vector=$signed(v)>>>1;
    end
endfunction

function automatic [7:0] round_prediction;
    input [10:0] sum;
    input hx;
    input hy;
    begin
        if(hx&&hy) round_prediction=(sum+11'd2)>>2;
        else if(hx||hy) round_prediction=(sum+11'd1)>>1;
        else round_prediction=sum[7:0];
    end
endfunction

// kate - Commit 166: no reset loop on this array. Synchronous read plus ordered
// write/read phases allow Quartus to infer block RAM instead of 1350x16 flops.
// Entry 695: field prediction carries two vectors and their field selects,
// so one macroblock's motion word becomes
// {field, fsel0, fsel1, intra, slot0 x/y, slot1 x/y}.  Frame prediction
// leaves both slots equal.
(* ramstyle = "M10K" *) reg [55:0] motion_mem [0:MAX_MB-1];
reg [10:0] motion_count;
reg [55:0] motion_word;
// Entry 695: the second field vector arrives as its own sideband record.
// Entry 695: the ordinary record's slot 0 is retained so the field record
// behind it can amend the entry without reading block RAM back.
reg signed [12:0] p_last_mvx,p_last_mvy;
reg p_last_intra;
wire mb_field=motion_word[55];
wire mb_fsel0=motion_word[54];
wire mb_fsel1=motion_word[53];
wire mb_intra=motion_word[52];
wire signed [12:0] mb_mvx=$signed(motion_word[51:39]);
wire signed [12:0] mb_mvy=$signed(motion_word[38:26]);
wire signed [12:0] mb_mvx1=$signed(motion_word[25:13]);
wire signed [12:0] mb_mvy1=$signed(motion_word[12:0]);

(* ramstyle = "M10K" *) reg [14:0] desc_mem [0:1023];
reg [14:0] desc_word;
reg [10:0] bank_desc_count [0:1];
reg [14:0] bank_last_desc_word [0:1];
reg [10:0] bank_motion_base [0:1];
reg [10:0] bank_motion_end [0:1];
reg [5:0] bank_row [0:1];
reg [1:0] bank_ready;
reg capture_bank, execute_bank;
wire [10:0] capture_desc_count=bank_desc_count[capture_bank];
wire [14:0] capture_last_desc_word=bank_last_desc_word[capture_bank];
wire [10:0] capture_motion_base=bank_motion_base[capture_bank];
wire [5:0] capture_row=bank_row[capture_bank];
wire execute_ready=bank_ready[execute_bank];
// Preserve the established internal proof name used by focused regressions;
// it now means that the oldest execution bank contains a complete row.
wire metadata_done=execute_ready;
reg [8:0] current_desc_slot;
reg desc_active;
reg wide_desc_pending;
reg [10:0] wide_desc_mb;
reg [5:0] sample_expected;
reg [8:0] exec_desc_slot;
reg [10:0] exec_desc_count_latched;
reg [10:0] exec_motion_end;
reg row_final_latched;

reg pending, started;
reg [1:0] reference_bank_latched;
reg req, waitresp, lookup_wait;
reg [10:0] mbi;
reg [5:0] col, mrow;
reg [2:0] blk;
reg [23:0] timeout;
reg emit, wait_store, pixel_setup, motion_load;
reg residual_load, residual_load_wait;
reg [5:0] ei;
reg [1:0] tap_index;
reg [10:0] pred_sum;
reg [7:0] out_reg;
reg emit_advanced, emit_first_sample;
reg [11:0] emit_x, emit_y;
reg emit_block_start, emit_block_complete;
reg [28:0] next_prelaunch_addr;
reg next_prelaunch_valid;
reg block_fetch_start;
reg [2:0] block_base_byte,block_base_byte1;
wire fast_pixel_advance, slow_pixel_advance, precompute_after_advance;
wire block_lookup_request;
wire [3:0] block_lookup_row;
wire block_lookup_phase;
wire block_lookup_column;
wire block_lookup_ready,block_lookup_valid;
wire [63:0] block_lookup_data;
wire block_fetch_active,block_fetch_complete,block_fetch_error;
wire [28:0] block_fetch_addr;
wire block_fetch_rd;
wire [6:0] block_fetch_issued,block_fetch_returned;
wire [2:0] block_fetch_outstanding;

wire [28:0] roff=(reference_bank_latched==2'd1)?BANK_OFF:
                 (reference_bank_latched==2'd2)?29'h00040000:29'd0;
wire [2:0] er=ei[5:3], el=ei[2:0];

// Entry 695: field prediction carries one vector per destination field.  The
// destination parity is the block row's low bit for luma and chroma alike,
// because the macroblock origin and the block origin are both even.  Chroma
// takes the same truncation toward zero that frame prediction already uses,
// which is what h262common's field model applies.
wire signed [12:0] slot0_mv_x=(blk<4)?mb_mvx :chroma_half_vector(mb_mvx);
wire signed [12:0] slot0_mv_y=(blk<4)?mb_mvy :chroma_half_vector(mb_mvy);
wire signed [12:0] slot1_mv_x=(blk<4)?mb_mvx1:chroma_half_vector(mb_mvx1);
wire signed [12:0] slot1_mv_y=(blk<4)?mb_mvy1:chroma_half_vector(mb_mvy1);
wire dest_slot=mb_field?er[0]:1'b0;
wire slot_fsel=dest_slot?mb_fsel1:mb_fsel0;

wire signed [12:0] exec_mvx=dest_slot?slot1_mv_x:slot0_mv_x;
wire signed [12:0] exec_mvy=dest_slot?slot1_mv_y:slot0_mv_y;
wire signed [12:0] exec_int_x=$signed(exec_mvx)>>>1;
wire signed [12:0] exec_int_y=$signed(exec_mvy)>>>1;
wire half_x=exec_mvx[0];
wire half_y=exec_mvy[0];

// Per-phase block origins.  Phase d serves destination field d for the whole
// block, so its rectangle is four field rows tall.
wire [11:0] block_dest_x0=(blk<4)?(({6'd0,col}<<4)+{8'd0,blk[0],3'd0})
                                 :({6'd0,col}<<3);
wire [11:0] block_dest_y0=(blk<4)?(({6'd0,mrow}<<4)+{8'd0,blk[1],3'd0})
                                 :({6'd0,mrow}<<3);
wire signed [13:0] block_field_row0=$signed({2'b00,block_dest_y0[11:1]});
wire signed [13:0] slot0_int_x=$signed({slot0_mv_x[12],slot0_mv_x})>>>1;
wire signed [13:0] slot0_int_y=$signed({slot0_mv_y[12],slot0_mv_y})>>>1;
wire signed [13:0] slot1_int_x=$signed({slot1_mv_x[12],slot1_mv_x})>>>1;
wire signed [13:0] slot1_int_y=$signed({slot1_mv_y[12],slot1_mv_y})>>>1;
wire slot0_half_x=slot0_mv_x[0],slot0_half_y=slot0_mv_y[0];
wire slot1_half_x=slot1_mv_x[0],slot1_half_y=slot1_mv_y[0];
wire signed [13:0] phase0_base_x=$signed({2'b00,block_dest_x0})+slot0_int_x;
wire signed [13:0] phase1_base_x=$signed({2'b00,block_dest_x0})+slot1_int_x;
// A field row maps back to a frame line through the selected field's parity.
wire signed [13:0] phase0_base_y=
    ((block_field_row0+slot0_int_y)<<<1)+$signed({13'd0,mb_fsel0});
wire signed [13:0] phase1_base_y=
    ((block_field_row0+slot1_int_y)<<<1)+$signed({13'd0,mb_fsel1});

wire [11:0] luma_x=({6'd0,col}<<4)+{8'd0,blk[0],el};
wire [11:0] luma_y=({6'd0,mrow}<<4)+{8'd0,blk[1],er};
wire [11:0] chroma_x=({6'd0,col}<<3)+{9'd0,el};
wire [11:0] chroma_y=({6'd0,mrow}<<3)+{9'd0,er};
wire [11:0] dest_x=(blk<4)?luma_x:chroma_x;
wire [11:0] dest_y=(blk<4)?luma_y:chroma_y;
wire signed [13:0] src_base_x=
    $signed({1'b0,dest_x})+$signed(exec_int_x);
// Field prediction indexes the reference in field lines: the destination's own
// field row plus the vector, mapped back to a frame line through the selected
// field's parity.  Frame prediction is unchanged.
wire signed [13:0] dest_field_row=$signed({2'b00,dest_y[11:1]});
wire signed [13:0] src_base_y=
    mb_field?
        (((dest_field_row+$signed({exec_int_y[12],exec_int_y}))<<<1)+
         $signed({13'd0,slot_fsel})):
        ($signed({1'b0,dest_y})+$signed(exec_int_y));
wire [11:0] plane_width =
    (blk<4)?padded_luma_width:padded_chroma_width;
wire [11:0] plane_height =
    (blk<4)?padded_luma_height:padded_chroma_height;
wire signed [13:0] src_last_x=
    src_base_x+(half_x?14'sd1:14'sd0);
wire signed [13:0] src_last_y=
    src_base_y+(half_y?(mb_field?14'sd2:14'sd1):14'sd0);
wire signed [13:0] plane_width_s=
    $signed({2'b00,plane_width});
wire signed [13:0] plane_height_s=
    $signed({2'b00,plane_height});
wire source_bounds_ok=
    (src_base_x>=0)&&(src_base_y>=0)&&
    (src_last_x<plane_width_s)&&(src_last_y<plane_height_s);
wire signed [13:0] block_src_last_x=src_base_x+14'sd7+
    (half_x?14'sd1:14'sd0);
wire signed [13:0] block_src_last_y=src_base_y+14'sd7+
    (half_y?14'sd1:14'sd0);
// Both phases are fetched, so both must be in range.  A phase spans four field
// rows, which is six frame lines, plus two more for a vertical half sample.
wire phase0_bounds_ok=
    (phase0_base_x>=0)&&(phase0_base_y>=0)&&
    ((phase0_base_x+14'sd7+(slot0_half_x?14'sd1:14'sd0))<plane_width_s)&&
    ((phase0_base_y+14'sd6+(slot0_half_y?14'sd2:14'sd0))<plane_height_s);
wire phase1_bounds_ok=
    (phase1_base_x>=0)&&(phase1_base_y>=0)&&
    ((phase1_base_x+14'sd7+(slot1_half_x?14'sd1:14'sd0))<plane_width_s)&&
    ((phase1_base_y+14'sd6+(slot1_half_y?14'sd2:14'sd0))<plane_height_s);
wire block_source_bounds_ok=
    mb_field?(phase0_bounds_ok&&phase1_bounds_ok)
            :((src_base_x>=0)&&(src_base_y>=0)&&
              (block_src_last_x<plane_width_s)&&
              (block_src_last_y<plane_height_s));
wire [3:0] block_word_span=
    {1'b0,src_base_x[2:0]}+4'd7+{3'd0,half_x};
wire [3:0] phase0_word_span=
    {1'b0,phase0_base_x[2:0]}+4'd7+{3'd0,slot0_half_x};
wire [3:0] phase1_word_span=
    {1'b0,phase1_base_x[2:0]}+4'd7+{3'd0,slot1_half_x};
wire [28:0] phase0_addr=pixel_addr(
    roff,blk,phase0_base_x[11:0],phase0_base_y[11:0]);
wire [28:0] phase1_addr=pixel_addr(
    roff,blk,phase1_base_x[11:0],phase1_base_y[11:0]);
wire [28:0] block_phase0_base_addr=pixel_addr(
    roff,blk,src_base_x[11:0],src_base_y[11:0]);
wire [7:0] block_row_words=(blk<4)?8'd90:8'd45;

mpeg2_h262_prediction_block_fetcher block_fetcher(
    .clk(clk),.reset(reset),.start(block_fetch_start),
    // Entry 695: field prediction fetches one rectangle per destination field.
    .phase_count(mb_field?3'd2:3'd1),
    .phase0_base_addr(mb_field?phase0_addr:block_phase0_base_addr),
    .phase1_base_addr(mb_field?phase1_addr:29'd0),
    .phase2_base_addr(29'd0),.phase3_base_addr(29'd0),
    .phase0_two_words(mb_field?phase0_word_span[3]:block_word_span[3]),
    .phase1_two_words(mb_field?phase1_word_span[3]:1'b0),
    .phase2_two_words(1'b0),.phase3_two_words(1'b0),
    .phase0_rows(mb_field?(4'd4+{3'd0,slot0_half_y}):(4'd8+{3'd0,half_y})),
    .phase1_rows(mb_field?(4'd4+{3'd0,slot1_half_y}):4'd1),
    .phase2_rows(4'd1),.phase3_rows(4'd1),
    // A doubled stride makes each fetched row step one field line, which is
    // also what lets the vertical half sample interpolate between field lines.
    .row_words(mb_field?{block_row_words[6:0],1'b0}:block_row_words),
    .memory_busy(ddram_busy),
    .memory_dout(ddram_dout),.memory_dout_ready(ddram_dout_ready),
    .memory_addr(block_fetch_addr),.memory_rd(block_fetch_rd),
    .lookup_request(block_lookup_request),
    .lookup_phase({1'b0,block_lookup_phase}),
    .lookup_row(block_lookup_row),.lookup_column(block_lookup_column),
    .lookup_ready(block_lookup_ready),.lookup_valid(block_lookup_valid),
    .lookup_data(block_lookup_data),.active(block_fetch_active),
    .complete(block_fetch_complete),.error(block_fetch_error),
    .issued_count(block_fetch_issued),.returned_count(block_fetch_returned),
    .outstanding_count(block_fetch_outstanding));

// Entry 239: form and register the first-tap word address for the following
// pixel before the current cache response arrives. This keeps the four-way
// cache match out of the engine's output path while permitting back-to-back
// registered lookup responses.
wire [5:0] next_pixel_ei=
    ei+(precompute_after_advance?2'd2:2'd1);
wire next_pixel_exists=
    precompute_after_advance?(ei<6'd62):(ei!=6'd63);
wire [2:0] next_pixel_er=next_pixel_ei[5:3];
wire [2:0] next_pixel_el=next_pixel_ei[2:0];
wire [11:0] next_pixel_luma_x=
    ({6'd0,col}<<4)+{8'd0,blk[0],next_pixel_el};
wire [11:0] next_pixel_luma_y=
    ({6'd0,mrow}<<4)+{8'd0,blk[1],next_pixel_er};
wire [11:0] next_pixel_chroma_x=
    ({6'd0,col}<<3)+{9'd0,next_pixel_el};
wire [11:0] next_pixel_chroma_y=
    ({6'd0,mrow}<<3)+{9'd0,next_pixel_er};
wire [11:0] next_pixel_dest_x=
    (blk<4)?next_pixel_luma_x:next_pixel_chroma_x;
wire [11:0] next_pixel_dest_y=
    (blk<4)?next_pixel_luma_y:next_pixel_chroma_y;
// The following pixel may belong to the other destination field, so it takes
// its own slot's vector rather than the current pixel's.
wire next_pixel_dest_slot=mb_field?next_pixel_er[0]:1'b0;
wire signed [12:0] next_pixel_mv_x=
    next_pixel_dest_slot?slot1_mv_x:slot0_mv_x;
wire signed [12:0] next_pixel_mv_y=
    next_pixel_dest_slot?slot1_mv_y:slot0_mv_y;
wire signed [12:0] next_pixel_int_x=$signed(next_pixel_mv_x)>>>1;
wire signed [12:0] next_pixel_int_y=$signed(next_pixel_mv_y)>>>1;
wire next_pixel_half_x=next_pixel_mv_x[0];
wire next_pixel_half_y=next_pixel_mv_y[0];
wire next_pixel_fsel=next_pixel_dest_slot?mb_fsel1:mb_fsel0;
wire signed [13:0] next_pixel_dest_field_row=
    $signed({2'b00,next_pixel_dest_y[11:1]});
wire signed [13:0] next_pixel_src_base_x=
    $signed({1'b0,next_pixel_dest_x})+$signed(next_pixel_int_x);
wire signed [13:0] next_pixel_src_base_y=
    mb_field?
        (((next_pixel_dest_field_row+
           $signed({next_pixel_int_y[12],next_pixel_int_y}))<<<1)+
         $signed({13'd0,next_pixel_fsel})):
        ($signed({1'b0,next_pixel_dest_y})+$signed(next_pixel_int_y));
wire signed [13:0] next_pixel_src_last_x=
    next_pixel_src_base_x+(next_pixel_half_x?14'sd1:14'sd0);
wire signed [13:0] next_pixel_src_last_y=
    next_pixel_src_base_y+
    (next_pixel_half_y?(mb_field?14'sd2:14'sd1):14'sd0);
wire next_pixel_source_bounds_ok=
    (next_pixel_src_base_x>=0)&&(next_pixel_src_base_y>=0)&&
    (next_pixel_src_last_x<plane_width_s)&&
    (next_pixel_src_last_y<plane_height_s);
wire [28:0] computed_next_prelaunch_addr=pixel_addr(
    roff,blk,next_pixel_src_base_x[11:0],next_pixel_src_base_y[11:0]);

wire tap_dx=
    (half_x&&half_y)?tap_index[0]:
    (half_x?tap_index[0]:1'b0);
wire tap_dy=
    (half_x&&half_y)?tap_index[1]:
    (half_y?tap_index[0]:1'b0);
wire tap_last=
    (half_x&&half_y)?(tap_index==2'd3):
    ((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire signed [13:0] src_x_tap_signed=
    src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=
    src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire [1:0] next_tap_index=tap_index+1'b1;
wire next_tap_dx=
    (half_x&&half_y)?next_tap_index[0]:
    (half_x?next_tap_index[0]:1'b0);
wire next_tap_dy=
    (half_x&&half_y)?next_tap_index[1]:
    (half_y?next_tap_index[0]:1'b0);
wire signed [13:0] next_src_x_tap_signed=
    src_base_x+$signed({13'd0,next_tap_dx});
wire signed [13:0] next_src_y_tap_signed=
    src_base_y+$signed({13'd0,next_tap_dy});
wire [11:0] next_src_x_tap=next_src_x_tap_signed[11:0];
wire [11:0] next_src_y_tap=next_src_y_tap_signed[11:0];

wire descriptor_position_hit=
    (exec_desc_slot<exec_desc_count_latched)&&
    (desc_word[14:4]==mbi)&&
    (desc_word[2:0]==blk);
wire residual_hit=descriptor_position_hit&&
    (desc_word[3]==mb_intra);
// Commit 231: while the current pixel performs its reference lookup, use the
// synchronous residual-store port to fetch the next sample in the block.
// Block boundaries retain the staged residual_load path so descriptor changes
// still receive the full RAM read latency.
wire residual_read_ahead=
    (pixel_setup||lookup_wait||req||waitresp||emit)&&(ei!=6'd63);
wire [5:0] residual_read_index=
    (fast_pixel_advance&&(ei<6'd62)) ? (ei+2'd2) :
    residual_read_ahead ? (ei+1'b1) : ei;
wire [15:0] residual_mem_index=
    {execute_bank,exec_desc_slot,6'b000000}+{10'd0,residual_read_index};
reg signed [15:0] residual_pel_q;

assign residual_store_write=
    capture_enable&&residual_valid&&desc_active&&
    (residual_index==sample_expected);
assign residual_store_write_address=
    {capture_bank,current_desc_slot,6'b000000}+{10'd0,residual_index};
assign residual_store_write_data=residual_value;
assign residual_store_read_address=residual_mem_index;

// Entry 347: the physical bank has 512 slots, while the supported 45-MB row
// can author at most 270 ordered descriptors. Keep both invariants explicit in
// simulation so a future geometry change cannot silently wrap either bank.
`ifndef SYNTHESIS
initial begin
    if(MAX_ROW_BLOCKS>MAX_BANK_BLOCKS)
        $fatal(1,"P supported row exceeds its physical residual bank");
end
always @(posedge clk) begin
    if(!reset) begin
        if(capture_desc_count>MAX_ROW_BLOCKS)
            $fatal(1,"P residual row exceeded 270 descriptors");
        if(residual_store_write&&(current_desc_slot>=MAX_ROW_BLOCKS))
            $fatal(1,"P residual write used an unsupported descriptor slot");
        if(residual_store_write&&
           (residual_store_write_address[15]!=capture_bank))
            $fatal(1,"P residual write crossed its capture bank");
        if(active&&
           (residual_store_read_address[15]!=execute_bank))
            $fatal(1,"P residual read crossed its execution bank");
        if(residual_store_write&&active&&(capture_bank==execute_bank))
            $fatal(1,"P residual capture overlapped its execution bank");
    end
end
`endif

wire [7:0] current_tap_sample=bat(ddram_dout,src_x_tap[2:0]);
wire [10:0] pred_sum_with_current=
    pred_sum+{3'd0,current_tap_sample};
wire [7:0] predicted_current=
    round_prediction(pred_sum_with_current,half_x,half_y);
wire [7:0] reconstructed_current=
    clip(predicted_current,residual_pel_q);
wire [7:0] lookup_tap_sample=
    bat(block_lookup_data,src_x_tap[2:0]);
wire [10:0] lookup_pred_sum_with_current=
    pred_sum+{3'd0,lookup_tap_sample};
wire [7:0] lookup_predicted_current=
    round_prediction(lookup_pred_sum_with_current,half_x,half_y);
wire [7:0] lookup_reconstructed_current=
    clip(lookup_predicted_current,residual_pel_q);
wire lookup_advance=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&!tap_last;
wire lookup_pixel_complete=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&tap_last;
wire predicted_pixel_complete=lookup_pixel_complete;
wire next_pixel_lookup=predicted_pixel_complete&&(ei!=6'd63)&&
    next_prelaunch_valid;
assign fast_pixel_advance=predicted_pixel_complete&&
    ((ei==6'd63)||next_prelaunch_valid);
assign slow_pixel_advance=emit&&!emit_advanced&&(ei!=6'd63);
assign precompute_after_advance=
    (fast_pixel_advance&&(ei!=6'd63))||slow_pixel_advance;
wire pixel_completed=
    (pixel_setup&&mb_intra&&residual_hit)||predicted_pixel_complete;
wire prediction_lookup=
    (pixel_setup&&!mb_intra&&source_bounds_ok)||lookup_advance||
    next_pixel_lookup;
wire block_lookup_retry=lookup_wait&&block_lookup_ready&&
    !block_lookup_valid;
wire block_lookup_idle_request=lookup_wait&&!block_fetch_start&&
    !block_lookup_ready;
wire [5:0] block_request_ei=next_pixel_lookup?(ei+1'b1):ei;
wire [1:0] block_request_tap=lookup_advance?
    (tap_index+1'b1):next_pixel_lookup?2'd0:tap_index;
wire block_request_tap_dx=
    (half_x&&half_y)?block_request_tap[0]:
    (half_x?block_request_tap[0]:1'b0);
wire block_request_tap_dy=
    (half_x&&half_y)?block_request_tap[1]:
    (half_y?block_request_tap[0]:1'b0);
wire [2:0] block_request_base_byte=
    (mb_field&&block_request_ei[3])?block_base_byte1:block_base_byte;
wire [4:0] block_request_byte=
    {2'd0,block_request_base_byte}+{2'd0,block_request_ei[2:0]}+
    {4'd0,block_request_tap_dx};
// Entry 695: a field phase holds this block's four rows of one parity, so the
// row within the phase is the block row halved.
assign block_lookup_row=
    mb_field?({2'd0,block_request_ei[5:4]}+{3'd0,block_request_tap_dy})
            :({1'b0,block_request_ei[5:3]}+block_request_tap_dy);
// The phase to read is the destination parity of the pixel being requested.
assign block_lookup_phase=mb_field?block_request_ei[3]:1'b0;
assign block_lookup_column=block_request_byte[3];
assign block_lookup_request=
    (prediction_lookup&&!(pixel_setup&&(ei==0)))||
    block_lookup_retry||block_lookup_idle_request;

assign ddram_burstcnt=block_fetch_rd?8'd1:0;
assign ddram_addr=block_fetch_rd?block_fetch_addr:29'd0;
assign ddram_rd=block_fetch_rd;
assign ddram_cacheable=block_fetch_rd;
assign ddram_lookup_request=1'b0;
assign ddram_lookup_consume=1'b0;

assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&emit_block_start;
assign store_block_complete=emit&&emit_block_complete;
assign store_pixel_x=emit_x;
assign store_pixel_y=emit_y;

wire ready_res=execute_ready;
wire descriptor_order_error=
    (capture_desc_count!=0)&&
    ({wide_desc_mb,residual_value[2:0]} <=
     {capture_last_desc_word[14:4],capture_last_desc_word[2:0]});

// One macroblock's committed motion word: both slots equal, no field.  This is
// what every P path writes, and its meaning is unchanged from before entry 695.
wire [55:0] motion_commit_word=
    {3'b000,(residual_index==6'h3b),
     motion_vector_x,motion_vector_y,
     motion_vector_x,motion_vector_y};
// Entry 695: the field record's amendment of the entry just written.  Only the
// wide parser emits 6'h35, so only there does the record value carry a
// payload; on every other path this value is the residual channel and its bits
// mean something else, which is why the ordinary record must not be read for
// field information.
wire [55:0] motion_field_amend_word=
    {1'b1,residual_value[0],residual_value[1],p_last_intra,
     p_last_mvx,p_last_mvy,
     motion_vector_x,motion_vector_y};

wire new_picture_metadata=
    capture_enable&&residual_valid&&!desc_active&&
    ((residual_index==6'h3e)||(residual_index==6'h3b))&&
    persisted_seen&&!active;
wire unused_shift_map=&{1'b0,shift_right_map};

// Commit 202: synchronous descriptor and sparse-sample lookups allow both
// 2048-block stores to infer M10K RAM. Commit 231 keeps residual_load for the
// first sample of a block, then captures each prefetched in-block sample when
// the preceding pixel advances. The two-sample address during a fast retire
// supplies the synchronous RAM pipeline for the following back-to-back pixel.
always @(posedge clk) begin
    if(reset) begin
        residual_pel_q<=0;
        desc_word<=0;
    end else begin
        if(residual_load_wait||
           (fast_pixel_advance&&(ei!=6'd63))||
           slow_pixel_advance)
            residual_pel_q<=residual_hit ? residual_store_read_data : 16'sd0;
        desc_word<=desc_mem[{execute_bank,exec_desc_slot}];
    end
end

always @(posedge clk) begin
    if(reset) begin
        motion_count<=0;
        motion_word<=0;
        p_last_mvx<=0;p_last_mvy<=0;p_last_intra<=0;
        bank_desc_count[0]<=0;
        bank_desc_count[1]<=0;
        bank_last_desc_word[0]<=0;
        bank_last_desc_word[1]<=0;
        bank_motion_base[0]<=0;
        bank_motion_base[1]<=0;
        bank_motion_end[0]<=0;
        bank_motion_end[1]<=0;
        bank_row[0]<=0;
        bank_row[1]<=0;
        bank_ready<=0;
        capture_bank<=0;
        execute_bank<=0;
        current_desc_slot<=0;
        desc_active<=0;
        wide_desc_pending<=0;
        wide_desc_mb<=0;
        sample_expected<=0;
        exec_desc_slot<=0;
        exec_desc_count_latched<=0;
        exec_motion_end<=0;
        pending<=0;
        started<=0;
        active<=0;
        reference_bank_latched<=0;
        req<=0;
        waitresp<=0;
        lookup_wait<=0;
        mbi<=0;
        col<=0;
        mrow<=0;
        blk<=0;
        timeout<=0;
        emit<=0;
        wait_store<=0;
        pixel_setup<=0;
        motion_load<=0;
        residual_load<=0;
        residual_load_wait<=0;
        ei<=0;
        tap_index<=0;
        pred_sum<=0;
        out_reg<=0;
        emit_advanced<=0;
        emit_first_sample<=0;
        emit_x<=0;
        emit_y<=0;
        emit_block_start<=0;
        emit_block_complete<=0;
        next_prelaunch_addr<=0;
        next_prelaunch_valid<=0;
        block_fetch_start<=0;
        block_base_byte<=0;
        read_seen<=0;
        sample_value<=0;
        sample_nonzero<=0;
        half_sample_seen<=0;
        reconstructed_seen<=0;
        reconstructed_value<=0;
        persisted_seen<=0;
        row_persisted<=0;
        persisted_value<=0;
        progress_stage<=0;
        error<=0;
        error_source<=0;
        row_final_latched<=0;
    end else begin
        row_persisted<=0;
        block_fetch_start<=0;
        if(new_picture_metadata) begin
            persisted_seen<=0;
            progress_stage<=4'd1;
            motion_count<=11'd1;
            motion_mem[0]<=motion_commit_word;
            p_last_mvx<=motion_vector_x;
            p_last_mvy<=motion_vector_y;
            p_last_intra<=(residual_index==6'h3b);
            bank_desc_count[0]<=0;
            bank_desc_count[1]<=0;
            bank_last_desc_word[0]<=0;
            bank_last_desc_word[1]<=0;
            bank_motion_base[0]<=0;
            bank_motion_base[1]<=0;
            bank_motion_end[0]<=0;
            bank_motion_end[1]<=0;
            bank_row[0]<=0;
            bank_row[1]<=0;
            bank_ready<=0;
            capture_bank<=0;
            execute_bank<=0;
            current_desc_slot<=0;
            desc_active<=0;
            wide_desc_pending<=0;
            sample_expected<=0;
            exec_desc_slot<=0;
            exec_desc_count_latched<=0;
            exec_motion_end<=0;
            pending<=request;
            started<=0;
            req<=0;
            waitresp<=0;
            lookup_wait<=0;
            emit<=0;
            emit_advanced<=0;
            next_prelaunch_valid<=0;
            block_fetch_start<=0;
            block_base_byte<=0;
            block_base_byte1<=0;
            wait_store<=0;
            pixel_setup<=0;
            motion_load<=0;
            residual_load<=0;
            residual_load_wait<=0;
            mbi<=0;
            col<=0;
            mrow<=0;
            row_final_latched<=0;
            blk<=0;
            ei<=0;
            half_sample_seen<=0;
        end else if(capture_enable&&residual_valid) begin
            if(progress_stage==4'd0)
                progress_stage<=4'd1;
            if(desc_active) begin
                if(residual_index!=sample_expected) begin
                    error<=1;
                    if(!error) error_source<=5'd1;
                end else begin
                    if(residual_index==6'd63) begin
                        desc_active<=0;
                    end else begin
                        sample_expected<=sample_expected+1'b1;
                    end
                end
            end else if(residual_index==6'h35) begin
                // Entry 695: field prediction's second record amends the entry
                // the ordinary record just wrote, adding slot 1 and both field
                // selects.  Capture and execution are disjoint phases, so that
                // entry is still writable here.
                if(bank_ready[capture_bank]||(motion_count==0)) begin
                    error<=1;
                    if(!error) error_source<=5'd19;
                end else begin
                    motion_mem[motion_count-1'b1]<=motion_field_amend_word;
                end
            end else if((residual_index==6'h3e)||
                        (residual_index==6'h3b)) begin
                if(bank_ready[capture_bank] ||
                   (capture_desc_count!=0) ||
                   wide_desc_pending ||
                   (motion_count>=MAX_MB)) begin
                    error<=1;
                    if(!error) error_source<=5'd2;
                end else begin
                    motion_mem[motion_count]<=motion_commit_word;
                    motion_count<=motion_count+1'b1;
                    p_last_mvx<=motion_vector_x;
                    p_last_mvy<=motion_vector_y;
                    p_last_intra<=(residual_index==6'h3b);
                end
            end else if(residual_index==6'h3c) begin
                if(bank_ready[capture_bank] ||
                   wide_desc_pending ||
                   (capture_desc_count>=MAX_ROW_BLOCKS) ||
                   (residual_value<0) ||
                   (residual_value>16'sd1349)) begin
                    error<=1;
                    if(!error) error_source<=5'd3;
                end else begin
                    wide_desc_mb<=residual_value[10:0];
                    wide_desc_pending<=1;
                end
            end else if(residual_index==6'h3d) begin
                if(!wide_desc_pending ||
                   bank_ready[capture_bank] ||
                   (capture_desc_count>=MAX_ROW_BLOCKS) ||
                   (residual_value[15:4]!=0) ||
                   (residual_value[2:0]>=6)) begin
                    error<=1;
                    if(!error) error_source<=5'd4;
                end else if(descriptor_order_error) begin
                    error<=1;
                    if(!error) error_source<=5'd5;
                end else begin
                    current_desc_slot<=capture_desc_count[8:0];
                    desc_mem[{capture_bank,capture_desc_count[8:0]}]<=
                        {wide_desc_mb,residual_value[3:0]};
                    bank_last_desc_word[capture_bank]<=
                        {wide_desc_mb,residual_value[3:0]};
                    bank_desc_count[capture_bank]<=capture_desc_count+1'b1;
                    desc_active<=1;
                    wide_desc_pending<=0;
                    sample_expected<=0;
                end
            end else if((residual_index==6'h3f) &&
                        (residual_value[15:12]==4'hB)) begin
                if((motion_count!=11'd48) ||
                   bank_ready[capture_bank] ||
                   wide_desc_pending ||
                   (capture_desc_count>=MAX_ROW_BLOCKS) ||
                   (residual_value[8:3]>=48) ||
                   (residual_value[2:0]>=6) ||
                   ((capture_desc_count!=0)&&
                    ({5'd0,residual_value[8:3],
                      residual_value[2:0]} <=
                     {capture_last_desc_word[14:4],
                      capture_last_desc_word[2:0]}))) begin
                    error<=1;
                    if(!error) error_source<=5'd6;
                end else begin
                    current_desc_slot<=capture_desc_count[8:0];
                    desc_mem[{capture_bank,capture_desc_count[8:0]}]<=
                        {{5'd0,residual_value[8:3]},1'b0,
                         residual_value[2:0]};
                    bank_last_desc_word[capture_bank]<=
                        {{5'd0,residual_value[8:3]},1'b0,
                         residual_value[2:0]};
                    bank_desc_count[capture_bank]<=capture_desc_count+1'b1;
                    desc_active<=1;
                    sample_expected<=0;
                end
            end else if((residual_index==6'h3f) &&
                        ((residual_value==16'shA2FE) ||
                         (residual_value==16'shA2FF))) begin
                if((motion_count==capture_motion_base) ||
                   bank_ready[capture_bank] ||
                   wide_desc_pending ||
                   (motion_count!=(capture_motion_base+{5'd0,mb_width})) ||
                   ((residual_value==16'shA2FF) &&
                    (capture_row+1'b1!=mb_height)) ||
                   ((residual_value==16'shA2FE) &&
                    (capture_row+1'b1>=mb_height))) begin
                    error<=1;
                    if(!error) error_source<=5'd7;
                end else begin
                    bank_ready[capture_bank]<=1'b1;
                    bank_motion_end[capture_bank]<=motion_count;
                    bank_motion_base[~capture_bank]<=motion_count;
                    bank_row[~capture_bank]<=capture_row+1'b1;
                    capture_bank<=~capture_bank;
                end
            end else begin
                error<=1;
                if(!error) error_source<=5'd8;
            end
        end

        if(request&&!started) pending<=1;
        if(pending&&!started&&ready_res) begin
            pending<=0;
            started<=1;
            active<=1;
            reference_bank_latched<=reference_bank;
            timeout<=24'hffffff;
            mbi<=bank_motion_base[execute_bank];
            col<=0;
            mrow<=bank_row[execute_bank];
            blk<=0;
            ei<=0;
            exec_desc_slot<=0;
            exec_desc_count_latched<=bank_desc_count[execute_bank];
            exec_motion_end<=bank_motion_end[execute_bank];
            row_final_latched<=
                (bank_row[execute_bank]+1'b1==mb_height);
            motion_load<=1;
            progress_stage<=4'd2;
            pixel_setup<=0;
            if(!geometry_ok ||
               !reference_valid ||
               (reference_bank==destination_bank) ||
               (motion_count==0)) begin
                error<=1;
                if(!error) error_source<=5'd9;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
                motion_load<=0;
            end
        end

        if(started&&!persisted_seen&&timeout!=0) begin
            timeout<=timeout-1'b1;
            if(timeout==1) begin
                error<=1;
                if(!error) error_source<=5'd10;
            end
        end

        if(motion_load) begin
            motion_load<=0;
            if(mbi>=exec_motion_end || mbi>=motion_count || mbi>=MAX_MB) begin
                error<=1;
                if(!error) error_source<=5'd11;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else begin
                motion_word<=motion_mem[mbi];
                residual_load<=1;
            end
        end

        if(residual_load) begin
            residual_load<=0;
            residual_load_wait<=1;
        end

        if(residual_load_wait) begin
            residual_load_wait<=0;
            pred_sum<=0;
            tap_index<=0;
            pixel_setup<=1;
        end

        if(pixel_setup||precompute_after_advance) begin
            next_prelaunch_addr<=computed_next_prelaunch_addr;
            next_prelaunch_valid<=
                next_pixel_exists&&!mb_intra&&next_pixel_source_bounds_ok;
        end

        if(pixel_setup) begin
            pixel_setup<=0;
            if(mb_intra&&!residual_hit) begin
                error<=1;
                if(!error) error_source<=5'd17;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else if(mb_intra) begin
                out_reg<=clip(8'd0,residual_pel_q);
                emit<=1;
            end else if(!source_bounds_ok||
                        ((ei==0)&&!block_source_bounds_ok)) begin
                error<=1;
                if(!error) error_source<=5'd12;
                active<=0;
                persisted_seen<=1;
                timeout<=0;
            end else begin
                if(ei==0)begin
                    block_fetch_start<=1;
                    block_base_byte<=mb_field?phase0_base_x[2:0]
                                             :src_base_x[2:0];
                    block_base_byte1<=phase1_base_x[2:0];
                end
                if(half_x||half_y) half_sample_seen<=1;
                lookup_wait<=1;
            end
        end

        if(lookup_wait&&block_lookup_ready) begin
            if(block_lookup_valid) begin
                if(progress_stage<4'd3)
                    progress_stage<=4'd3;
                if(tap_last) begin
                    lookup_wait<=0;
                    out_reg<=lookup_reconstructed_current;
                    emit<=1;
                    if((mbi==0)&&(blk==0)&&(ei==0)) begin
                        read_seen<=1;
                        sample_value<=lookup_predicted_current;
                        sample_nonzero<=|lookup_predicted_current;
                    end
                end else begin
                    pred_sum<=lookup_pred_sum_with_current;
                    tap_index<=tap_index+1'b1;
                end
            end
        end

        if(block_fetch_error)begin
            error<=1;
            if(!error)error_source<=5'd18;
            active<=0;
            persisted_seen<=1;
            timeout<=0;
        end

        if(emit) begin
            if(progress_stage<4'd4)
                progress_stage<=4'd4;
            if(emit_first_sample) begin
                reconstructed_value<=out_reg;
                persisted_value<=out_reg;
            end
            emit<=0;
            if(!emit_advanced&&(ei==6'd63)) begin
                wait_store<=1;
            end else if(!emit_advanced) begin
                ei<=ei+1'b1;
                pred_sum<=0;
                tap_index<=0;
                if(next_pixel_lookup) begin
                    lookup_wait<=1;
                end else begin
                    pixel_setup<=1;
                end
            end
        end

        if(pixel_completed) begin
            emit<=1;
            emit_advanced<=fast_pixel_advance;
            emit_first_sample<=(mbi==0)&&(blk==0)&&(ei==0);
            emit_x<=
                (blk<4)?luma_x:
                (blk==4)?{2'b01,chroma_x[9:0]}:
                         {2'b10,chroma_x[9:0]};
            emit_y<=(blk<4)?luma_y:chroma_y;
            emit_block_start<=(ei==0);
            emit_block_complete<=(ei==6'd63);
        end

        if(fast_pixel_advance) begin
            if(ei==6'd63) begin
                wait_store<=1;
            end else begin
                ei<=ei+1'b1;
                pred_sum<=0;
                tap_index<=0;
                lookup_wait<=1;
            end
        end

        if(wait_store&&store_block_stored) begin
            // Entry 233: block_stored is the writer's all-eight-rows-accepted
            // barrier. Prediction reads the opposite reference bank, so a
            // destination readback adds no dependency or reconstructed data.
            if(progress_stage<4'd5)
                progress_stage<=4'd5;
            wait_store<=0;
            if(residual_hit)
                exec_desc_slot<=exec_desc_slot+1'b1;
            if(blk==3'd5) begin
                if(col+1'b1>=mb_width) begin
                    if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=exec_desc_count_latched)
                    begin
                        error<=1;
                        if(!error) error_source<=5'd15;
                    end
                    if(mbi+1'b1!=exec_motion_end)
                    begin
                        error<=1;
                        if(!error) error_source<=5'd16;
                    end
                    row_persisted<=1;
                    active<=0;
                    timeout<=0;
                    if(row_final_latched) begin
                        persisted_seen<=1;
                        progress_stage<=4'd7;
                        reconstructed_seen<=1;
                    end else begin
                        started<=0;
                        pending<=0;
                        bank_ready[execute_bank]<=1'b0;
                        bank_desc_count[execute_bank]<=0;
                        bank_last_desc_word[execute_bank]<=0;
                        execute_bank<=~execute_bank;
                        exec_desc_slot<=0;
                        exec_desc_count_latched<=0;
                        exec_motion_end<=0;
                        row_final_latched<=0;
                    end
                end else begin
                    mbi<=mbi+1'b1;
                    col<=col+1'b1;
                    blk<=0;
                    ei<=0;
                    motion_load<=1;
                end
            end else begin
                blk<=blk+1'b1;
                ei<=0;
                residual_load<=1;
            end
        end
    end
end

endmodule
