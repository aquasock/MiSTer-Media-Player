            R_DC_SIZE: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(dc_size_match) begin
                    dc_size<=dc_size_value;
                    dc_vlc_code<=0;
                    dc_vlc_len<=0;
                    if(dc_size_value==0) begin
                        if(residual_coeff_count>=MAX_COEFF_EVENTS)
                            parser_state<=R_ERROR;
                        else begin
                            residual_coeff_mem[residual_coeff_count[14:0]]<=
                                {6'd0,$signed({2'b00,dc_predictor_current})};
                            residual_coeff_last_mem[
                                residual_coeff_count[14:0]]<=1'b0;
                            residual_coeff_count<=residual_coeff_count+1'b1;
                            qfs_index<=7'd1;
                            current_block_has_coeff<=1;
                            coeff_vlc_code<=0;
                            coeff_vlc_len<=0;
                            parser_state<=R_COEFF_VLC;
                        end
                    end else begin
                        dc_diff_shift<=0;
                        dc_diff_bit_count<=0;
                        parser_state<=R_DC_DIFF;
                    end
                end else if(dc_vlc_len_next>=
                            ((current_block_index<4)?4'd9:4'd10))
                    parser_state<=R_ERROR;
                else begin
                    dc_vlc_code<=dc_vlc_code_next;
                    dc_vlc_len<=dc_vlc_len_next;
                end
            end

            R_DC_DIFF: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    dc_diff_shift<=dc_diff_bits_next;
                    if(dc_diff_bit_count==(dc_size-1'b1)) begin
                        if((dc_coefficient_decoded<0) ||
                           (dc_coefficient_decoded>
                            dc_coefficient_max_signed) ||
                           (residual_coeff_count>=MAX_COEFF_EVENTS)) begin
                            parser_state<=R_ERROR;
                        end else begin
                            if(current_block_index<4)
                                dc_predictor_y<=dc_coefficient_decoded[10:0];
                            else if(current_block_index==4)
                                dc_predictor_cb<=dc_coefficient_decoded[10:0];
                            else
                                dc_predictor_cr<=dc_coefficient_decoded[10:0];
                            residual_coeff_mem[residual_coeff_count[14:0]]<=
                                {6'd0,dc_coefficient_decoded};
                            residual_coeff_last_mem[
                                residual_coeff_count[14:0]]<=1'b0;
                            residual_coeff_count<=residual_coeff_count+1'b1;
                            qfs_index<=7'd1;
                            current_block_has_coeff<=1;
                            coeff_vlc_code<=0;
                            coeff_vlc_len<=0;
                            parser_state<=R_COEFF_VLC;
                        end
                    end else dc_diff_bit_count<=dc_diff_bit_count+1'b1;
                end
            end

            R_COEFF_VLC: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(coeff_vlc_match) begin
                    coeff_vlc_code<=0;
                    coeff_vlc_len<=0;
                    if(coeff_vlc_eob) begin
                        if(!current_block_has_coeff ||
                           residual_coeff_count==0) begin
                            parser_state<=R_ERROR;
                        end else begin
                            residual_coeff_last_mem[
                                residual_coeff_count[14:0]-1'b1
                            ]<=1'b1;
                            current_block_index<=
                                current_block_index+1'b1;
                            parser_state<=R_BLOCK;
                        end
                    end else if(coeff_vlc_escape) begin
                        escape_run_shift<=0;
                        escape_run_bit_count<=0;
                        parser_state<=R_ESCAPE_RUN;
                    end else begin
                        coeff_run_pending<=coeff_vlc_run;
                        coeff_level_pending<=coeff_vlc_level;
                        parser_state<=R_COEFF_SIGN;
                    end
                end else if(coeff_vlc_len_next>=5'd16) begin
                    parser_state<=R_ERROR;
                end else begin
                    coeff_vlc_code<=coeff_vlc_code_next;
                    coeff_vlc_len<=coeff_vlc_len_next;
                end
            end

            R_COEFF_SIGN: begin
                if(parser_at_end ||
                   normal_target_index>8'd63 ||
                   residual_coeff_count>=MAX_COEFF_EVENTS) begin
                    parser_state<=R_ERROR;
                end else begin
                    residual_coeff_mem[residual_coeff_count[14:0]]<=
                        {normal_target_index[5:0],parser_current_bit ?
                         -$signed({7'd0,coeff_level_pending}) :
                          $signed({7'd0,coeff_level_pending})};
                    residual_coeff_last_mem[
                        residual_coeff_count[14:0]]<=1'b0;
                    residual_coeff_count<=residual_coeff_count+1'b1;
                    qfs_index<={1'b0,normal_target_index[5:0]}+7'd1;
                    current_block_has_coeff<=1;
                    coeff_vlc_code<=0;
                    coeff_vlc_len<=0;
                    parser_state<=R_COEFF_VLC;
                end
            end

            R_ESCAPE_RUN: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    escape_run_shift<=escape_run_next;
                    if(escape_run_bit_count==3'd5) begin
                        escape_run_bit_count<=0;
                        escape_level_shift<=0;
                        escape_level_bit_count<=0;
                        parser_state<=R_ESCAPE_LEVEL;
                    end else escape_run_bit_count<=escape_run_bit_count+1'b1;
                end
            end

            R_ESCAPE_LEVEL: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    escape_level_shift<=escape_level_next;
                    if(escape_level_bit_count==4'd11) begin
                        if((escape_level_next==12'h000) ||
                           (escape_level_next==12'h800) ||
                           (escape_target_index>8'd63) ||
                           (residual_coeff_count>=MAX_COEFF_EVENTS)) begin
                            parser_state<=R_ERROR;
                        end else begin
                            residual_coeff_mem[
                                residual_coeff_count[14:0]]<=
                                {escape_target_index[5:0],
                                 escape_level_signed[11],
                                 escape_level_signed};
                            residual_coeff_last_mem[
                                residual_coeff_count[14:0]]<=1'b0;
                            residual_coeff_count<=
                                residual_coeff_count+1'b1;
                            qfs_index<=
                                {1'b0,escape_target_index[5:0]}+7'd1;
                            current_block_has_coeff<=1;
                            coeff_vlc_code<=0;
                            coeff_vlc_len<=0;
                            parser_state<=R_COEFF_VLC;
                        end
                    end else begin
                        escape_level_bit_count<=
                            escape_level_bit_count+1'b1;
                    end
                end
            end

            R_MB_DONE: begin
                motion_event_valid<=1;
                motion_event_index<=current_mb_index;
                motion_event_x<=current_motion_x;
                motion_event_y<=current_motion_y;
                motion_event_intra<=current_is_intra;
                if(current_has_motion) begin
                    predictor_x<=current_motion_x;
                    predictor_y<=current_motion_y;
                end
                row_has_coded_mb<=1;
                if(current_col==(picture_mb_width-1'b1)) begin
                    parser_state<=R_STUFF;
                end else begin
                    mba_vlc_bits<=0;
                    mba_vlc_len<=0;
                    mba_escape_accum<=0;
                    parser_state<=R_MBA;
                end
            end

            R_STUFF: begin
                if(parser_at_end) parser_state<=R_SUCCESS;
                else if(parser_current_bit) parser_state<=R_ERROR;
            end

            R_SUCCESS: begin
                parse_active<=0;
                slice_parser_started<=0;
                chunk_boundary_known<=0;
                if(!row_has_coded_mb) begin
                    probe_error<=1;
                    proof_done<=1;
                    parse_hold<=0;
                end else if(boundary_final) begin
                    if(current_col!=(picture_mb_width-1'b1)) begin
                        probe_error<=1;
                        proof_done<=1;
                        parse_hold<=0;
                    end else begin
                        picture_mb_count<=
                            row_base_index+{5'd0,current_col}+11'd1;
                        row_complete_now<=1;
                        row_final<=1;
                        row_waiting<=1;
                    end
                end else if(slice_capture) begin
                    // kate - Commit 173: while parse_active, slice_capture is
                    // the already-consumed boundary classification: 1 means the
                    // following slice has the same vertical position.
                    if(current_col>=(picture_mb_width-1'b1)) begin
                        probe_error<=1;
                        proof_done<=1;
                        parse_hold<=0;
                    end else begin
                        picture_mb_count<=
                            row_base_index+{5'd0,current_col}+11'd1;
                        row_covered_count<=current_col+1'b1;
                        row_byte_count<=0;
                        slice_capture<=1;
                        parse_hold<=0;
                    end
                end else begin
                    // A row transition is legal only after the restricted-slice
                    // coverage for the current row reaches its right edge.
                    if(current_col!=(picture_mb_width-1'b1)) begin
                        probe_error<=1;
                        proof_done<=1;
                        parse_hold<=0;
                    end else begin
                        picture_mb_count<=
                            row_base_index+{5'd0,picture_mb_width};
                        row_complete_now<=1;
                        row_final<=0;
                        row_waiting<=1;
                    end
                end
            end

            default: begin
                parse_active<=0;
                parse_hold<=0;
                slice_parser_started<=0;
                chunk_boundary_known<=0;
                proof_done<=1;
                probe_error<=1;
                wide_candidate<=0;
            end
            endcase
            end
        end

        if(stream_valid) begin
            byte_window<=byte_window_next;

            if(sequence_capture) begin
                sequence_shift<=sequence_next;
                if(sequence_count==2) begin
                    sequence_capture<=0;
                    sequence_count<=0;
                    picture_mb_width<=sequence_mb_width_next;
                    picture_mb_height<=sequence_mb_height_next;
                    geometry_supported<=
                        (sequence_h_next!=0) &&
                        (sequence_v_next!=0) &&
                        (sequence_h_next<=12'd720) &&
                        (sequence_v_next<=12'd480) &&
                        (sequence_mb_width_next!=0) &&
                        (sequence_mb_width_next<=6'd45) &&
                        (sequence_mb_height_next!=0) &&
                        (sequence_mb_height_next<=6'd30) &&
                        (((sequence_h_next==12'd128) &&
                          (sequence_v_next==12'd96)) ||
                         (sequence_h_next>12'd128) ||
                         (sequence_v_next>12'd96));
                end else sequence_count<=sequence_count+1'b1;
            end else if(start_code_now &&
                        (start_code_value==SEQUENCE_HEADER_CODE)) begin
                sequence_capture<=1;
                sequence_count<=0;
                sequence_shift<=0;
            end

            if(picture_capture) begin
                picture_shift<=picture_next;
                if(picture_count) begin
                    picture_capture<=0;
                    picture_count<=0;
                    current_picture_is_p<=
                        (picture_next[5:3]==3'd2);
                    wide_candidate<=0;
                    if((picture_next[5:3]==3'd2) &&
                       geometry_supported) begin
                        wide_seen<=0;
                        picture_mb_count<=0;
                        residual_block_count<=0;
                        residual_present<=0;
                        residual_coeff_count<=0;
                        slice_capture<=0;
                        slice_parser_started<=0;
                        chunk_boundary_known<=0;
                        slice_row_number<=0;
                        row_byte_count<=0;
                        row_base_index<=0;
                        row_covered_count<=0;
                        proof_done<=0;
                        parse_active<=0;
                        parse_hold<=0;
                        row_waiting<=0;
                        row_final<=0;
                        probe_error<=0;
                    end
                end else picture_count<=1;
            end else if(start_code_now &&
                        (start_code_value==PICTURE_START_CODE)) begin
                picture_capture<=1;
                picture_count<=0;
                picture_shift<=0;
            end

            if(pce_capture) begin
                pce_shift<=pce_next;
                if(pce_count==4) begin
                    pce_capture<=0;
                    pce_count<=0;
                    q_scale_type<=pce_next[12];
                    alternate_scan<=pce_next[10];
                    p_intra_vlc_format<=pce_next[11];
                    p_forward_f_code_horizontal<=pce_next[35:32];
                    p_forward_f_code_vertical<=pce_next[31:28];
                    wide_candidate<=
                        geometry_supported &&
                        current_picture_is_p &&
                        (pce_next[39:36]==4'h8) &&
                        (pce_next[35:32]>=4'd1) &&
                        (pce_next[35:32]<=4'd4) &&
                        (pce_next[31:28]>=4'd1) &&
                        (pce_next[31:28]<=4'd4) &&
                        (pce_next[17:16]==2'b11) &&
                        pce_next[14] &&
                        !pce_next[13];
                end else pce_count<=pce_count+1'b1;
            end else if(current_picture_is_p &&
                        start_code_now &&
                        (start_code_value==EXTENSION_START_CODE)) begin
                pce_capture<=1;
                pce_count<=0;
                pce_shift<=0;
            end

            if(!parse_active && !proof_done && slice_capture) begin
                if(start_code_now) begin
                    if(row_byte_count<3) begin
                        slice_capture<=0;
                        slice_parser_started<=0;
                        proof_done<=1;
                        probe_error<=1;
                    end else if(
                        (start_code_value=={2'd0,slice_row_number}) ||
                        ((slice_row_number<picture_mb_height) &&
                         (start_code_value==
                            ({2'd0,slice_row_number}+8'd1)))
                    ) begin
                        // kate - Commit 173: preserve whether the already-seen
                        // following slice stays on this row while the buffered
                        // current slice is parsed under backpressure.
                        slice_capture<=
                            (start_code_value=={2'd0,slice_row_number});
                        parse_active<=1;
                        parse_hold<=1;
                        chunk_boundary_known<=1;
                        boundary_final<=0;
                        parse_byte_limit<=row_byte_count-3;
                        if(!slice_parser_started) begin
                            slice_parser_started<=1;
                            init_row_parser();
                        end else begin
                            parse_byte_index<=0;
                            parse_bit_index<=3'd7;
                        end
                    end else if(
                        (slice_row_number==picture_mb_height) &&
                        post_p_boundary_now
                    ) begin
                        slice_capture<=0;
                        parse_active<=1;
                        parse_hold<=1;
                        chunk_boundary_known<=1;
                        boundary_final<=1;
                        parse_byte_limit<=row_byte_count-3;
                        if(!slice_parser_started) begin
                            slice_parser_started<=1;
                            init_row_parser();
                        end else begin
                            parse_byte_index<=0;
                            parse_bit_index<=3'd7;
                        end
                    end else begin
                        slice_capture<=0;
                        proof_done<=1;
                        probe_error<=1;
                    end
                end else if(row_byte_count<(ROW_BUFFER_BYTES-1)) begin
                    row_bytes[row_byte_count]<=stream_data;
                    row_byte_count<=row_byte_count+1'b1;
                end else begin
                    // Fill the final byte, parse through byte 509, and retain
                    // bytes 510..511 as start-code overlap for the next window.
                    row_bytes[row_byte_count]<=stream_data;
                    slice_capture<=0;
                    parse_active<=1;
                    parse_hold<=1;
                    chunk_boundary_known<=0;
                    parse_byte_limit<=ROW_BUFFER_BYTES-2;
                    if(!slice_parser_started) begin
                        slice_parser_started<=1;
                        init_row_parser();
                    end else begin
                        parse_byte_index<=0;
                        parse_bit_index<=3'd7;
                    end
                end
            end else if(!parse_active && !proof_done &&
                        wide_candidate && slice_start_now) begin
                if(start_code_value==8'h01) begin
                    slice_capture<=1;
                    slice_parser_started<=0;
                    chunk_boundary_known<=0;
                    slice_row_number<=1;
                    row_byte_count<=0;
                    row_base_index<=0;
                    row_covered_count<=0;
                end else begin
                    proof_done<=1;
                    probe_error<=1;
                end
            end
        end
    end
end

endmodule
