        motion_event_valid<=0;
        if(final_release_pending) begin
            parse_hold<=0;
            final_release_pending<=0;
        end

        if(parse_active) begin
            if(parser_at_end && !chunk_boundary_known) begin
                // Commit 198: preserve the syntax FSM and the final two bytes,
                // then release upstream long enough to refill this window.
                parse_active<=0;
                parse_hold<=0;
                slice_capture<=1;
                row_bytes[0]<=row_bytes[ROW_BUFFER_BYTES-2];
                row_bytes[1]<=row_bytes[ROW_BUFFER_BYTES-1];
                row_byte_count<=9'd2;
                parse_byte_index<=0;
                parse_bit_index<=3'd7;
            end else begin
            if(parser_consume_bit) begin
                if(parse_bit_index==0) begin
                    parse_bit_index<=3'd7;
                    parse_byte_index<=parse_byte_index+1'b1;
                end else begin
                    parse_bit_index<=parse_bit_index-1'b1;
                end
            end

            case(parser_state)
            R_H_QSCALE: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    qscale_shift<=qscale_next;
                    if(field_bit_count==3'd4) begin
                        field_bit_count<=0;
                        if(qscale_next==0) parser_state<=R_ERROR;
                        else begin
                            current_qscale<=qscale_next;
                            parser_state<=R_H_EXTRA_FLAG;
                        end
                    end else field_bit_count<=field_bit_count+1'b1;
                end
            end

            R_H_EXTRA_FLAG: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(parser_current_bit) begin
                    extra_info_count<=0;
                    parser_state<=R_H_EXTRA_INFO;
                end else begin
                    mba_vlc_bits<=0;
                    mba_vlc_len<=0;
                    mba_escape_accum<=0;
                    parser_state<=R_MBA;
                end
            end

            R_H_EXTRA_INFO: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(extra_info_count==4'd7) begin
                    extra_info_count<=0;
                    parser_state<=R_H_EXTRA_FLAG;
                end else extra_info_count<=extra_info_count+1'b1;
            end

            R_MBA: begin
                // kate - Commit 173: after a coded slice endpoint the buffered
                // payload can end immediately or with only byte-alignment zeroes.
                // A non-zero/incomplete MBA or an unterminated escape remains an error.
                if(parser_at_end) begin
                    if(row_has_coded_mb &&
                       (mba_vlc_bits==0) &&
                       (mba_escape_accum==0))
                        parser_state<=R_SUCCESS;
                    else
                        parser_state<=R_ERROR;
                end else if(mba_escape_match) begin
                    if(mba_escape_accum>10'd957) parser_state<=R_ERROR;
                    else begin
                        mba_escape_accum<=mba_escape_accum+10'd33;
                        mba_vlc_bits<=0;
                        mba_vlc_len<=0;
                    end
                end else if(mba_match[6]) begin
                    mba_increment<=
                        mba_escape_accum+{4'd0,mba_match[5:0]};
                    mba_vlc_bits<=0;
                    mba_vlc_len<=0;
                    mba_escape_accum<=0;
                    parser_state<=R_APPLY;
                end else if(mba_vlc_len_next==4'd11) begin
                    parser_state<=R_ERROR;
                end else begin
                    mba_vlc_bits<=mba_vlc_bits_next;
                    mba_vlc_len<=mba_vlc_len_next;
                end
            end

            R_APPLY: begin
                // STANDARDS_CONFORMANCE:H262-025. The first MBA of a P slice
                // positions its first coded macroblock from the row origin;
                // preceding positions are skipped macroblocks.  Subsequent
                // increments remain relative to previous_col.
                if((mba_increment==0) ||
                   (next_col_calc<0) ||
                   (next_col_calc>=$signed({5'd0,picture_mb_width}))) begin
                    parser_state<=R_ERROR;
                end else begin
                    current_col<=next_col_calc[5:0];
                    previous_col<=next_col_calc[7:0];
                    current_has_motion<=0;
                    current_has_pattern<=0;
                    current_has_quant<=0;
                    mbtype_bits<=0;
                    mbtype_len<=0;
                    if(mba_increment>1) begin
                        predictor_x<=0;
                        predictor_y<=0;
                        skip_emit_col<=previous_col+1'b1;
                        skip_remaining<=mba_increment[5:0]-1'b1;
                        parser_state<=R_SKIP_EMIT;
                    end else begin
                        parser_state<=R_MBTYPE;
                    end
                end
            end

            R_SKIP_EMIT: begin
                motion_event_valid<=1;
                motion_event_index<=
                    row_base_index+{5'd0,skip_emit_col};
                motion_event_x<=0;
                motion_event_y<=0;
                if(skip_remaining==1) begin
                    skip_remaining<=0;
                    parser_state<=R_MBTYPE;
                end else begin
                    skip_remaining<=skip_remaining-1'b1;
                    skip_emit_col<=skip_emit_col+1'b1;
                end
            end

            R_MBTYPE: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(mbtype_match[4]) begin
                    mbtype_bits<=0;
                    mbtype_len<=0;
                    current_has_motion<=mbtype_match[3];
                    current_has_pattern<=mbtype_match[2];
                    current_has_quant<=mbtype_match[1];
                    if(mbtype_match[0]) parser_state<=R_ERROR;
                    else if(mbtype_match[1]) begin
                        qscale_shift<=0;
                        field_bit_count<=0;
                        parser_state<=R_MB_QSCALE;
                    end else if(mbtype_match[3]) begin
                        motion_vlc_bits<=0;
                        motion_vlc_len<=0;
                        parser_state<=R_MOTION_X;
                    end else begin
                        current_motion_x<=0;
                        current_motion_y<=0;
                        predictor_x<=0;
                        predictor_y<=0;
                        if(mbtype_match[2]) begin
                            cbp_vlc_bits<=0;
                            cbp_vlc_len<=0;
                            parser_state<=R_CBP;
                        end else parser_state<=R_MB_DONE;
                    end
                end else if(mbtype_len_next==3'd6) begin
                    parser_state<=R_ERROR;
                end else begin
                    mbtype_bits<=mbtype_bits_next;
                    mbtype_len<=mbtype_len_next;
                end
            end

            R_MB_QSCALE: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    qscale_shift<=qscale_next;
                    if(field_bit_count==3'd4) begin
                        field_bit_count<=0;
                        if(qscale_next==0) parser_state<=R_ERROR;
                        else begin
                            current_qscale<=qscale_next;
                            if(current_has_motion) begin
                                motion_vlc_bits<=0;
                                motion_vlc_len<=0;
                                parser_state<=R_MOTION_X;
                            end else begin
                                current_motion_x<=0;
                                current_motion_y<=0;
                                predictor_x<=0;
                                predictor_y<=0;
                                if(current_has_pattern) begin
                                    cbp_vlc_bits<=0;
                                    cbp_vlc_len<=0;
                                    parser_state<=R_CBP;
                                end else parser_state<=R_MB_DONE;
                            end
                        end
                    end else field_bit_count<=field_bit_count+1'b1;
                end
            end

            R_MOTION_X: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(motion_match[6]) begin
                    motion_code_pending<=$signed(motion_match[5:0]);
                    motion_vlc_bits<=0;
                    motion_vlc_len<=0;
                    if($signed(motion_match[5:0])==0) begin
                        current_motion_x<=predictor_x;
                        parser_state<=R_MOTION_Y;
                    end else if(p_forward_f_code_horizontal==4'd1) begin
                        current_motion_x<=reconstruct_mv(
                            predictor_x,motion_match[5:0],3'd0,
                            p_forward_f_code_horizontal);
                        parser_state<=R_MOTION_Y;
                    end else begin
                        motion_residual_shift<=0;
                        motion_residual_count<=0;
                        parser_state<=R_MOTION_X_RES;
                    end
                end else if(motion_vlc_len_next==4'd11) begin
                    parser_state<=R_ERROR;
                end else begin
                    motion_vlc_bits<=motion_vlc_bits_next;
                    motion_vlc_len<=motion_vlc_len_next;
                end
            end

            R_MOTION_X_RES: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    motion_residual_shift<=motion_residual_next;
                    if(motion_residual_count==
                       (p_forward_f_code_horizontal-4'd2)) begin
                        current_motion_x<=reconstruct_mv(
                            predictor_x,motion_code_pending,
                            motion_residual_next,
                            p_forward_f_code_horizontal);
                        motion_residual_count<=0;
                        motion_vlc_bits<=0;
                        motion_vlc_len<=0;
                        parser_state<=R_MOTION_Y;
                    end else motion_residual_count<=
                        motion_residual_count+1'b1;
                end
            end

            R_MOTION_Y: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(motion_match[6]) begin
                    motion_code_pending<=$signed(motion_match[5:0]);
                    motion_vlc_bits<=0;
                    motion_vlc_len<=0;
                    if($signed(motion_match[5:0])==0) begin
                        current_motion_y<=predictor_y;
                        if(current_has_pattern) begin
                            cbp_vlc_bits<=0;
                            cbp_vlc_len<=0;
                            parser_state<=R_CBP;
                        end else parser_state<=R_MB_DONE;
                    end else if(p_forward_f_code_vertical==4'd1) begin
                        current_motion_y<=reconstruct_mv(
                            predictor_y,motion_match[5:0],3'd0,
                            p_forward_f_code_vertical);
                        if(current_has_pattern) begin
                            cbp_vlc_bits<=0;
                            cbp_vlc_len<=0;
                            parser_state<=R_CBP;
                        end else parser_state<=R_MB_DONE;
                    end else begin
                        motion_residual_shift<=0;
                        motion_residual_count<=0;
                        parser_state<=R_MOTION_Y_RES;
                    end
                end else if(motion_vlc_len_next==4'd11) begin
                    parser_state<=R_ERROR;
                end else begin
                    motion_vlc_bits<=motion_vlc_bits_next;
                    motion_vlc_len<=motion_vlc_len_next;
                end
            end

            R_MOTION_Y_RES: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    motion_residual_shift<=motion_residual_next;
                    if(motion_residual_count==
                       (p_forward_f_code_vertical-4'd2)) begin
                        current_motion_y<=reconstruct_mv(
                            predictor_y,motion_code_pending,
                            motion_residual_next,
                            p_forward_f_code_vertical);
                        motion_residual_count<=0;
                        if(current_has_pattern) begin
                            cbp_vlc_bits<=0;
                            cbp_vlc_len<=0;
                            parser_state<=R_CBP;
                        end else parser_state<=R_MB_DONE;
                    end else motion_residual_count<=
                        motion_residual_count+1'b1;
                end
            end

            R_CBP: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(cbp_match[6]) begin
                    current_cbp<=cbp_match[5:0];
                    cbp_vlc_bits<=0;
                    cbp_vlc_len<=0;
                    current_block_index<=0;
                    if(cbp_match[5:0]==0) parser_state<=R_ERROR;
                    else begin
                        residual_present<=1;
                        parser_state<=R_BLOCK;
                    end
                end else if(cbp_vlc_len_next==4'd9) begin
                    parser_state<=R_ERROR;
                end else begin
                    cbp_vlc_bits<=cbp_vlc_bits_next;
                    cbp_vlc_len<=cbp_vlc_len_next;
                end
            end

            R_BLOCK: begin
                if(current_block_index==3'd6) parser_state<=R_MB_DONE;
                else if(current_cbp[5-current_block_index]) begin
                    if(residual_block_count>=MAX_RESIDUAL_BLOCKS) begin
                        parser_state<=R_ERROR;
                    end else begin
                        current_residual_slot<=residual_block_count;
                        residual_mb_plan[
                            (residual_block_count*11)+:11
                        ]<=current_mb_index;
                        residual_block_index_plan[
                            (residual_block_count*3)+:3
                        ]<=current_block_index;
                        residual_qscale_plan[
                            (residual_block_count*5)+:5
                        ]<=current_qscale;
                        residual_block_count<=residual_block_count+1'b1;
                        qfs_index<=0;
                        coeff_vlc_code<=0;
                        coeff_vlc_len<=0;
                        current_block_has_coeff<=0;
                        parser_state<=R_FIRST_COEFF;
                    end
                end else begin
                    current_block_index<=current_block_index+1'b1;
                end
            end

            R_FIRST_COEFF: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else if(parser_current_bit) begin
                    coeff_run_pending<=0;
                    coeff_level_pending<=1;
                    parser_state<=R_COEFF_SIGN;
                end else begin
                    coeff_vlc_code<=0;
                    coeff_vlc_len<=5'd1;
                    parser_state<=R_COEFF_VLC;
                end
            end
