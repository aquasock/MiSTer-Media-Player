        endcase
        default:;
        endcase
        match_cbp_code={valid,value};
    end
endfunction
wire [6:0] cbp_match=match_cbp_code(cbp_bits_next,cbp_len_next);

always @* begin
    dc_size_match=1'b0;dc_size_value=4'd0;
    if(current_block_index<3'd4) begin
        case(dc_vlc_len_next)
        2:case(dc_vlc_code_next[1:0])
            2'b00:begin dc_size_match=1;dc_size_value=1;end
            2'b01:begin dc_size_match=1;dc_size_value=2;end default:;endcase
        3:case(dc_vlc_code_next[2:0])
            3'b100:begin dc_size_match=1;dc_size_value=0;end
            3'b101:begin dc_size_match=1;dc_size_value=3;end
            3'b110:begin dc_size_match=1;dc_size_value=4;end default:;endcase
        4:if(dc_vlc_code_next[3:0]==4'b1110)begin dc_size_match=1;dc_size_value=5;end
        5:if(dc_vlc_code_next[4:0]==5'b11110)begin dc_size_match=1;dc_size_value=6;end
        6:if(dc_vlc_code_next[5:0]==6'b111110)begin dc_size_match=1;dc_size_value=7;end
        7:if(dc_vlc_code_next[6:0]==7'b1111110)begin dc_size_match=1;dc_size_value=8;end
        8:if(dc_vlc_code_next[7:0]==8'b11111110)begin dc_size_match=1;dc_size_value=9;end
        9:case(dc_vlc_code_next[8:0])
            9'b111111110:begin dc_size_match=1;dc_size_value=10;end
            9'b111111111:begin dc_size_match=1;dc_size_value=11;end default:;endcase
        default:;endcase
    end else begin
        case(dc_vlc_len_next)
        2:case(dc_vlc_code_next[1:0])
            2'b00:begin dc_size_match=1;dc_size_value=0;end
            2'b01:begin dc_size_match=1;dc_size_value=1;end
            2'b10:begin dc_size_match=1;dc_size_value=2;end default:;endcase
        3:if(dc_vlc_code_next[2:0]==3'b110)begin dc_size_match=1;dc_size_value=3;end
        4:if(dc_vlc_code_next[3:0]==4'b1110)begin dc_size_match=1;dc_size_value=4;end
        5:if(dc_vlc_code_next[4:0]==5'b11110)begin dc_size_match=1;dc_size_value=5;end
        6:if(dc_vlc_code_next[5:0]==6'b111110)begin dc_size_match=1;dc_size_value=6;end
        7:if(dc_vlc_code_next[6:0]==7'b1111110)begin dc_size_match=1;dc_size_value=7;end
        8:if(dc_vlc_code_next[7:0]==8'b11111110)begin dc_size_match=1;dc_size_value=8;end
        9:if(dc_vlc_code_next[8:0]==9'b111111110)begin dc_size_match=1;dc_size_value=9;end
        10:case(dc_vlc_code_next[9:0])
            10'b1111111110:begin dc_size_match=1;dc_size_value=10;end
            10'b1111111111:begin dc_size_match=1;dc_size_value=11;end default:;endcase
        default:;endcase
    end
end

wire parser_consumes_bit=(state==S_QSCALE)||(state==S_EXTRA_FLAG)||(state==S_EXTRA_INFO)||(state==S_MBA)||
    (state==S_MBTYPE)||(state==S_FX)||(state==S_FX_RES)||(state==S_FY)||(state==S_FY_RES)||
    (state==S_BX)||(state==S_BX_RES)||(state==S_BY)||(state==S_BY_RES)||(state==S_CBP)||
    (state==S_FIRST_COEFF)||(state==S_COEFF_VLC)||(state==S_COEFF_SIGN)||(state==S_ESCAPE_RUN)||
    (state==S_ESCAPE_LEVEL)||(state==S_STUFF)||(state==S_MB_QSCALE)||
    (state==S_DC_SIZE)||(state==S_DC_DIFF);
wire consume_bit=parse_active&&parser_consumes_bit&&!parser_at_end;

reg t_start,t_we,t_end,t_intra; reg [5:0] t_widx; reg signed [12:0] t_wval; reg [4:0] t_qscale;
wire t_done,t_first_valid,t_valid,t_error; wire signed [15:0] t_first_value,t_value; wire [1:0] t_unused_block; wire [5:0] t_index;
mpeg2_h262_p_non_intra_transform b_transform(
    .clk(clk),.reset(reset),.qfs_block_index(2'd1),.qfs_block_start(t_start),.qfs_write_en(t_we),
    .qfs_write_index(t_widx),.qfs_write_value(t_wval),.qfs_block_end(t_end),
    .quantiser_scale_code(t_qscale),.q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
    .intra_block(t_intra),.intra_dc_precision(b_intra_dc_precision),
    .block_done(t_done),.first_sample_valid(t_first_valid),.first_sample_value(t_first_value),
    .residual_sample_valid(t_valid),.residual_sample_block_index(t_unused_block),
    .residual_sample_index(t_index),.residual_sample_value(t_value),.probe_error(t_error));

reg [6:0] t_sample_count;
reg [15:0] t_coeff_read_index,block_coeff_end;
reg [11:0] transform_slot;
reg [10:0] transform_mb;
reg [2:0] transform_block;
reg transform_intra;
localparam [3:0]
    R_IDLE=0,R_BLOCK_WAIT=1,R_BLOCK_CAPTURE=2,R_TSTART=3,
    R_TWRITE=4,R_COEFF_WAIT=5,R_TEND=6,R_TWAIT=7,
    R_DESC=8,R_SAMPLE=9,R_FINISH=10;
reg [3:0] rstate;
wire producer_row_done=replay_active&&(rstate==R_FINISH);
// Entry 278: keep the RAM address itself registered so Quartus retains the
// 32Kx19 M10K inference.  R_TSTART primes the successor address before the
// first write; every consecutive R_TWRITE then consumes the retained word
// while the synchronous port captures its successor.
reg [14:0] residual_coeff_read_address;

// kate - Commit 173: next uncovered column in the current row across
// same-vertical-position slices. It is reset only when restricted coverage
// advances to the next row, not at each slice header.
reg [5:0] row_covered_count;

always @(posedge clk) begin
    if(reset) begin
        residual_block_word<=0;
        residual_coeff_word<=0;
        residual_coeff_read_address<=0;
    end else begin
        residual_block_word<=residual_block_mem[transform_slot[10:0]];
        residual_coeff_word<=residual_coeff_mem[residual_coeff_read_address];
        if(!replay_active||(rstate==R_BLOCK_WAIT))
            residual_coeff_read_address<=t_coeff_read_index[14:0];
        else if(rstate==R_TSTART)
            residual_coeff_read_address<=t_coeff_read_index[14:0]+15'd1;
        else if(rstate==R_TWRITE)
            residual_coeff_read_address<=t_coeff_read_index[14:0]+15'd2;
        else if((rstate==R_TWAIT)&&t_done&&
                (transform_slot+1'b1<residual_count))
            residual_coeff_read_address<=t_coeff_read_index[14:0];
    end
end

always @(posedge clk) begin
    // Unconditional and outside reset so Quartus infers a block-memory read
    // port; the address leads the bit pointer by one byte.
    row_ram_q<=row_bytes[parse_byte_index+9'd1];
    if(reset) begin
        parse_cur_byte<=0;row_head0<=0;row_head1<=0;row_tail_last<=0;row_tail_prev<=0;
        byte_window<=0;sequence_capture<=0;sequence_count<=0;sequence_shift<=0;geometry_supported<=0;picture_mb_width<=0;picture_mb_height<=0;
        picture_capture<=0;picture_count<=0;picture_shift<=0;current_picture_is_b<=0;
        pce_capture<=0;pce_count<=0;pce_shift<=0;b_candidate<=0;b_seen<=0;b_complete_now<=0;
        b_forward_f_code_horizontal<=0;b_forward_f_code_vertical<=0;
        b_backward_f_code_horizontal<=0;b_backward_f_code_vertical<=0;
        parse_hold<=0;parser_error<=0;replay_error<=0;prior_error<=0;slice_capture<=0;slice_parser_started<=0;chunk_boundary_known<=0;slice_row_number<=0;row_byte_count<=0;row_base_index<=0;row_covered_count<=0;
        parse_active<=0;proof_done<=0;boundary_final<=0;row_waiting<=0;replay_row_final<=0;
        outstanding_rows<=0;final_row_queued<=0;producer_rearm_pending<=0;
        parse_byte_limit<=0;parse_byte_index<=0;parse_bit_index<=7;
        state<=S_QSCALE;field_bit_count<=0;qscale_shift<=0;current_qscale<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;skip_remaining<=0;geometry_sent<=0;
        mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;mba_symbol_escape_q<=0;mba_symbol_value_q<=0;mbtype_bits<=0;mbtype_len<=0;current_direction<=0;last_direction<=0;current_pattern<=0;current_intra<=0;current_quant<=0;
        fpx<=0;fpy<=0;bpx<=0;bpy<=0;cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;
        motion_code_pending<=0;motion_bits<=0;motion_len<=0;motion_residual_shift<=0;motion_residual_count<=0;
        cbp_bits<=0;cbp_len<=0;current_cbp<=0;current_block_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;
        qfs_index<=0;coeff_run_pending<=0;coeff_level_pending<=0;current_block_has_coeff<=0;
        escape_run_shift<=0;escape_run_bit_count<=0;escape_level_shift<=0;escape_level_bit_count<=0;
        residual_count<=0;residual_coeff_count<=0;pending_residual_mb<=0;pending_residual_block<=0;pending_residual_qscale<=0;pending_residual_intra<=0;q_scale_type<=0;alternate_scan<=0;b_intra_vlc_format<=0;b_intra_dc_precision<=0;
        dc_predictor_y<=11'd128;dc_predictor_cb<=11'd128;dc_predictor_cr<=11'd128;dc_vlc_code<=0;dc_vlc_len<=0;dc_size<=0;dc_diff_bit_count<=0;dc_diff_shift<=0;
        t_start<=0;t_we<=0;t_end<=0;t_intra<=0;t_widx<=0;t_wval<=0;t_qscale<=0;t_sample_count<=0;t_coeff_read_index<=0;block_coeff_end<=0;transform_slot<=0;transform_mb<=0;transform_block<=0;transform_intra<=0;
        rstate<=R_IDLE;replay_active<=0;sideband_valid<=0;sideband_index<=0;sideband_value<=0;motion_vector_x<=0;motion_vector_y<=0;
        first_sample_valid<=0;first_sample_value<=0;
    end else begin
        b_complete_now<=0;sideband_valid<=0;first_sample_valid<=0;t_start<=0;t_we<=0;t_end<=0;
        if(t_error)replay_error<=1;
        if(producer_rearm_pending)begin
            producer_rearm_pending<=0;
            residual_count<=0;residual_coeff_count<=0;
        end

        // Entry 264: the producer and raster consumer share two logical row
        // banks.  A completed transform row consumes one credit; persistence
        // returns one.  Parsing can therefore advance immediately while one
        // older row reconstructs, and stalls only when both banks are full.
        case({producer_row_done,row_retired})
        2'b10:outstanding_rows<=outstanding_rows+1'b1;
        2'b01:outstanding_rows<=outstanding_rows-1'b1;
        default:outstanding_rows<=outstanding_rows;
        endcase

        if(row_retired&&final_row_queued&&(outstanding_rows==1)&&
           !producer_row_done) begin
            row_waiting<=0;parse_hold<=0;final_row_queued<=0;
            b_seen<=1;b_complete_now<=1;proof_done<=1;
        end else if(row_waiting&&row_retired&&!producer_row_done&&
                    !final_row_queued) begin
            row_waiting<=0;parse_hold<=0;
            residual_count<=0;residual_coeff_count<=0;
            row_byte_count<=0;row_covered_count<=0;
            slice_row_number<=slice_row_number+1'b1;
            row_base_index<=row_base_index+{5'd0,picture_mb_width};
            slice_capture<=1;
        end

        if(parse_active) begin
            if(parser_at_end && !chunk_boundary_known) begin
                parse_active<=0;parse_hold<=0;slice_capture<=1;
                row_head0<=row_tail_prev;
                row_head1<=row_tail_last;
                parse_cur_byte<=row_tail_prev;
                row_byte_count<=9'd2;parse_byte_index<=0;parse_bit_index<=7;
            end else begin
            if(consume_bit) begin
                if(parse_bit_index==0)begin parse_bit_index<=7;parse_byte_index<=parse_byte_index+1'b1;parse_cur_byte<=parse_next_byte;end
                else parse_bit_index<=parse_bit_index-1'b1;
            end
            case(state)
            S_QSCALE: begin
                if(parser_at_end)state<=S_ERROR;
                else begin qscale_shift<=qscale_next;if(field_bit_count==4)begin field_bit_count<=0;if(qscale_next==0)state<=S_ERROR;else begin current_qscale<=qscale_next;state<=S_EXTRA_FLAG;end end else field_bit_count<=field_bit_count+1'b1;end
            end
            S_EXTRA_FLAG: begin
                if(parser_at_end)state<=S_ERROR;
                else if(parser_current_bit)begin extra_info_count<=0;state<=S_EXTRA_INFO;end
                else begin mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;state<=S_MBA;end
            end
            S_EXTRA_INFO: begin
                if(parser_at_end)state<=S_ERROR;else if(extra_info_count==7)begin extra_info_count<=0;state<=S_EXTRA_FLAG;end else extra_info_count<=extra_info_count+1'b1;
            end
            S_MBA: begin
                // kate - Commit 173: a coded slice endpoint may be followed by
                // zero alignment bits and then the already-buffered start-code
                // boundary. Only an all-zero unfinished MBA with no escape debt
                // can terminate a non-empty slice.
                if(parser_at_end) begin
                    if(row_has_coded_mb&&(mba_wide_bits==0)&&(mba_escape_accum==0))state<=S_SUCCESS;
                    else state<=S_ERROR;
                end else if(mba_symbol[7]) begin
                    mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;
                    mba_symbol_escape_q<=mba_symbol[6];mba_symbol_value_q<=mba_symbol[5:0];
                    state<=S_MBA_APPLY;
                end else if(mba_wide_len_next>=4'd11) state<=S_ERROR;
                else begin mba_wide_bits<=mba_wide_bits_next;mba_wide_len<=mba_wide_len_next;end
            end
            S_MBA_APPLY: begin
                if(mba_symbol_escape_q) begin
                    if(mba_escape_min_target_q>={2'b00,picture_mb_width})state<=S_ERROR;
                    else begin mba_escape_accum<=mba_escape_accum_next_q[6:0];state<=S_MBA;end
                end else if((mba_increment_total_q==0)||
                            (mba_target_col_q>={2'b00,picture_mb_width})||
                            (!row_has_coded_mb&&
                             (mba_target_col_q!={2'b00,row_covered_count}))) begin
                    state<=S_ERROR;
                end else begin
                    // STANDARDS_CONFORMANCE:H262-025. The first MBA positions
                    // the first coded macroblock and never emits synthetic
                    // leading skips; later MBA gaps retain normal B skip logic.
                    mba_escape_accum<=0;mbtype_bits<=0;mbtype_len<=0;
                    if(!row_has_coded_mb)begin current_col<=mba_target_col_q[5:0];state<=S_MBTYPE;end
                    else if(mba_increment_total_q>8'd1)begin skip_remaining<=mba_increment_total_q[5:0]-1'b1;state<=S_SKIP_A;end
                    else state<=S_MBTYPE;
                end
            end
            S_SKIP_A: begin
                if(last_direction==0)state<=S_ERROR;
                else begin dc_predictor_y<=dc_predictor_reset;dc_predictor_cb<=dc_predictor_reset;dc_predictor_cr<=dc_predictor_reset;sideband_valid<=1;sideband_index<=direction_index(last_direction);sideband_value<=0;motion_vector_x<=fpx;motion_vector_y<=fpy;state<=S_SKIP_B;end
            end
            S_SKIP_B: begin
                sideband_valid<=1;sideband_index<=6'h3b;sideband_value<=0;motion_vector_x<=bpx;motion_vector_y<=bpy;current_col<=current_col+1'b1;
                if(skip_remaining==1)begin skip_remaining<=0;state<=S_MBTYPE;end
                else begin skip_remaining<=skip_remaining-1'b1;state<=S_SKIP_A;end
            end
            S_MBTYPE: begin
                if(parser_at_end)state<=S_ERROR;
                else if(mbtype_match[5])begin
                    current_quant<=mbtype_match[4];current_intra<=mbtype_match[3];current_direction<=mbtype_match[2:1];current_pattern<=mbtype_match[0];mbtype_bits<=0;mbtype_len<=0;
                    cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;motion_bits<=0;motion_len<=0;
                    if(!mbtype_match[3])begin dc_predictor_y<=dc_predictor_reset;dc_predictor_cb<=dc_predictor_reset;dc_predictor_cr<=dc_predictor_reset;end
                    if(mbtype_match[4])begin qscale_shift<=0;field_bit_count<=0;state<=S_MB_QSCALE;end
                    else if(mbtype_match[3])begin current_cbp<=6'h3f;current_block_index<=0;state<=S_BLOCK;end
                    else if(mbtype_match[2:1]==2'd2)state<=S_BX;else state<=S_FX;
                end else if(mbtype_len_next>=6)state<=S_ERROR;else begin mbtype_bits<=mbtype_bits_next;mbtype_len<=mbtype_len_next;end
            end
            S_MB_QSCALE: begin
                if(parser_at_end)state<=S_ERROR;
                else begin qscale_shift<=qscale_next;if(field_bit_count==4)begin field_bit_count<=0;if(qscale_next==0)state<=S_ERROR;else begin current_qscale<=qscale_next;if(current_intra)begin current_cbp<=6'h3f;current_block_index<=0;state<=S_BLOCK;end else state<=S_ERROR;end end else field_bit_count<=field_bit_count+1'b1;end
            end
            S_FX: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin
                    motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;
                    if($signed(motion_match[5:0])==0)begin cur_fx<=fpx;state<=S_FY;end
                    else if(b_forward_f_code_horizontal==4'd1)begin
                        cur_fx<=reconstruct_mv(fpx,motion_match[5:0],4'd0,b_forward_f_code_horizontal);state<=S_FY;
                    end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_FX_RES;end
                end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_FX_RES: begin
                if(parser_at_end)state<=S_ERROR;
                else begin
                    motion_residual_shift<=motion_residual_next;
                    if({2'b00,motion_residual_count}==(b_forward_f_code_horizontal-4'd2))begin
                        cur_fx<=reconstruct_mv(fpx,motion_code_pending,motion_residual_next,b_forward_f_code_horizontal);
                        motion_residual_count<=0;motion_bits<=0;motion_len<=0;state<=S_FY;
                    end else motion_residual_count<=motion_residual_count+1'b1;
                end
            end
            S_FY: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin
                    motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;
                    if($signed(motion_match[5:0])==0)begin
                        cur_fy<=fpy;
                        if(current_direction==2'd3)state<=S_BX;
                        else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end
                        else state<=S_MB_DONE;
                    end else if(b_forward_f_code_vertical==4'd1)begin
                        cur_fy<=reconstruct_mv(fpy,motion_match[5:0],4'd0,b_forward_f_code_vertical);
                        if(current_direction==2'd3)state<=S_BX;
                        else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end
                        else state<=S_MB_DONE;
                    end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_FY_RES;end
                end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
