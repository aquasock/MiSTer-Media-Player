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

wire signed [9:0] block_forward_int_x=$signed(exec_fmvx)>>>1;
wire signed [9:0] block_forward_int_y=$signed(exec_fmvy)>>>1;
wire signed [9:0] block_backward_int_x=$signed(exec_bmvx)>>>1;
wire signed [9:0] block_backward_int_y=$signed(exec_bmvy)>>>1;
wire signed [13:0] block_forward_src_x=
    $signed({1'b0,dest_x})+$signed(block_forward_int_x);
wire signed [13:0] block_forward_src_y=
    $signed({1'b0,dest_y})+$signed(block_forward_int_y);
wire signed [13:0] block_backward_src_x=
    $signed({1'b0,dest_x})+$signed(block_backward_int_x);
wire signed [13:0] block_backward_src_y=
    $signed({1'b0,dest_y})+$signed(block_backward_int_y);
wire block_phase0_backward=(exec_direction==2'd2);
wire signed [13:0] block_phase0_src_x=block_phase0_backward?
    block_backward_src_x:block_forward_src_x;
wire signed [13:0] block_phase0_src_y=block_phase0_backward?
    block_backward_src_y:block_forward_src_y;
wire block_phase0_half_x=block_phase0_backward?
    exec_bmvx[0]:exec_fmvx[0];
wire block_phase0_half_y=block_phase0_backward?
    exec_bmvy[0]:exec_fmvy[0];
wire signed [13:0] block_phase0_last_x=block_phase0_src_x+14'sd7+
    (block_phase0_half_x?14'sd1:14'sd0);
wire signed [13:0] block_phase0_last_y=block_phase0_src_y+14'sd7+
    (block_field_dct?14'sd7:14'sd0)+
    (block_phase0_half_y?14'sd1:14'sd0);
wire signed [13:0] block_phase1_last_x=block_backward_src_x+14'sd7+
    (exec_bmvx[0]?14'sd1:14'sd0);
wire signed [13:0] block_phase1_last_y=block_backward_src_y+14'sd7+
    (block_field_dct?14'sd7:14'sd0)+
    (exec_bmvy[0]?14'sd1:14'sd0);
wire block_phase0_bounds_ok=(block_phase0_src_x>=0)&&
    (block_phase0_src_y>=0)&&
    (block_phase0_last_x<$signed({2'b00,plane_width}))&&
    (block_phase0_last_y<$signed({2'b00,plane_height}));
wire block_phase1_bounds_ok=(block_backward_src_x>=0)&&
    (block_backward_src_y>=0)&&
    (block_phase1_last_x<$signed({2'b00,plane_width}))&&
    (block_phase1_last_y<$signed({2'b00,plane_height}));
wire [3:0] block_phase0_word_span=
    {1'b0,block_phase0_src_x[2:0]}+4'd7+
    {3'd0,block_phase0_half_x};
wire [3:0] block_phase1_word_span=
    {1'b0,block_backward_src_x[2:0]}+4'd7+
    {3'd0,exec_bmvx[0]};
wire [28:0] block_phase0_base_addr=pixel_addr(
    block_phase0_backward?future_off:past_off,blk,
    block_phase0_src_x[11:0],block_phase0_src_y[11:0]);
wire [28:0] block_phase1_base_addr=pixel_addr(
    future_off,blk,block_backward_src_x[11:0],
    block_backward_src_y[11:0]);
wire [7:0] block_row_words=(blk<4)?8'd90:8'd45;

// Entry 695: a field phase is addressed from the block's first line rather
// than from the pixel being reconstructed, because the phase holds the block's
// four rows of one destination parity.
wire [11:0] block_dest_x0=(blk<4)?(({6'd0,col}<<4)+{8'd0,blk[0],3'b000})
                                 :({6'd0,col}<<3);
wire [11:0] block_dest_y0=(blk<4)?(({6'd0,mrow}<<4)+{8'd0,blk[1],3'b000})
                                 :({6'd0,mrow}<<3);
wire signed [13:0] block_field_row0=$signed({2'b00,block_dest_y0[11:1]});
// Each evaluation computes one direction's two destination-parity footprints.
// Entry 701 sequences this selector before address/span/bounds formation rather
// than keeping four complete footprint cones live in parallel.
function automatic signed [9:0] field_mv_x;
    input backward; input slot;
    begin
        field_mv_x=backward?(slot?exec_bmvx1:exec_bmvx)
                           :(slot?exec_fmvx1:exec_fmvx);
    end
endfunction
function automatic signed [9:0] field_mv_y;
    input backward; input slot;
    begin
        field_mv_y=backward?(slot?exec_bmvy1:exec_bmvy)
                           :(slot?exec_fmvy1:exec_fmvy);
    end
endfunction
function automatic field_select;
    input backward; input slot;
    begin
        field_select=backward?(slot?exec_bsel1:exec_bsel0)
                             :(slot?exec_fsel1:exec_fsel0);
    end
endfunction
wire field_pair_backward=(exec_direction==2'd2)||field_fetch_backward;
wire signed [9:0] field_pair0_mvx=field_mv_x(field_pair_backward,1'b0);
wire signed [9:0] field_pair0_mvy=field_mv_y(field_pair_backward,1'b0);
wire signed [9:0] field_pair1_mvx=field_mv_x(field_pair_backward,1'b1);
wire signed [9:0] field_pair1_mvy=field_mv_y(field_pair_backward,1'b1);
wire field_pair0_sel=field_select(field_pair_backward,1'b0);
wire field_pair1_sel=field_select(field_pair_backward,1'b1);
// A field row maps back to a frame line through the selected field's parity.
`define H262_B_FIELD_BASE_X(MVX) \
    ($signed({2'b00,block_dest_x0})+($signed(MVX)>>>1))
`define H262_B_FIELD_BASE_Y(MVY,SEL) \
    (((block_field_row0+($signed(MVY)>>>1))<<<1)+$signed({13'd0,SEL}))
wire signed [13:0] field_pair0_base_x=`H262_B_FIELD_BASE_X(field_pair0_mvx);
wire signed [13:0] field_pair1_base_x=`H262_B_FIELD_BASE_X(field_pair1_mvx);
wire signed [13:0] field_pair0_base_y=
    `H262_B_FIELD_BASE_Y(field_pair0_mvy,field_pair0_sel);
wire signed [13:0] field_pair1_base_y=
    `H262_B_FIELD_BASE_Y(field_pair1_mvy,field_pair1_sel);
wire [28:0] field_pair0_addr=pixel_addr(
    field_pair_backward?future_off:past_off,blk,
    field_pair0_base_x[11:0],field_pair0_base_y[11:0]);
wire [28:0] field_pair1_addr=pixel_addr(
    field_pair_backward?future_off:past_off,blk,
    field_pair1_base_x[11:0],field_pair1_base_y[11:0]);
wire [3:0] field_pair0_span=
    {1'b0,field_pair0_base_x[2:0]}+4'd7+{3'd0,field_pair0_mvx[0]};
wire [3:0] field_pair1_span=
    {1'b0,field_pair1_base_x[2:0]}+4'd7+{3'd0,field_pair1_mvx[0]};
// A phase spans four field rows, which is six frame lines, plus two more for a
// vertical half sample.
`define H262_B_FIELD_BOUNDS(BX,BY,MVX,MVY) \
    ((BX>=0)&&(BY>=0)&& \
     ((BX+14'sd7+(MVX[0]?14'sd1:14'sd0))<$signed({2'b00,plane_width}))&& \
     ((BY+14'sd6+(MVY[0]?14'sd2:14'sd0))<$signed({2'b00,plane_height})))
wire field_pair0_bounds_ok=`H262_B_FIELD_BOUNDS(
    field_pair0_base_x,field_pair0_base_y,field_pair0_mvx,field_pair0_mvy);
wire field_pair1_bounds_ok=`H262_B_FIELD_BOUNDS(
    field_pair1_base_x,field_pair1_base_y,field_pair1_mvx,field_pair1_mvy);
// The byte within a fetched word comes from the phase's own horizontal vector,
// so the preserved extraction registers must follow the slot as well as the
// direction.  ei[3] is the destination parity of the pixel being set up.
wire [5:0] field_next_ei=ei+6'd1;
// The extraction path does not add the element offset the way the lookup path
// does, so these are the pixel's own source byte, not the block origin's.
wire [2:0] field_forward_base_byte=
    (ei[3]?block_phase1_base_byte:block_phase0_base_byte)+ei[2:0];
wire [2:0] field_backward_base_byte=
    (ei[3]?block_phase3_base_byte:block_phase2_base_byte)+ei[2:0];
wire [2:0] field_next_base_byte=
    (field_next_ei[3]?block_phase1_base_byte:block_phase0_base_byte)+
    field_next_ei[2:0];
wire field_pair_bounds_ok=field_pair0_bounds_ok&&field_pair1_bounds_ok;
wire block_all_bounds_ok=block_field_dct?field_dct_fetch_bounds_ok:
    exec_field?field_pair_bounds_ok:
    (block_phase0_bounds_ok&&
     ((exec_direction!=2'd3)||block_phase1_bounds_ok));

// A frame-predicted field-DCT block walks one destination field at a time.
// Each prediction direction therefore owns one physical fetcher; phase zero
// holds the source parity at integer Y and phase one, when needed, holds the
// adjacent frame line for vertical half-sample interpolation.  This reuses the
// same two fetchers already required by bidirectional field prediction.
wire field_dct_fetch_backward=
    (exec_direction==2'd2)||field_fetch_backward;
wire field_dct_slot=blk[1];
wire signed [9:0] field_dct_fetch_mvx=exec_field?
    field_mv_x(field_dct_fetch_backward,field_dct_slot):
    (field_dct_fetch_backward?exec_bmvx:exec_fmvx);
wire signed [9:0] field_dct_fetch_mvy=exec_field?
    field_mv_y(field_dct_fetch_backward,field_dct_slot):
    (field_dct_fetch_backward?exec_bmvy:exec_fmvy);
wire field_dct_fetch_sel=exec_field?
    field_select(field_dct_fetch_backward,field_dct_slot):1'b0;
wire [11:0] field_dct_dest_y0=({6'd0,mrow}<<4)+{11'd0,blk[1]};
wire signed [13:0] field_dct_dest_field_row=
    $signed({2'b00,field_dct_dest_y0[11:1]});
wire signed [13:0] field_dct_fetch_x=
    $signed({2'b00,block_dest_x0})+
    ($signed(field_dct_fetch_mvx)>>>1);
wire signed [13:0] field_dct_fetch_y=
    exec_field?
        (((field_dct_dest_field_row+
           ($signed(field_dct_fetch_mvy)>>>1))<<<1)+
         $signed({13'd0,field_dct_fetch_sel})):
        ($signed({2'b00,field_dct_dest_y0})+
         ($signed(field_dct_fetch_mvy)>>>1));
wire field_dct_fetch_half_x=
    field_dct_fetch_mvx[0];
wire field_dct_fetch_half_y=
    field_dct_fetch_mvy[0];
wire [28:0] field_dct_phase0_addr=pixel_addr(
    field_dct_fetch_backward?future_off:past_off,blk,
    field_dct_fetch_x[11:0],field_dct_fetch_y[11:0]);
wire [28:0] field_dct_phase1_addr=pixel_addr(
    field_dct_fetch_backward?future_off:past_off,blk,
    field_dct_fetch_x[11:0],field_dct_fetch_y[11:0]+12'd1);
wire [3:0] field_dct_word_span=
    {1'b0,field_dct_fetch_x[2:0]}+4'd7+
    {3'd0,field_dct_fetch_half_x};
wire signed [13:0] field_dct_last_x=field_dct_fetch_x+14'sd7+
    (field_dct_fetch_half_x?14'sd1:14'sd0);
wire signed [13:0] field_dct_last_y=field_dct_fetch_y+14'sd14+
    (field_dct_fetch_half_y?(exec_field?14'sd2:14'sd1):14'sd0);
wire field_dct_fetch_bounds_ok=
    (field_dct_fetch_x>=0)&&(field_dct_fetch_y>=0)&&
    (field_dct_last_x<$signed({2'b00,plane_width}))&&
    (field_dct_last_y<$signed({2'b00,plane_height}));

// Entry 272: the successor footprint is derived from the already loaded
// macroblock motion record.  Only blk 0..4 use it; the blk-5 boundary keeps
// the synchronous next-macroblock motion load as the serialization point.
wire [2:0] successor_blk=blk+1'b1;
wire successor_luma=(successor_blk<4);
wire [11:0] successor_dest_x=successor_luma?
    (({6'd0,col}<<4)+{8'd0,successor_blk[0],3'b000}):
    ({6'd0,col}<<3);
wire [11:0] successor_dest_y=successor_luma?
    (({6'd0,mrow}<<4)+{8'd0,successor_blk[1],3'b000}):
    ({6'd0,mrow}<<3);
wire [11:0] successor_plane_width=successor_luma?
    padded_luma_width:padded_chroma_width;
wire [11:0] successor_plane_height=successor_luma?
    padded_luma_height:padded_chroma_height;
wire signed [9:0] successor_fmvx=successor_luma?
    mb_fmvx:chroma_half_vector(mb_fmvx);
wire signed [9:0] successor_fmvy=successor_luma?
    mb_fmvy:chroma_half_vector(mb_fmvy);
wire signed [9:0] successor_bmvx=successor_luma?
    mb_bmvx:chroma_half_vector(mb_bmvx);
wire signed [9:0] successor_bmvy=successor_luma?
    mb_bmvy:chroma_half_vector(mb_bmvy);
wire successor_phase0_backward=(exec_direction==2'd2);
wire signed [9:0] successor_phase0_mvx=successor_phase0_backward?
    successor_bmvx:successor_fmvx;
wire signed [9:0] successor_phase0_mvy=successor_phase0_backward?
    successor_bmvy:successor_fmvy;
wire signed [13:0] successor_phase0_src_x=
    $signed({1'b0,successor_dest_x})+
    ($signed(successor_phase0_mvx)>>>1);
wire signed [13:0] successor_phase0_src_y=
    $signed({1'b0,successor_dest_y})+
    ($signed(successor_phase0_mvy)>>>1);
wire signed [13:0] successor_phase1_src_x=
    $signed({1'b0,successor_dest_x})+
    ($signed(successor_bmvx)>>>1);
wire signed [13:0] successor_phase1_src_y=
    $signed({1'b0,successor_dest_y})+
    ($signed(successor_bmvy)>>>1);
wire signed [13:0] successor_phase0_last_x=successor_phase0_src_x+
    14'sd7+(successor_phase0_mvx[0]?14'sd1:14'sd0);
wire signed [13:0] successor_phase0_last_y=successor_phase0_src_y+
    14'sd7+(successor_phase0_mvy[0]?14'sd1:14'sd0);
wire signed [13:0] successor_phase1_last_x=successor_phase1_src_x+
    14'sd7+(successor_bmvx[0]?14'sd1:14'sd0);
wire signed [13:0] successor_phase1_last_y=successor_phase1_src_y+
    14'sd7+(successor_bmvy[0]?14'sd1:14'sd0);
wire successor_phase0_bounds_ok=(successor_phase0_src_x>=0)&&
    (successor_phase0_src_y>=0)&&
    (successor_phase0_last_x<$signed({2'b00,successor_plane_width}))&&
    (successor_phase0_last_y<$signed({2'b00,successor_plane_height}));
wire successor_phase1_bounds_ok=(successor_phase1_src_x>=0)&&
    (successor_phase1_src_y>=0)&&
    (successor_phase1_last_x<$signed({2'b00,successor_plane_width}))&&
    (successor_phase1_last_y<$signed({2'b00,successor_plane_height}));
wire successor_all_bounds_ok=successor_phase0_bounds_ok&&
    ((exec_direction!=2'd3)||successor_phase1_bounds_ok);
wire [3:0] successor_phase0_word_span=
    {1'b0,successor_phase0_src_x[2:0]}+4'd7+
    {3'd0,successor_phase0_mvx[0]};
wire [3:0] successor_phase1_word_span=
    {1'b0,successor_phase1_src_x[2:0]}+4'd7+
    {3'd0,successor_bmvx[0]};
wire [28:0] successor_phase0_base_addr=pixel_addr(
    successor_phase0_backward?future_off:past_off,successor_blk,
    successor_phase0_src_x[11:0],successor_phase0_src_y[11:0]);
wire [28:0] successor_phase1_base_addr=pixel_addr(
    future_off,successor_blk,successor_phase1_src_x[11:0],
    successor_phase1_src_y[11:0]);
wire [7:0] successor_row_words=successor_luma?8'd90:8'd45;

wire [28:0] current_launch_phase0_base_addr=
    block_field_dct?field_dct_phase0_addr:
    exec_field?field_pair0_addr:block_phase0_base_addr;
wire [28:0] current_launch_phase1_base_addr=
    block_field_dct?field_dct_phase1_addr:
    exec_field?field_pair1_addr:block_phase1_base_addr;
wire current_launch_phase0_two_words=
    block_field_dct?field_dct_word_span[3]:
    exec_field?field_pair0_span[3]:block_phase0_word_span[3];
wire current_launch_phase1_two_words=
    block_field_dct?field_dct_word_span[3]:
    exec_field?field_pair1_span[3]:block_phase1_word_span[3];
wire current_launch_phase0_half_y=
    block_field_dct?field_dct_fetch_half_y:
    exec_field?field_pair0_mvy[0]:block_phase0_half_y;
wire current_launch_phase1_half_y=
    block_field_dct?field_dct_fetch_half_y:
    exec_field?field_pair1_mvy[0]:exec_bmvy[0];
// A field macroblock never prefetches its successor, so these need no mux.
wire [3:0] current_launch_phase0_rows=block_field_dct?
    (4'd8+(exec_field?{3'd0,field_dct_fetch_half_y}:4'd0)):
    exec_field?(4'd4+{3'd0,current_launch_phase0_half_y})
                                :(4'd8+{3'd0,current_launch_phase0_half_y});
wire [3:0] current_launch_phase1_rows=block_field_dct?4'd8:
    exec_field?(4'd4+{3'd0,current_launch_phase1_half_y})
                                :(4'd8+{3'd0,current_launch_phase1_half_y});
wire [2:0] current_launch_phase_count=block_field_dct?
    (exec_field?3'd1:(field_dct_fetch_half_y?3'd2:3'd1)):
    exec_field?3'd2:
    ((exec_direction==2'd3)?3'd2:3'd1);
wire [7:0] current_launch_row_words=(exec_field||block_field_dct)?
    {block_row_words[6:0],1'b0}:block_row_words;
// Do not let a broadcast lookup sample a fetcher's previous retained word on
// the same edge that start clears its validity map for a new block.
wire block_lookup_request0=block_lookup_request&&
    !block_lookup_target_bank&&
    !(block_fetch_start&&!block_fetch_start_bank);
wire block_lookup_request1=block_lookup_request&&
    block_lookup_target_bank&&
    !(block_fetch_start&&block_fetch_start_bank);

mpeg2_h262_prediction_block_fetcher #(
    .PHASES(2),.PIPELINED_LOOKUP(2)
) block_fetcher(
    .clk(clk),.reset(reset),
    .start(block_fetch_start&&!block_fetch_start_bank),
    .phase_count(fetch_launch_phase_count),
    .phase0_base_addr(fetch_launch_phase0_base_addr),
    .phase1_base_addr(fetch_launch_phase1_base_addr),
    .phase2_base_addr(29'd0),
    .phase3_base_addr(29'd0),
    .phase0_two_words(fetch_launch_phase0_two_words),
    .phase1_two_words(fetch_launch_phase1_two_words),
    .phase2_two_words(1'b0),
    .phase3_two_words(1'b0),
    .phase0_rows(fetch_launch_phase0_rows),
    .phase1_rows(fetch_launch_phase1_rows),
    .phase2_rows(4'd0),
    .phase3_rows(4'd0),
    // A doubled stride makes each fetched row step one field line.
    .row_words(fetch_launch_row_words),
    .memory_busy(ddram_busy),
    .memory_dout(ddram_dout),
    .memory_dout_ready(ddram_dout_ready&&block_fetch_active0),
    .memory_addr(block_fetch_addr0),.memory_rd(block_fetch_rd0),
    .lookup_request(block_lookup_request0),
    .lookup_phase(block_lookup_phase),.lookup_row(block_lookup_row),
    .lookup_column(block_lookup_column),
    .lookup_ready(block_lookup_ready0),.lookup_valid(block_lookup_valid0),
    .lookup_data(block_lookup_data0),.active(block_fetch_active0),
    .lookup_next_row_valid(block_lookup_next_row_valid0),
    .lookup_next_row_data(block_lookup_next_row_data0),
    .complete(block_fetch_complete0),.error(block_fetch_error0),
    .issued_count(block_fetch_issued0),
    .returned_count(block_fetch_returned0),
    .outstanding_count(block_fetch_outstanding0));

mpeg2_h262_prediction_block_fetcher #(
    .PHASES(2),.PIPELINED_LOOKUP(2)
) block_fetcher1(
    .clk(clk),.reset(reset),
    .start(block_fetch_start&&block_fetch_start_bank),
    .phase_count(fetch_launch_phase_count),
    .phase0_base_addr(fetch_launch_phase0_base_addr),
    .phase1_base_addr(fetch_launch_phase1_base_addr),
    .phase2_base_addr(29'd0),
    .phase3_base_addr(29'd0),
    .phase0_two_words(fetch_launch_phase0_two_words),
    .phase1_two_words(fetch_launch_phase1_two_words),
    .phase2_two_words(1'b0),
    .phase3_two_words(1'b0),
    .phase0_rows(fetch_launch_phase0_rows),
    .phase1_rows(fetch_launch_phase1_rows),
    .phase2_rows(4'd0),
    .phase3_rows(4'd0),
    // A doubled stride makes each fetched row step one field line.
    .row_words(fetch_launch_row_words),
    .memory_busy(ddram_busy),
    .memory_dout(ddram_dout),
    .memory_dout_ready(ddram_dout_ready&&block_fetch_active1),
    .memory_addr(block_fetch_addr1),.memory_rd(block_fetch_rd1),
    .lookup_request(block_lookup_request1),
    .lookup_phase(block_lookup_phase),.lookup_row(block_lookup_row),
    .lookup_column(block_lookup_column),
    .lookup_ready(block_lookup_ready1),.lookup_valid(block_lookup_valid1),
    .lookup_data(block_lookup_data1),.active(block_fetch_active1),
    .lookup_next_row_valid(block_lookup_next_row_valid1),
    .lookup_next_row_data(block_lookup_next_row_data1),
    .complete(block_fetch_complete1),.error(block_fetch_error1),
    .issued_count(block_fetch_issued1),
    .returned_count(block_fetch_returned1),
    .outstanding_count(block_fetch_outstanding1));

wire block_lookup_bank=block_consumer_bank^
    ((exec_field||block_field_dct)&&
     (exec_direction==2'd3)&&pred_direction);
assign block_lookup_ready=block_lookup_bank?
    block_lookup_ready1:block_lookup_ready0;
wire block_lookup_selected_valid=block_lookup_bank?
    block_lookup_valid1:block_lookup_valid0;
wire field_backward_lookup_current=
    (exec_field||block_field_dct)&&
    (exec_direction==2'd3)&&pred_direction;
assign block_lookup_valid=block_lookup_selected_valid&&
    (!field_backward_lookup_current||
     (field_second_fetch_started&&!block_fetch_start));
assign block_lookup_data=block_lookup_bank?
    block_lookup_data1:block_lookup_data0;
wire block_lookup_selected_next_row_valid=block_lookup_bank?
    block_lookup_next_row_valid1:block_lookup_next_row_valid0;
assign block_lookup_next_row_valid=block_lookup_selected_next_row_valid&&
    (!field_backward_lookup_current||
     (field_second_fetch_started&&!block_fetch_start));
assign block_lookup_next_row_data=block_lookup_bank?
    block_lookup_next_row_data1:block_lookup_next_row_data0;
assign block_fetch_active=block_fetch_active0||block_fetch_active1;
assign block_fetch_complete=block_consumer_bank?
    block_fetch_complete1:block_fetch_complete0;
assign block_fetch_error=block_fetch_error0||block_fetch_error1||
    (block_fetch_rd0&&block_fetch_rd1);
assign block_fetch_addr=block_fetch_rd1?block_fetch_addr1:block_fetch_addr0;
assign block_fetch_rd=block_fetch_rd0||block_fetch_rd1;
assign block_fetch_issued=block_fetch_active1?block_fetch_issued1:
    block_fetch_active0?block_fetch_issued0:
    block_consumer_bank?block_fetch_issued1:block_fetch_issued0;
assign block_fetch_returned=block_fetch_active1?block_fetch_returned1:
    block_fetch_active0?block_fetch_returned0:
    block_consumer_bank?block_fetch_returned1:block_fetch_returned0;
assign block_fetch_outstanding=block_fetch_active1?block_fetch_outstanding1:
    block_fetch_active0?block_fetch_outstanding0:
    block_consumer_bank?block_fetch_outstanding1:block_fetch_outstanding0;

// Entry 239: complete backward/current and following-pixel word addresses stay
// registered ahead of the cache. A fast final response advances these
// registers concurrently with the writer output.
wire [5:0] precompute_current_ei=
    precompute_after_advance?(ei+1'b1):ei;
wire [5:0] precompute_next_ei=precompute_current_ei+1'b1;
wire [2:0] precompute_current_er=precompute_current_ei[5:3];
wire [2:0] precompute_current_el=precompute_current_ei[2:0];
wire [2:0] precompute_next_er=precompute_next_ei[5:3];
wire [2:0] precompute_next_el=precompute_next_ei[2:0];

wire signed [9:0] backward_int_x=$signed(exec_bmvx)>>>1;
wire signed [9:0] backward_int_y=$signed(exec_bmvy)>>>1;
wire next_use_backward=(exec_direction==2'd2);
wire signed [9:0] next_exec_mvx=
    next_use_backward?exec_bmvx:exec_fmvx;
wire signed [9:0] next_exec_mvy=
    next_use_backward?exec_bmvy:exec_fmvy;
wire signed [9:0] next_int_x=$signed(next_exec_mvx)>>>1;
wire signed [9:0] next_int_y=$signed(next_exec_mvy)>>>1;

wire [11:0] precompute_current_luma_x=
    ({6'd0,col}<<4)+{8'd0,blk[0],precompute_current_el};
wire [11:0] precompute_current_luma_y=
    ({6'd0,mrow}<<4)+
    (block_field_dct?
        ({8'd0,precompute_current_er,1'b0}+{11'd0,blk[1]}):
        {8'd0,blk[1],precompute_current_er});
wire [11:0] precompute_current_chroma_x=
    ({6'd0,col}<<3)+{9'd0,precompute_current_el};
wire [11:0] precompute_current_chroma_y=
    ({6'd0,mrow}<<3)+{9'd0,precompute_current_er};
wire [11:0] precompute_current_dest_x=
    (blk<4)?precompute_current_luma_x:precompute_current_chroma_x;
wire [11:0] precompute_current_dest_y=
    (blk<4)?precompute_current_luma_y:precompute_current_chroma_y;
wire signed [13:0] precompute_bidir_src_x=
    $signed({1'b0,precompute_current_dest_x})+$signed(backward_int_x);
wire signed [13:0] precompute_bidir_src_y=
    $signed({1'b0,precompute_current_dest_y})+$signed(backward_int_y);
wire signed [13:0] precompute_bidir_last_x=
    precompute_bidir_src_x+(exec_bmvx[0]?14'sd1:14'sd0);
wire signed [13:0] precompute_bidir_last_y=
    precompute_bidir_src_y+(exec_bmvy[0]?14'sd1:14'sd0);
wire precompute_bidir_bounds_ok=
    (precompute_bidir_src_x>=0)&&(precompute_bidir_src_y>=0)&&
    (precompute_bidir_last_x<$signed({2'b00,plane_width}))&&
    (precompute_bidir_last_y<$signed({2'b00,plane_height}));
wire [28:0] precompute_bidir_addr=pixel_addr(
    future_off,blk,precompute_bidir_src_x[11:0],
    precompute_bidir_src_y[11:0]);

wire [11:0] precompute_next_luma_x=
    ({6'd0,col}<<4)+{8'd0,blk[0],precompute_next_el};
wire [11:0] precompute_next_luma_y=
    ({6'd0,mrow}<<4)+
    (block_field_dct?
        ({8'd0,precompute_next_er,1'b0}+{11'd0,blk[1]}):
        {8'd0,blk[1],precompute_next_er});
wire [11:0] precompute_next_chroma_x=
    ({6'd0,col}<<3)+{9'd0,precompute_next_el};
wire [11:0] precompute_next_chroma_y=
    ({6'd0,mrow}<<3)+{9'd0,precompute_next_er};
wire [11:0] precompute_next_dest_x=
    (blk<4)?precompute_next_luma_x:precompute_next_chroma_x;
wire [11:0] precompute_next_dest_y=
    (blk<4)?precompute_next_luma_y:precompute_next_chroma_y;
wire signed [13:0] precompute_next_src_x=
    $signed({1'b0,precompute_next_dest_x})+$signed(next_int_x);
wire signed [13:0] precompute_next_src_y=
    $signed({1'b0,precompute_next_dest_y})+$signed(next_int_y);
wire signed [13:0] precompute_next_last_x=
    precompute_next_src_x+(next_exec_mvx[0]?14'sd1:14'sd0);
wire signed [13:0] precompute_next_last_y=
    precompute_next_src_y+(next_exec_mvy[0]?14'sd1:14'sd0);
wire precompute_next_bounds_ok=
    (precompute_current_ei!=6'd63)&&
    (precompute_next_src_x>=0)&&(precompute_next_src_y>=0)&&
    (precompute_next_last_x<$signed({2'b00,plane_width}))&&
    (precompute_next_last_y<$signed({2'b00,plane_height}));
wire [28:0] precompute_next_addr=pixel_addr(
    next_use_backward?future_off:past_off,blk,
    precompute_next_src_x[11:0],precompute_next_src_y[11:0]);

wire tap_dx=(half_x&&half_y)?tap_index[0]:(half_x?tap_index[0]:1'b0);
wire tap_dy=(half_x&&half_y)?tap_index[1]:(half_y?tap_index[0]:1'b0);
wire tap_last=(half_x&&half_y)?(tap_index==2'd3):((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire [1:0] next_tap_index=tap_index+1'b1;
wire next_tap_dx=(half_x&&half_y)?next_tap_index[0]:
    (half_x?next_tap_index[0]:1'b0);
wire next_tap_dy=(half_x&&half_y)?next_tap_index[1]:
    (half_y?next_tap_index[0]:1'b0);
wire next_tap_last=(half_x&&half_y)?(next_tap_index==2'd3):
    ((half_x||half_y)?(next_tap_index==2'd1):
     (next_tap_index==2'd0));
wire [3:0] phase_tap_byte_sum={1'b0,phase_base_byte}+tap_dx;
wire [3:0] next_phase_tap_byte_sum=
    {1'b0,phase_base_byte}+next_tap_dx;
// Entry 277: the footprint lookup already returns the same word column from
// the adjacent row.  When a 2-by-2 phase starts at tap zero and both horizontal
// samples stay in that column, all four registered bytes are available now.
wire lookup_quad=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&block_lookup_next_row_valid&&
    !block_field_dct&&
    (tap_index==2'd0)&&half_x&&half_y&&
    (phase_tap_byte_sum[3]==next_phase_tap_byte_sum[3]);
// Entry 273: a retained word may supply the following horizontal tap without
// a second lookup.  Row and word identity are explicit.
wire lookup_horizontal_pair=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&!lookup_quad&&
    !tap_last&&(tap_dy==next_tap_dy)&&
    (phase_tap_byte_sum[3]==next_phase_tap_byte_sum[3]);
// Entry 275: the separately registered adjacent-row response supplies the
// second tap of a pure vertical half-pel phase.  Four-tap interpolation and
// horizontal word crossings remain on the established path.
wire lookup_vertical_pair=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&block_lookup_next_row_valid&&!tap_last&&
    !block_field_dct&&
    !half_x&&half_y&&(next_tap_dy==(tap_dy+1'b1))&&
    (phase_tap_byte_sum[3]==next_phase_tap_byte_sum[3]);
wire lookup_pair=lookup_horizontal_pair||lookup_vertical_pair;
wire lookup_phase_complete=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&(tap_last||lookup_quad||
                         (lookup_pair&&next_tap_last));
wire prediction_phase_complete=lookup_phase_complete;
wire bidir_lookup_candidate=prediction_phase_complete&&
    (exec_direction==2'd3)&&!pred_direction;
wire predicted_pixel_complete=prediction_phase_complete&&
    !((exec_direction==2'd3)&&!pred_direction);
wire next_pixel_lookup_candidate=
    predicted_pixel_complete&&(ei!=6'd63);
wire bidir_early_lookup=
    bidir_lookup_candidate&&bidir_prelaunch_valid;
wire next_pixel_early_lookup=
    next_pixel_lookup_candidate&&next_prelaunch_valid;
wire early_lookup=bidir_early_lookup||next_pixel_early_lookup;
wire [28:0] early_lookup_addr=
    bidir_early_lookup?bidir_prelaunch_addr:next_prelaunch_addr;
wire early_half_x=
    bidir_early_lookup?exec_bmvx[0]:next_exec_mvx[0];
wire early_half_y=
    bidir_early_lookup?exec_bmvy[0]:next_exec_mvy[0];
// Entry 243: while a registered DDR miss response retires, present the
// following tap address to the cache request
// port. The cache captures it on that response edge; req remains asserted
// afterward until the unchanged one-outstanding downstream handshake accepts
// it. This removes the idle capture bubble without adding transaction depth.
wire miss_response_prelaunch=
    waitresp&&ddram_dout_ready&&!tap_last&&ddram_busy;
wire [2:0] miss_response_prelaunch_byte=miss_prelaunch_byte;
assign fast_pixel_advance=predicted_pixel_complete&&
    ((ei==6'd63)||next_prelaunch_valid);
assign slow_pixel_advance=emit&&!emit_advanced&&(ei!=6'd63);
assign precompute_after_advance=
    (fast_pixel_advance&&(ei!=6'd63))||slow_pixel_advance;
wire signed [13:0] src_x_tap_signed=src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire signed [13:0] next_src_x_tap_signed=
    src_base_x+$signed({13'd0,next_tap_dx});
wire signed [13:0] next_src_y_tap_signed=
    src_base_y+$signed({13'd0,next_tap_dy});
wire [11:0] next_src_x_tap=next_src_x_tap_signed[11:0];
wire [11:0] next_src_y_tap=next_src_y_tap_signed[11:0];
wire [28:0] selected_reference_off=phase_backward?future_off:past_off;
wire [28:0] computed_phase_base_addr=pixel_addr(
    selected_reference_off,blk,src_base_x[11:0],src_base_y[11:0]);

wire residual_hit=(exec_desc_slot<exec_desc_count_latched)&&
    (desc_word[13:3]==mbi)&&
    (desc_word[2:0]==blk);
wire pixel_completed=
    (pixel_setup&&(exec_direction==0)&&residual_hit)||
    predicted_pixel_complete;
// Commit 231: overlap the synchronous read of the next in-block residual with
// the current pixel's reference lookup. Block boundaries continue through the
// staged residual_load path so descriptor changes retain the full RAM latency.
wire residual_read_ahead=
    (pixel_setup||lookup_wait||req||waitresp||emit)&&(ei!=6'd63);
wire [5:0] residual_read_index=
    (fast_pixel_advance&&(ei<6'd62)) ? (ei+2'd2) :
    residual_read_ahead ? (ei+1'b1) : ei;
wire [15:0] residual_mem_index=
    {execute_bank,exec_desc_slot,6'b000000}+{10'd0,residual_read_index};
reg signed [15:0] residual_pel;
assign residual_store_write=capture_enable&&sideband_valid&&desc_active&&
    (sideband_index==sample_expected);
assign residual_store_write_address=
    {capture_bank,current_desc_slot,6'b000000}+{10'd0,sideband_index};
assign residual_store_write_data=sideband_value;
assign residual_store_read_address=residual_mem_index;

// Entry 347: preserve the distinct 512-slot physical-bank and 270-descriptor
// supported-row bounds, and prove all shared-store accesses retain their bank.
`ifndef SYNTHESIS
initial begin
    if(MAX_ROW_BLOCKS>MAX_BANK_BLOCKS)
        $fatal(1,"B supported row exceeds its physical residual bank");
end
always @(posedge clk) begin
    if(!reset) begin
        if(capture_desc_count>MAX_ROW_BLOCKS)
            $fatal(1,"B residual row exceeded 270 descriptors");
        if(residual_store_write&&(current_desc_slot>=MAX_ROW_BLOCKS))
            $fatal(1,"B residual write used an unsupported descriptor slot");
        if(residual_store_write&&
           (residual_store_write_address[15]!=capture_bank))
            $fatal(1,"B residual write crossed its capture bank");
        if(active&&
           (residual_store_read_address[15]!=execute_bank))
            $fatal(1,"B residual read crossed its execution bank");
        if(residual_store_write&&active&&(capture_bank==execute_bank))
            $fatal(1,"B residual capture overlapped its execution bank");
    end
end
`endif
// kate - Commit 182: byte select is the copy registered at request accept, not
// the live combinational address.  Same value, captured a cycle earlier.
wire [7:0] current_tap_sample=bat(ddram_dout,tap_byte_sel);
wire [10:0] pred_sum_with_current=pred_sum+{3'd0,current_tap_sample};
wire [7:0] selected_prediction=round_prediction(pred_sum_with_current,half_x,half_y);
wire [8:0] bidir_sum={1'b0,forward_prediction}+{1'b0,selected_prediction}+9'd1;
wire [7:0] bidir_prediction=bidir_sum[8:1];
wire [7:0] final_prediction=(exec_direction==2'd3)?bidir_prediction:selected_prediction;
wire [7:0] reconstructed_current=clip(final_prediction,residual_pel);
wire [7:0] reconstructed_intra=clip(8'd0,residual_pel);
wire [2:0] phase_tap_byte=phase_tap_byte_sum[2:0];
wire [7:0] lookup_tap_sample=bat(block_lookup_data,phase_tap_byte);
wire [2:0] lookup_next_tap_byte=next_phase_tap_byte_sum[2:0];
wire [7:0] lookup_next_tap_sample=
    lookup_vertical_pair?
        bat(block_lookup_next_row_data,lookup_next_tap_byte):
        bat(block_lookup_data,lookup_next_tap_byte);
wire [7:0] lookup_quad_bottom_left=
    bat(block_lookup_next_row_data,phase_tap_byte);
wire [7:0] lookup_quad_bottom_right=
    bat(block_lookup_next_row_data,lookup_next_tap_byte);
wire [10:0] lookup_pred_sum_with_current=
    pred_sum+{3'd0,lookup_tap_sample}+
    (lookup_quad?({3'd0,lookup_next_tap_sample}+
                  {3'd0,lookup_quad_bottom_left}+
                  {3'd0,lookup_quad_bottom_right}):
     lookup_pair?{3'd0,lookup_next_tap_sample}:11'd0);
wire [7:0] lookup_selected_prediction=
    round_prediction(lookup_pred_sum_with_current,half_x,half_y);
wire [8:0] lookup_bidir_sum=
    {1'b0,forward_prediction}+{1'b0,lookup_selected_prediction}+9'd1;
wire [7:0] lookup_bidir_prediction=lookup_bidir_sum[8:1];
wire [7:0] lookup_final_prediction=
    (exec_direction==2'd3)?lookup_bidir_prediction:lookup_selected_prediction;
wire [7:0] lookup_reconstructed_current=
    clip(lookup_final_prediction,residual_pel);
wire lookup_advance=lookup_wait&&block_lookup_ready&&
    block_lookup_valid&&!lookup_phase_complete;
wire [1:0] lookup_advance_tap_index=
    tap_index+(lookup_pair?2'd2:2'd1);
wire lookup_advance_tap_dx=(half_x&&half_y)?
    lookup_advance_tap_index[0]:
    (half_x?lookup_advance_tap_index[0]:1'b0);
wire lookup_advance_tap_dy=(half_x&&half_y)?
    lookup_advance_tap_index[1]:
    (half_y?lookup_advance_tap_index[0]:1'b0);
wire prediction_lookup=
    (pixel_setup&&(exec_direction!=0)&&phase_bounds_ok)||lookup_advance||
    bidir_lookup_candidate||next_pixel_lookup_candidate;
wire advance_tap_address=lookup_advance;
wire address_tap_dx=advance_tap_address?lookup_advance_tap_dx:tap_dx;
wire address_tap_dy=advance_tap_address?lookup_advance_tap_dy:tap_dy;
wire [3:0] address_tap_byte_sum=
    {1'b0,phase_base_byte}+address_tap_dx;
wire [28:0] normal_lookup_addr=phase_base_addr+
    (address_tap_dy?{22'd0,phase_row_words}:29'd0)+
    {28'd0,address_tap_byte_sum[3]};
wire [3:0] next_miss_tap_byte_sum=
    {1'b0,phase_base_byte}+next_tap_dx;
wire [28:0] next_miss_prelaunch_addr=phase_base_addr+
    (next_tap_dy?{22'd0,phase_row_words}:29'd0)+
    {28'd0,next_miss_tap_byte_sum[3]};

// Frame mode keeps forward/backward as phases zero/one in one fetcher.  Field
// mode keeps destination parity as phases zero/one and selects the physical
// forward/backward fetcher separately through block_lookup_bank.
wire block_lookup_direction=lookup_issue_direction;
assign block_lookup_target_bank=block_consumer_bank^
    ((exec_field||block_field_dct)&&
     (exec_direction==2'd3)&&block_lookup_direction);
assign block_lookup_phase=block_field_dct?
    {1'b0,(exec_field?1'b0:block_request_tap_dy)}:exec_field?
    {1'b0,block_request_ei[3]}:
    {1'b0,block_lookup_direction};
wire [5:0] block_request_ei=lookup_issue_ei;
wire [1:0] block_request_tap=lookup_issue_tap;
// The vector belongs to the direction being looked up and, under field
// prediction, to the slot matching the pixel's destination parity.
wire block_request_backward=
    (exec_direction==2'd2)||block_lookup_direction;
wire signed [9:0] block_request_mvx=block_field_dct?
    (exec_field?field_mv_x(block_request_backward,field_dct_slot):
                (block_request_backward?exec_bmvx:exec_fmvx)):exec_field?
    field_mv_x(block_request_backward,block_request_ei[3]):
    (block_request_backward?exec_bmvx:exec_fmvx);
wire signed [9:0] block_request_mvy=block_field_dct?
    (exec_field?field_mv_y(block_request_backward,field_dct_slot):
                (block_request_backward?exec_bmvy:exec_fmvy)):exec_field?
    field_mv_y(block_request_backward,block_request_ei[3]):
    (block_request_backward?exec_bmvy:exec_fmvy);
wire block_request_half_x=block_request_mvx[0];
wire block_request_half_y=block_request_mvy[0];
wire block_request_tap_dx=
    (block_request_half_x&&block_request_half_y)?block_request_tap[0]:
    (block_request_half_x?block_request_tap[0]:1'b0);
wire block_request_tap_dy=
    (block_request_half_x&&block_request_half_y)?block_request_tap[1]:
    (block_request_half_y?block_request_tap[0]:1'b0);
wire [2:0] block_request_base_byte=
    block_field_dct?
        ((block_request_backward&&(exec_direction==2'd3))?
            block_phase2_base_byte:block_phase0_base_byte):
    exec_field&&block_request_backward&&(exec_direction==2'd3)?
        (block_lookup_phase[0]?block_phase3_base_byte:block_phase2_base_byte):
    (block_lookup_phase==2'd0)?block_phase0_base_byte:block_phase1_base_byte;
wire [4:0] block_request_byte=
    {2'd0,block_request_base_byte}+{2'd0,block_request_ei[2:0]}+
    {4'd0,block_request_tap_dx};
assign block_lookup_row=block_field_dct?
    ({1'b0,block_request_ei[5:3]}+
     (exec_field?{3'd0,block_request_tap_dy}:4'd0)):exec_field?
    ({2'd0,block_request_ei[5:4]}+{3'd0,block_request_tap_dy}):
    ({1'b0,block_request_ei[5:3]}+block_request_tap_dy);
assign block_lookup_column=block_request_byte[3];

// Advance the issue cursor from geometry only.  Retained words are not
// streamed until the selected footprint is complete, so the response-side
// valid/next-row-valid decisions are guaranteed to take the same branch.
// Field-DCT addressing selects a footprint by block parity, while the
// established reconstruction sequencer selects interpolation taps by the
// destination pixel parity.  Keep those two roles distinct here as they are
// in the response-side phase_mvx/phase_mvy state.
wire lookup_issue_group_backward=
    (exec_direction==2'd2)||block_lookup_direction;
wire signed [9:0] lookup_issue_group_mvx=exec_field?
    field_mv_x(lookup_issue_group_backward,block_request_ei[3]):
    (lookup_issue_group_backward?exec_bmvx:exec_fmvx);
wire signed [9:0] lookup_issue_group_mvy=exec_field?
    field_mv_y(lookup_issue_group_backward,block_request_ei[3]):
    (lookup_issue_group_backward?exec_bmvy:exec_fmvy);
wire lookup_issue_group_half_x=lookup_issue_group_mvx[0];
wire lookup_issue_group_half_y=lookup_issue_group_mvy[0];
wire lookup_issue_group_tap_dx=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        block_request_tap[0]:
    (lookup_issue_group_half_x?block_request_tap[0]:1'b0);
wire lookup_issue_group_tap_dy=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        block_request_tap[1]:
    (lookup_issue_group_half_y?block_request_tap[0]:1'b0);
wire lookup_issue_tap_last=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        (block_request_tap==2'd3):
    ((lookup_issue_group_half_x||lookup_issue_group_half_y)?
        (block_request_tap==2'd1):(block_request_tap==2'd0));
wire [1:0] lookup_issue_next_tap=block_request_tap+1'b1;
wire lookup_issue_next_tap_dx=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        lookup_issue_next_tap[0]:
    (lookup_issue_group_half_x?lookup_issue_next_tap[0]:1'b0);
wire lookup_issue_next_tap_dy=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        lookup_issue_next_tap[1]:
    (lookup_issue_group_half_y?lookup_issue_next_tap[0]:1'b0);
wire lookup_issue_next_tap_last=
    (lookup_issue_group_half_x&&lookup_issue_group_half_y)?
        (lookup_issue_next_tap==2'd3):
    ((lookup_issue_group_half_x||lookup_issue_group_half_y)?
        (lookup_issue_next_tap==2'd1):(lookup_issue_next_tap==2'd0));
wire [4:0] lookup_issue_group_byte=
    {2'd0,block_request_base_byte}+{2'd0,block_request_ei[2:0]}+
    {4'd0,lookup_issue_group_tap_dx};
wire [4:0] lookup_issue_next_byte=
    {2'd0,block_request_base_byte}+{2'd0,block_request_ei[2:0]}+
    {4'd0,lookup_issue_next_tap_dx};
wire lookup_issue_quad=!block_field_dct&&
    (block_request_tap==2'd0)&&lookup_issue_group_half_x&&
    lookup_issue_group_half_y&&
    (lookup_issue_group_byte[3]==lookup_issue_next_byte[3]);
wire lookup_issue_horizontal_pair=!lookup_issue_quad&&
    !lookup_issue_tap_last&&
    (lookup_issue_group_tap_dy==lookup_issue_next_tap_dy)&&
    (lookup_issue_group_byte[3]==lookup_issue_next_byte[3]);
wire lookup_issue_vertical_pair=!lookup_issue_quad&&
    !lookup_issue_tap_last&&!block_field_dct&&
    !lookup_issue_group_half_x&&lookup_issue_group_half_y&&
    (lookup_issue_next_tap_dy==(lookup_issue_group_tap_dy+1'b1))&&
    (lookup_issue_group_byte[3]==lookup_issue_next_byte[3]);
wire lookup_issue_pair=lookup_issue_horizontal_pair||
    lookup_issue_vertical_pair;
wire lookup_issue_phase_complete=lookup_issue_tap_last||lookup_issue_quad||
    (lookup_issue_pair&&lookup_issue_next_tap_last);
wire [1:0] lookup_issue_advance_tap=block_request_tap+
    (lookup_issue_pair?2'd2:2'd1);
wire block_lookup_target_complete=block_lookup_target_bank?
    block_fetch_complete1:block_fetch_complete0;
wire block_lookup_field_target_ready=
    !((exec_field||block_field_dct)&&(exec_direction==2'd3)&&
      block_lookup_direction)||field_second_fetch_started;
wire block_lookup_stream_request=active&&lookup_issue_active&&
    block_lookup_target_complete&&block_lookup_field_target_ready&&
    !block_fetch_start;
assign block_lookup_request=block_lookup_stream_request;

assign ddram_burstcnt=block_fetch_rd?8'd1:8'd0;
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
assign store_field_dct=block_field_dct;
// Wide B scratch tag: X[11:10]=11 identifies scratch; Y[11:9]
// identifies Y/Cb/Cr while preserving 10-bit X and 9-bit Y coordinates.
assign store_pixel_x=emit_x;
assign store_pixel_y=emit_y;

wire descriptor_order_error=(capture_desc_count!=0)&&
    ({sideband_value[13:3],sideband_value[2:0]}<=
     {capture_last_desc_word[13:3],capture_last_desc_word[2:0]});
wire first_direction_word=(sideband_index==6'h37)||(sideband_index==6'h38)||(sideband_index==6'h39)||(sideband_index==6'h3a);
wire [1:0] direction_word=(sideband_index==6'h37)?2'd0:(sideband_index==6'h38)?2'd1:(sideband_index==6'h39)?2'd2:2'd3;
wire geometry_word=(sideband_index==6'h3c)&&(sideband_value[15:12]==4'd0);
wire descriptor_word=(sideband_index==6'h3f)&&sideband_value[15]&&
    (sideband_value!=16'shA3FE)&&(sideband_value!=16'shA3FF);

always @(posedge clk) begin
    if(reset) begin
        desc_word<=0;
        residual_pel<=0;
    end else begin
        desc_word<=desc_mem[{execute_bank,exec_desc_slot}];
        if(residual_load_wait||
           (fast_pixel_advance&&(ei!=6'd63))||
           slow_pixel_advance)
            residual_pel<=residual_hit?residual_store_read_data:16'sd0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        mb_width<=0;mb_height<=0;geometry_seen<=0;motion_count<=0;motion_word<=0;motion_load<=0;
        motion_first_pending<=0;pending_direction<=0;pending_fmvx<=0;pending_fmvy<=0;
        pending_fmvx1<=0;pending_fmvy1<=0;pending_bmvx1<=0;pending_bmvy1<=0;
        pending_field<=0;pending_field_dct<=0;pending_fsel0<=0;pending_fsel1<=0;pending_bsel1<=0;
        exec_direction<=0;exec_fmvx<=0;exec_fmvy<=0;exec_bmvx<=0;exec_bmvy<=0;
        exec_fmvx1<=0;exec_fmvy1<=0;exec_bmvx1<=0;exec_bmvy1<=0;
        exec_field<=0;exec_fsel0<=0;exec_fsel1<=0;exec_bsel0<=0;exec_bsel1<=0;
        exec_block_field_dct<=0;
        phase_mvx<=0;phase_mvy<=0;phase_backward<=0;
        bidir_prelaunch_addr<=0;next_prelaunch_addr<=0;
        miss_prelaunch_addr<=0;miss_prelaunch_byte<=0;
        bidir_prelaunch_byte<=0;next_prelaunch_byte<=0;
        bidir_prelaunch_valid<=0;next_prelaunch_valid<=0;
        phase_base_addr<=0;phase_base_byte<=0;phase_row_words<=0;
        phase_bounds_ok<=0;
        bank_desc_count[0]<=0;bank_desc_count[1]<=0;
        bank_last_desc_word[0]<=0;bank_last_desc_word[1]<=0;
        bank_motion_base[0]<=0;bank_motion_base[1]<=0;
        bank_motion_end[0]<=0;bank_motion_end[1]<=0;
        bank_row[0]<=0;bank_row[1]<=0;bank_ready<=0;
        capture_bank<=0;execute_bank<=0;current_desc_slot<=0;
        desc_active<=0;sample_expected<=0;exec_desc_slot<=0;
        exec_desc_count_latched<=0;exec_motion_end<=0;
        pending<=0;started<=0;active<=0;past_bank_latched<=0;future_bank_latched<=0;scratch_bank_latched<=0;req<=0;waitresp<=0;lookup_wait<=0;
        mbi<=0;col<=0;mrow<=0;blk<=0;timeout<=0;emit<=0;wait_store<=0;pixel_setup<=0;residual_load<=0;residual_load_wait<=0;ei<=0;
        pred_direction<=0;tap_index<=0;
        lookup_issue_active<=0;lookup_issue_ei<=0;
        lookup_issue_direction<=0;lookup_issue_tap<=0;
        pred_sum<=0;forward_prediction<=0;out_reg<=0;tap_byte_sel<=0;
        emit_advanced<=0;emit_x<=0;emit_y<=0;emit_block_start<=0;emit_block_complete<=0;
        block_fetch_start<=0;block_fetch_start_bank<=0;
        block_fetch_start_prefetch<=0;
        fetch_launch_phase_count<=0;
        fetch_launch_phase0_base_addr<=0;fetch_launch_phase1_base_addr<=0;
        fetch_launch_phase0_two_words<=0;fetch_launch_phase1_two_words<=0;
        fetch_launch_phase0_rows<=0;fetch_launch_phase1_rows<=0;
        fetch_launch_row_words<=0;block_consumer_bank<=0;
        block_prefetch_valid<=0;block_current_prefetched<=0;
        block_current_started<=0;
        field_second_fetch_pending<=0;field_second_fetch_launch<=0;
        field_second_fetch_started<=0;
        field_fetch_backward<=0;
        block_phase0_base_byte<=0;
        block_phase1_base_byte<=0;
        block_phase2_base_byte<=0;
        block_phase3_base_byte<=0;
        read_seen<=0;sample_nonzero<=0;half_sample_seen<=0;reconstructed_seen<=0;persisted_seen<=0;row_persisted<=0;error<=0;error_source<=0;
        row_final_latched<=0;
    end else begin
        row_persisted<=0;
        block_fetch_start<=0;
        if(capture_enable&&sideband_valid) begin
            if(desc_active) begin
                if(sideband_index!=sample_expected)begin error<=1;if(!error)error_source<=5'd1;end
                else if(sideband_index==6'd63)desc_active<=0;
                else sample_expected<=sample_expected+1'b1;
            end else if(first_direction_word) begin
                if(bank_ready[capture_bank]||motion_first_pending||
                   (motion_count>=MAX_MB)||(capture_desc_count!=0))begin error<=1;if(!error)error_source<=5'd2;end
                else begin
                    pending_direction<=direction_word;pending_fmvx<=motion_vector_x;pending_fmvy<=motion_vector_y;
                    // Entry 695: the record value carries the field flag and
                    // this slot's field select; frame prediction sends zero and
                    // leaves both slots equal.
                    pending_field<=sideband_value[1];pending_field_dct<=sideband_value[2];pending_fsel0<=sideband_value[0];
                    pending_fmvx1<=motion_vector_x;pending_fmvy1<=motion_vector_y;
                    pending_bmvx1<=0;pending_bmvy1<=0;pending_fsel1<=0;pending_bsel1<=0;
                    motion_first_pending<=1;
                end
            end else if(sideband_index==6'h35) begin
                if(bank_ready[capture_bank]||!motion_first_pending||!sideband_value[1])begin error<=1;if(!error)error_source<=5'd2;end
                else begin pending_fmvx1<=motion_vector_x;pending_fmvy1<=motion_vector_y;pending_fsel1<=sideband_value[0];end
            end else if(sideband_index==6'h36) begin
                if(bank_ready[capture_bank]||!motion_first_pending||!sideband_value[1])begin error<=1;if(!error)error_source<=5'd2;end
                else begin pending_bmvx1<=motion_vector_x;pending_bmvy1<=motion_vector_y;pending_bsel1<=sideband_value[0];end
            end else if(geometry_word) begin
                if(bank_ready[capture_bank]||geometry_seen||!motion_first_pending||(motion_count!=0)||
                   (sideband_value[11:6]==0)||(sideband_value[11:6]>6'd45)||(sideband_value[5:0]==0)||(sideband_value[5:0]>6'd30))begin error<=1;if(!error)error_source<=5'd3;end
                else begin mb_width<=sideband_value[11:6];mb_height<=sideband_value[5:0];geometry_seen<=1;end
            end else if(sideband_index==6'h3b) begin
                if(bank_ready[capture_bank]||!motion_first_pending||(motion_count>=MAX_MB)||!geometry_seen)begin error<=1;if(!error)error_source<=5'd4;end
                else begin
                    motion_mem[motion_count]<={pending_field_dct,
                        pending_field,pending_fsel0,pending_fsel1,sideband_value[0],pending_bsel1,
                        pending_direction,
                        pending_fmvx,pending_fmvy,pending_fmvx1,pending_fmvy1,
                        motion_vector_x,motion_vector_y,
                        pending_field?pending_bmvx1:motion_vector_x,
                        pending_field?pending_bmvy1:motion_vector_y};
                    motion_count<=motion_count+1'b1;motion_first_pending<=0;
                end
            end else if(descriptor_word) begin
                if((motion_count==0)||motion_first_pending||bank_ready[capture_bank]||
                   (capture_desc_count>=MAX_ROW_BLOCKS)||
                   (sideband_value[13:3]>=MAX_MB)||(sideband_value[2:0]>=6)||descriptor_order_error)begin error<=1;if(!error)error_source<=5'd5;end
