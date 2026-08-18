        endcase
        default:;
        endcase
        match_cbp_code={valid,value};
    end
endfunction
wire [6:0] cbp_match=match_cbp_code(cbp_bits_next,cbp_len_next);

wire parser_consumes_bit=(state==S_QSCALE)||(state==S_EXTRA_FLAG)||(state==S_EXTRA_INFO)||(state==S_MBA)||
    (state==S_MBTYPE)||(state==S_FX)||(state==S_FX_RES)||(state==S_FY)||(state==S_FY_RES)||
    (state==S_BX)||(state==S_BX_RES)||(state==S_BY)||(state==S_BY_RES)||(state==S_CBP)||
    (state==S_FIRST_COEFF)||(state==S_COEFF_VLC)||(state==S_COEFF_SIGN)||(state==S_ESCAPE_RUN)||
    (state==S_ESCAPE_LEVEL)||(state==S_STUFF);
wire consume_bit=parse_active&&parser_consumes_bit&&!parser_at_end;

reg t_start,t_we,t_end; reg [5:0] t_widx; reg signed [12:0] t_wval; reg [4:0] t_qscale;
wire t_done,t_first_valid,t_valid,t_error; wire signed [15:0] t_first_value,t_value; wire [1:0] t_unused_block; wire [5:0] t_index;
mpeg2_h262_p_non_intra_transform b_transform(
    .clk(clk),.reset(reset),.qfs_block_index(2'd1),.qfs_block_start(t_start),.qfs_write_en(t_we),
    .qfs_write_index(t_widx),.qfs_write_value(t_wval),.qfs_block_end(t_end),
    .quantiser_scale_code(t_qscale),.q_scale_type(q_scale_type),.alternate_scan(alternate_scan),
    .block_done(t_done),.first_sample_valid(t_first_valid),.first_sample_value(t_first_value),
    .residual_sample_valid(t_valid),.residual_sample_block_index(t_unused_block),
    .residual_sample_index(t_index),.residual_sample_value(t_value),.probe_error(t_error));

reg signed [15:0] residual_mem [0:1023];
reg [6:0] t_sample_count,t_coeff_read_index; reg [4:0] transform_slot;
localparam [3:0] R_IDLE=0,R_TSTART=1,R_TWRITE=2,R_TEND=3,R_TWAIT=4,R_DESC=5,R_SAMPLE=6,R_FINISH=7;
reg [3:0] rstate; reg [5:0] replay_sample; reg [4:0] replay_slot;
wire [10:0] desc_mb=residual_mb[replay_slot[3:0]];
wire [2:0] desc_block=residual_block[replay_slot[3:0]];
wire [9:0] res_mem_addr={replay_slot[3:0],6'b000000}+{4'd0,replay_sample};

// kate - Commit 173: next uncovered column in the current row across
// same-vertical-position slices. It is reset only when restricted coverage
// advances to the next row, not at each slice header.
reg [5:0] row_covered_count;

integer i;
always @(posedge clk) begin
    if(reset) begin
        byte_window<=0;sequence_capture<=0;sequence_count<=0;sequence_shift<=0;geometry_supported<=0;picture_mb_width<=0;picture_mb_height<=0;
        picture_capture<=0;picture_count<=0;picture_shift<=0;current_picture_is_b<=0;
        pce_capture<=0;pce_count<=0;pce_shift<=0;b_candidate<=0;b_seen<=0;b_complete_now<=0;
        b_forward_f_code_horizontal<=0;b_forward_f_code_vertical<=0;
        b_backward_f_code_horizontal<=0;b_backward_f_code_vertical<=0;
        parse_hold<=0;parser_error<=0;replay_error<=0;prior_error<=0;slice_capture<=0;slice_parser_started<=0;chunk_boundary_known<=0;slice_row_number<=0;row_byte_count<=0;row_base_index<=0;row_covered_count<=0;
        parse_active<=0;proof_done<=0;boundary_final<=0;parse_byte_limit<=0;parse_byte_index<=0;parse_bit_index<=7;
        state<=S_QSCALE;field_bit_count<=0;qscale_shift<=0;current_qscale<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;skip_remaining<=0;geometry_sent<=0;
        mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;mba_symbol_escape_q<=0;mba_symbol_value_q<=0;mbtype_bits<=0;mbtype_len<=0;current_direction<=0;last_direction<=0;current_pattern<=0;
        fpx<=0;fpy<=0;bpx<=0;bpy<=0;cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;
        motion_code_pending<=0;motion_bits<=0;motion_len<=0;motion_residual_shift<=0;motion_residual_count<=0;
        cbp_bits<=0;cbp_len<=0;current_cbp<=0;current_block_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;
        qfs_index<=0;coeff_run_pending<=0;coeff_level_pending<=0;current_block_has_coeff<=0;
        escape_run_shift<=0;escape_run_bit_count<=0;escape_level_shift<=0;escape_level_bit_count<=0;
        residual_count<=0;residual_coeff_count<=0;q_scale_type<=0;alternate_scan<=0;
        t_start<=0;t_we<=0;t_end<=0;t_widx<=0;t_wval<=0;t_qscale<=0;t_sample_count<=0;t_coeff_read_index<=0;transform_slot<=0;
        rstate<=R_IDLE;replay_sample<=0;replay_slot<=0;replay_active<=0;sideband_valid<=0;sideband_index<=0;sideband_value<=0;
        first_sample_valid<=0;first_sample_value<=0;
        for(i=0;i<16;i=i+1)begin residual_mb[i]<=0;residual_block[i]<=0;residual_qscale[i]<=0;end
        for(i=0;i<64;i=i+1)begin residual_coeff_index[i]<=0;residual_coeff_value[i]<=0;residual_coeff_last[i]<=0;end
    end else begin
        b_complete_now<=0;sideband_valid<=0;first_sample_valid<=0;t_start<=0;t_we<=0;t_end<=0;
        if(t_error)replay_error<=1;

        if(parse_active) begin
            if(parser_at_end && !chunk_boundary_known) begin
                parse_active<=0;parse_hold<=0;slice_capture<=1;
                row_bytes[0]<=row_bytes[ROW_BUFFER_BYTES-2];
                row_bytes[1]<=row_bytes[ROW_BUFFER_BYTES-1];
                row_byte_count<=9'd2;parse_byte_index<=0;parse_bit_index<=7;
            end else begin
            if(consume_bit) begin
                if(parse_bit_index==0)begin parse_bit_index<=7;parse_byte_index<=parse_byte_index+1'b1;end
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
                else begin sideband_valid<=1;sideband_index<=direction_index(last_direction);sideband_value<=$signed({fpx,fpy});state<=S_SKIP_B;end
            end
            S_SKIP_B: begin
                sideband_valid<=1;sideband_index<=6'h3b;sideband_value<=$signed({bpx,bpy});current_col<=current_col+1'b1;
                if(skip_remaining==1)begin skip_remaining<=0;state<=S_MBTYPE;end
                else begin skip_remaining<=skip_remaining-1'b1;state<=S_SKIP_A;end
            end
            S_MBTYPE: begin
                if(parser_at_end)state<=S_ERROR;
                else if(mbtype_match[3])begin
                    current_direction<=mbtype_match[2:1];current_pattern<=mbtype_match[0];mbtype_bits<=0;mbtype_len<=0;
                    cur_fx<=0;cur_fy<=0;cur_bx<=0;cur_by<=0;motion_bits<=0;motion_len<=0;
                    if(mbtype_match[2:1]==2'd2)state<=S_BX;else state<=S_FX;
                end else if(mbtype_len_next>=4)state<=S_ERROR;else begin mbtype_bits<=mbtype_bits_next;mbtype_len<=mbtype_len_next;end
            end
            S_FX: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin
                    motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;
                    if($signed(motion_match[5:0])==0)begin cur_fx<=fpx;state<=S_FY;end
                    else if(b_forward_f_code_horizontal==4'd1)begin
                        cur_fx<=reconstruct_mv(fpx,motion_match[5:0],3'd0,b_forward_f_code_horizontal);state<=S_FY;
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
                        cur_fy<=reconstruct_mv(fpy,motion_match[5:0],3'd0,b_forward_f_code_vertical);
                        if(current_direction==2'd3)state<=S_BX;
                        else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end
                        else state<=S_MB_DONE;
                    end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_FY_RES;end
                end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
