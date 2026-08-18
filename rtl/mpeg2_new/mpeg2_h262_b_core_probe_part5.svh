                        slice_row_number<=slice_row_number+1'b1;row_base_index<=row_base_index+{5'd0,picture_mb_width};row_byte_count<=0;slice_capture<=1;parse_hold<=0;
                    end
                end
            end
            default: begin parse_active<=0;parse_hold<=0;proof_done<=1;parser_error<=1;b_candidate<=0;slice_parser_started<=0;chunk_boundary_known<=0;state<=S_ERROR;end
            endcase
            end
        end

        if(replay_active&&t_valid)begin
            if(transform_slot>=MAX_RESIDUAL_BLOCKS||t_index!=t_sample_count[5:0]||t_sample_count>=64)replay_error<=1;
            else begin residual_mem[{transform_slot[3:0],6'b000000}+t_index]<=t_value;t_sample_count<=t_sample_count+1'b1;end
        end
        case(rstate)
        R_TSTART:begin t_qscale<=residual_qscale[transform_slot[3:0]];t_sample_count<=0;t_start<=1;rstate<=R_TWRITE;end
        R_TWRITE:begin
            if((t_coeff_read_index>=residual_coeff_count)||(t_coeff_read_index>=MAX_COEFF_EVENTS))begin replay_error<=1;rstate<=R_FINISH;end
            else begin
                t_we<=1;t_widx<=residual_coeff_index[t_coeff_read_index[5:0]];t_wval<=residual_coeff_value[t_coeff_read_index[5:0]];
                t_coeff_read_index<=t_coeff_read_index+1'b1;
                if(residual_coeff_last[t_coeff_read_index[5:0]])rstate<=R_TEND;
            end
        end
        R_TEND:begin t_end<=1;rstate<=R_TWAIT;end
        R_TWAIT:if(t_done)begin
            if((t_sample_count+(t_valid?1'b1:1'b0))!=64)replay_error<=1;
            if(transform_slot+1'b1>=residual_count)begin
                if(t_coeff_read_index!=residual_coeff_count)replay_error<=1;
                replay_slot<=0;rstate<=R_DESC;
            end else begin transform_slot<=transform_slot+1'b1;rstate<=R_TSTART;end
        end
        R_DESC:begin sideband_valid<=1;sideband_index<=6'h3f;sideband_value<=$signed({2'b11,desc_mb,desc_block});replay_sample<=0;rstate<=R_SAMPLE;end
        R_SAMPLE:begin
            sideband_valid<=1;sideband_index<=replay_sample;sideband_value<=residual_mem[res_mem_addr];
            if((replay_slot==0)&&(replay_sample==0))begin first_sample_valid<=1;first_sample_value<=residual_mem[res_mem_addr];end
            if(replay_sample==63)begin if(replay_slot+1'b1>=residual_count)rstate<=R_FINISH;else begin replay_slot<=replay_slot+1'b1;rstate<=R_DESC;end end
            else replay_sample<=replay_sample+1'b1;
        end
        R_FINISH:begin sideband_valid<=1;sideband_index<=6'h3f;sideband_value<=16'shA3FF;b_seen<=1;b_complete_now<=1;replay_active<=0;parse_hold<=0;rstate<=R_IDLE;end
        default:;
        endcase

        if(stream_valid) begin
            byte_window<=byte_window_next;
            if(sequence_capture)begin
                sequence_shift<=sequence_next;
                if(sequence_count==2)begin
                    sequence_capture<=0;sequence_count<=0;
                    picture_mb_width<=sequence_mb_width_next;picture_mb_height<=sequence_mb_height_next;
                    geometry_supported<=(sequence_h_next!=0)&&(sequence_v_next!=0)&&(sequence_h_next<=12'd720)&&(sequence_v_next<=12'd480)&&
                        (sequence_mb_width_next!=0)&&(sequence_mb_width_next<=6'd45)&&(sequence_mb_height_next!=0)&&(sequence_mb_height_next<=6'd30);
                end else sequence_count<=sequence_count+1'b1;
            end else if(start_code_now&&(start_code_value==SEQUENCE_HEADER_CODE))begin sequence_capture<=1;sequence_count<=0;sequence_shift<=0;end

            if(picture_capture)begin
                picture_shift<=picture_next;
                if(picture_count)begin
                    picture_capture<=0;picture_count<=0;current_picture_is_b<=(picture_next[5:3]==3'd3);
                    if((picture_next[5:3]==3'd3)&&!parse_active&&!replay_active)begin
                        prior_error<=prior_error|parser_error|replay_error;
                        proof_done<=0;b_seen<=0;b_candidate<=0;parse_hold<=0;parser_error<=0;replay_error<=0;
                        slice_capture<=0;slice_parser_started<=0;chunk_boundary_known<=0;slice_row_number<=0;row_byte_count<=0;row_base_index<=0;row_covered_count<=0;residual_count<=0;residual_coeff_count<=0;geometry_sent<=0;
                        current_col<=0;row_has_coded_mb<=0;skip_remaining<=0;last_direction<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;
                        mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;
                    end
                end else picture_count<=1;
            end else if(start_code_now&&(start_code_value==PICTURE_START_CODE))begin picture_capture<=1;picture_count<=0;picture_shift<=0;end

            if(pce_capture)begin
                pce_shift<=pce_next;
                if(pce_count==4)begin
                    pce_capture<=0;pce_count<=0;q_scale_type<=pce_next[12];alternate_scan<=pce_next[10];
                    b_forward_f_code_horizontal<=pce_next[35:32];
                    b_forward_f_code_vertical<=pce_next[31:28];
                    b_backward_f_code_horizontal<=pce_next[27:24];
                    b_backward_f_code_vertical<=pce_next[23:20];
                    b_candidate<=geometry_supported&&current_picture_is_b&&(pce_next[39:36]==4'h8)&&
                        (pce_next[35:32]>=4'd1)&&(pce_next[35:32]<=4'd4)&&
                        (pce_next[31:28]>=4'd1)&&(pce_next[31:28]<=4'd4)&&
                        (pce_next[27:24]>=4'd1)&&(pce_next[27:24]<=4'd4)&&
                        (pce_next[23:20]>=4'd1)&&(pce_next[23:20]<=4'd4)&&
                        (pce_next[17:16]==2'b11)&&pce_next[14]&&!pce_next[13];
                end else pce_count<=pce_count+1'b1;
            end else if(current_picture_is_b&&start_code_now&&(start_code_value==EXTENSION_START_CODE))begin pce_capture<=1;pce_count<=0;pce_shift<=0;end

            if(!parse_active&&!proof_done&&slice_capture)begin
                if(start_code_now)begin
                    if(row_byte_count<3)begin slice_capture<=0;slice_parser_started<=0;chunk_boundary_known<=0;proof_done<=1;parser_error<=1;end
                    else if((start_code_value=={2'd0,slice_row_number})||
                            ((slice_row_number<picture_mb_height)&&
                             (start_code_value==({2'd0,slice_row_number}+1'b1))))begin
                        // kate - Commit 173: while the current buffered slice is
                        // parsed, slice_capture retains whether the already-seen
                        // following slice remains on the same macroblock row.
                        slice_capture<=(start_code_value=={2'd0,slice_row_number});parse_active<=1;parse_hold<=1;chunk_boundary_known<=1;boundary_final<=0;parse_byte_limit<=row_byte_count-3;parse_byte_index<=0;parse_bit_index<=7;
                        if(!slice_parser_started)begin
                            slice_parser_started<=1;state<=S_QSCALE;
                            field_bit_count<=0;qscale_shift<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;last_direction<=0;mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;skip_remaining<=0;
                            cbp_bits<=0;cbp_len<=0;current_cbp<=0;current_block_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;
                        end
                    end else if((slice_row_number==picture_mb_height)&&post_b_boundary_now)begin
                        slice_capture<=0;parse_active<=1;parse_hold<=1;chunk_boundary_known<=1;boundary_final<=1;parse_byte_limit<=row_byte_count-3;parse_byte_index<=0;parse_bit_index<=7;
                        if(!slice_parser_started)begin
                            slice_parser_started<=1;state<=S_QSCALE;
                            field_bit_count<=0;qscale_shift<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;last_direction<=0;mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;skip_remaining<=0;
                            cbp_bits<=0;cbp_len<=0;current_cbp<=0;current_block_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;
                        end
                    end else begin slice_capture<=0;proof_done<=1;parser_error<=1;end
                end else if(row_byte_count<(ROW_BUFFER_BYTES-1))begin row_bytes[row_byte_count]<=stream_data;row_byte_count<=row_byte_count+1'b1;end
                else begin
                    row_bytes[row_byte_count]<=stream_data;slice_capture<=0;parse_active<=1;parse_hold<=1;chunk_boundary_known<=0;parse_byte_limit<=ROW_BUFFER_BYTES-2;parse_byte_index<=0;parse_bit_index<=7;
                    if(!slice_parser_started)begin
                        slice_parser_started<=1;state<=S_QSCALE;
                        field_bit_count<=0;qscale_shift<=0;extra_info_count<=0;current_col<=0;row_has_coded_mb<=0;last_direction<=0;mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;fpx<=0;fpy<=0;bpx<=0;bpy<=0;skip_remaining<=0;
                        cbp_bits<=0;cbp_len<=0;current_cbp<=0;current_block_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;
                    end
                end
            end else if(!parse_active&&!proof_done&&b_candidate&&slice_start_now)begin
                if(start_code_value==8'h01)begin
                    slice_capture<=1;slice_parser_started<=0;chunk_boundary_known<=0;slice_row_number<=1;row_byte_count<=0;row_base_index<=0;row_covered_count<=0;residual_count<=0;residual_coeff_count<=0;parser_error<=0;replay_error<=0;
                    geometry_sent<=0;last_direction<=0;mba_bits<=0;mba_len<=0;mba_wide_bits<=0;mba_wide_len<=0;mba_escape_accum<=0;
                end else begin proof_done<=1;parser_error<=1;end
            end
        end
    end
end
endmodule
