                    end else begin
                        coeff_run_pending<=coeff_vlc_run; coeff_level_pending<=coeff_vlc_level; parser_state<=R_COEFF_SIGN;
                    end
                end else if(coeff_vlc_len_next>=5'd16) parser_state<=R_ERROR;
                else begin coeff_vlc_code<=coeff_vlc_code_next; coeff_vlc_len<=coeff_vlc_len_next; end
            end
            R_COEFF_SIGN: begin
                if(parser_at_end || normal_target_index>8'd63 || residual_coeff_count>=MAX_COEFF_EVENTS) parser_state<=R_ERROR;
                else begin
                    residual_coeff_index_plan[(residual_coeff_count*6)+:6]<=normal_target_index[5:0];
                    residual_coeff_value_plan[(residual_coeff_count*13)+:13]<=parser_current_bit ?
                        -$signed({7'd0,coeff_level_pending}) : $signed({7'd0,coeff_level_pending});
                    residual_coeff_count<=residual_coeff_count+1'b1;
                    qfs_index<={1'b0,normal_target_index[5:0]}+7'd1;
                    current_block_has_coeff<=1; coeff_vlc_code<=0; coeff_vlc_len<=0; parser_state<=R_COEFF_VLC;
                end
            end
            R_ESCAPE_RUN: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    escape_run_shift<=escape_run_next;
                    if(escape_run_bit_count==3'd5) begin escape_run_bit_count<=0; escape_level_shift<=0; escape_level_bit_count<=0; parser_state<=R_ESCAPE_LEVEL; end
                    else escape_run_bit_count<=escape_run_bit_count+1'b1;
                end
            end
            R_ESCAPE_LEVEL: begin
                if(parser_at_end) parser_state<=R_ERROR;
                else begin
                    escape_level_shift<=escape_level_next;
                    if(escape_level_bit_count==4'd11) begin
                        if((escape_level_next==12'h000)||(escape_level_next==12'h800)||(escape_target_index>8'd63)||(residual_coeff_count>=MAX_COEFF_EVENTS)) parser_state<=R_ERROR;
                        else begin
                            residual_coeff_index_plan[(residual_coeff_count*6)+:6]<=escape_target_index[5:0];
                            residual_coeff_value_plan[(residual_coeff_count*13)+:13]<={escape_level_signed[11],escape_level_signed};
                            residual_coeff_count<=residual_coeff_count+1'b1;
                            qfs_index<={1'b0,escape_target_index[5:0]}+7'd1;
                            current_block_has_coeff<=1; coeff_vlc_code<=0; coeff_vlc_len<=0; parser_state<=R_COEFF_VLC;
                        end
                    end else escape_level_bit_count<=escape_level_bit_count+1'b1;
                end
            end

            R_MB_DONE: begin
                motion_x_plan[(current_map_index*8)+:8]<=current_motion_x;
                motion_y_plan[(current_map_index*8)+:8]<=current_motion_y;
                if((current_motion_x==8'sd32)&&(current_motion_y==0)) aligned_shift_right_map[current_map_index]<=1'b1;
                if(current_has_motion) begin predictor_x<=current_motion_x; predictor_y<=current_motion_y; end
                row_has_coded_mb<=1;
                if(current_col==(MB_WIDTH-1'b1)) parser_state<=R_STUFF;
                else begin mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; parser_state<=R_MBA; end
            end
            R_STUFF: begin
                if(parser_at_end) parser_state<=R_SUCCESS;
                else if(parser_current_bit) parser_state<=R_ERROR;
            end
            R_SUCCESS: begin
                parse_active<=0;
                if(!row_has_coded_mb || (current_col!=(MB_WIDTH-1'b1))) begin probe_error<=1; proof_done<=1; parse_hold<=0; end
                else if(boundary_final) begin aligned_seen<=1; aligned_complete_now<=1; proof_done<=1; final_release_pending<=1; end
                else begin slice_row_number<=slice_row_number+1'b1; row_byte_count<=0; slice_capture<=1; parse_hold<=0; end
            end
            default: begin parse_active<=0; parse_hold<=0; proof_done<=1; probe_error<=1; aligned_candidate<=0; end
            endcase
        end

        if(stream_valid) begin
            byte_window<=byte_window_next;
            if(sequence_capture) begin
                sequence_shift<=sequence_next;
                if(sequence_count==2) begin
                    sequence_capture<=0; sequence_count<=0;
                    geometry_128x96<=(sequence_next[23:12]==12'd128)&&(sequence_next[11:0]==12'd96);
                end else sequence_count<=sequence_count+1'b1;
            end else if(start_code_now&&(start_code_value==SEQUENCE_HEADER_CODE)) begin
                sequence_capture<=1; sequence_count<=0; sequence_shift<=0;
            end

            if(picture_capture) begin
                picture_shift<=picture_next;
                if(picture_count) begin
                    picture_capture<=0; picture_count<=0; current_picture_is_p<=(picture_next[5:3]==3'd2);
                    if(aligned_seen&&(picture_next[5:3]==3'd2)) begin
                        aligned_candidate<=1; aligned_seen<=0; aligned_shift_right_map<=0; motion_x_plan<=0; motion_y_plan<=0;
                        residual_block_plan<=0; residual_block_count<=0; residual_present<=0;
                        residual_coeff_index_plan<=0; residual_coeff_value_plan<=0; residual_coeff_last_plan<=0;
                        residual_coeff_count<=0; residual_qscale_plan<=0;
                        slice_capture<=0; slice_row_number<=0; row_byte_count<=0; proof_done<=0; parse_active<=0; parse_hold<=0;
                    end else aligned_candidate<=0;
                end else picture_count<=1;
            end else if(start_code_now&&(start_code_value==PICTURE_START_CODE)) begin
                picture_capture<=1; picture_count<=0; picture_shift<=0;
            end

            if(pce_capture) begin
                pce_shift<=pce_next;
                if(pce_count==4) begin
                    pce_capture<=0; pce_count<=0;
                    q_scale_type<=pce_next[12]; alternate_scan<=pce_next[10];
                    aligned_candidate<=geometry_128x96 && current_picture_is_p &&
                        (pce_next[39:36]==4'h8) &&
                        (pce_next[35:32]==4'd3) && (pce_next[31:28]==4'd3) &&
                        (pce_next[17:16]==2'b11) && pce_next[14] && !pce_next[13];
                end else pce_count<=pce_count+1'b1;
            end else if(current_picture_is_p&&start_code_now&&(start_code_value==EXTENSION_START_CODE)) begin
                pce_capture<=1; pce_count<=0; pce_shift<=0;
            end

            if(!parse_active&&!proof_done&&slice_capture) begin
                if(start_code_now) begin
                    if(row_byte_count<3) begin slice_capture<=0; proof_done<=1; probe_error<=1; end
                    else if(slice_row_number<MB_HEIGHT) begin
                        if(start_code_value==({2'd0,slice_row_number}+8'd1)) begin
                            slice_capture<=0; parse_active<=1; parse_hold<=1; boundary_final<=0; parse_byte_limit<=row_byte_count-3;
                            parse_byte_index<=0; parse_bit_index<=3'd7; parser_state<=R_H_QSCALE;
                            field_bit_count<=0; qscale_shift<=0; extra_info_count<=0;
                            mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; mba_increment<=0;
                            previous_col<=-8'sd1; current_col<=0; row_has_coded_mb<=0;
                            predictor_x<=0; predictor_y<=0; current_motion_x<=0; current_motion_y<=0;
                            mbtype_bits<=0; mbtype_len<=0; motion_vlc_bits<=0; motion_vlc_len<=0;
                            cbp_vlc_bits<=0; cbp_vlc_len<=0; current_cbp<=0; current_block_index<=0;
                        end else begin slice_capture<=0; proof_done<=1; probe_error<=1; end
                    end else if(post_p_boundary_now) begin
                        slice_capture<=0; parse_active<=1; parse_hold<=1; boundary_final<=1; parse_byte_limit<=row_byte_count-3;
                        parse_byte_index<=0; parse_bit_index<=3'd7; parser_state<=R_H_QSCALE;
                        field_bit_count<=0; qscale_shift<=0; extra_info_count<=0;
                        mba_vlc_bits<=0; mba_vlc_len<=0; mba_escape_accum<=0; mba_increment<=0;
                        previous_col<=-8'sd1; current_col<=0; row_has_coded_mb<=0;
                        predictor_x<=0; predictor_y<=0; current_motion_x<=0; current_motion_y<=0;
                        mbtype_bits<=0; mbtype_len<=0; motion_vlc_bits<=0; motion_vlc_len<=0;
                        cbp_vlc_bits<=0; cbp_vlc_len<=0; current_cbp<=0; current_block_index<=0;
                    end else begin slice_capture<=0; proof_done<=1; probe_error<=1; end
                end else if(row_byte_count<ROW_BUFFER_BYTES) begin row_bytes[row_byte_count]<=stream_data; row_byte_count<=row_byte_count+1'b1; end
                else begin slice_capture<=0; proof_done<=1; probe_error<=1; end
            end else if(!parse_active&&!proof_done&&aligned_candidate&&slice_start_now) begin
                if(start_code_value==8'h01) begin
                    slice_capture<=1; slice_row_number<=1; row_byte_count<=0;
                    aligned_shift_right_map<=0; motion_x_plan<=0; motion_y_plan<=0;
                    residual_block_plan<=0; residual_block_count<=0; residual_present<=0;
                    residual_coeff_index_plan<=0; residual_coeff_value_plan<=0; residual_coeff_last_plan<=0;
                    residual_coeff_count<=0; residual_qscale_plan<=0;
                end else begin proof_done<=1; probe_error<=1; end
            end
        end
    end
end

endmodule
