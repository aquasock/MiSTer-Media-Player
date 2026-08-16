            end
            S_FY_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_fy<=reconstruct_mv_f3(fpy,motion_code_pending,motion_residual_next);motion_residual_count<=0;motion_bits<=0;motion_len<=0;if(current_direction==2'd3)state<=S_BX;else if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else motion_residual_count<=1;end end
            S_BX: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_bx<=bpx;state<=S_BY;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_BX_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_BX_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_bx<=reconstruct_mv_f3(bpx,motion_code_pending,motion_residual_next);motion_residual_count<=0;motion_bits<=0;motion_len<=0;state<=S_BY;end else motion_residual_count<=1;end end
            S_BY: begin
                if(parser_at_end)state<=S_ERROR;
                else if(motion_match[6])begin motion_code_pending<=$signed(motion_match[5:0]);motion_bits<=0;motion_len<=0;if($signed(motion_match[5:0])==0)begin cur_by<=bpy;if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else begin motion_residual_shift<=0;motion_residual_count<=0;state<=S_BY_RES;end end
                else if(motion_len_next==11)state<=S_ERROR;else begin motion_bits<=motion_bits_next;motion_len<=motion_len_next;end
            end
            S_BY_RES: begin if(parser_at_end)state<=S_ERROR;else begin motion_residual_shift<=motion_residual_next;if(motion_residual_count)begin cur_by<=reconstruct_mv_f3(bpy,motion_code_pending,motion_residual_next);motion_residual_count<=0;if(current_pattern)begin cbp_bits<=0;cbp_len<=0;state<=S_CBP;end else state<=S_MB_DONE;end else motion_residual_count<=1;end end
            S_CBP: begin
                if(parser_at_end)state<=S_ERROR;
                else if(cbp_match[6]) begin
                    current_cbp<=cbp_match[5:0];cbp_bits<=0;cbp_len<=0;current_block_index<=0;
                    if(cbp_match[5:0]==0)state<=S_ERROR;else state<=S_BLOCK;
                end else if(cbp_len_next>=9)state<=S_ERROR;
                else begin cbp_bits<=cbp_bits_next;cbp_len<=cbp_len_next;end
            end
            S_BLOCK: begin
                if(current_block_index==3'd6)state<=S_MB_DONE;
                else if(current_cbp[5-current_block_index]) begin
                    if(residual_count>=MAX_RESIDUAL_BLOCKS)state<=S_ERROR;
                    else begin
                        residual_mb[residual_count[3:0]]<=current_map_index;
                        residual_block[residual_count[3:0]]<=current_block_index;
                        residual_qscale[residual_count[3:0]]<=current_qscale;
                        residual_count<=residual_count+1'b1;
                        qfs_index<=0;coeff_vlc_code<=0;coeff_vlc_len<=0;current_block_has_coeff<=0;
                        state<=S_FIRST_COEFF;
                    end
                end else current_block_index<=current_block_index+1'b1;
            end
            S_FIRST_COEFF: begin
                if(parser_at_end)state<=S_ERROR;
                else if(parser_current_bit) begin
                    coeff_run_pending<=0;coeff_level_pending<=1;state<=S_COEFF_SIGN;
                end else begin coeff_vlc_code<=0;coeff_vlc_len<=5'd1;state<=S_COEFF_VLC;end
            end
            S_COEFF_VLC: begin
                if(parser_at_end)state<=S_ERROR;
                else if(coeff_vlc_match) begin
                    coeff_vlc_code<=0;coeff_vlc_len<=0;
                    if(coeff_vlc_eob) begin
                        if(!current_block_has_coeff||(residual_coeff_count==0))state<=S_ERROR;
                        else begin
                            residual_coeff_last[residual_coeff_count-1'b1]<=1'b1;
                            current_block_index<=current_block_index+1'b1;state<=S_BLOCK;
                        end
                    end else if(coeff_vlc_escape) begin
                        escape_run_shift<=0;escape_run_bit_count<=0;state<=S_ESCAPE_RUN;
                    end else begin
                        coeff_run_pending<=coeff_vlc_run;coeff_level_pending<=coeff_vlc_level;state<=S_COEFF_SIGN;
                    end
                end else if(coeff_vlc_len_next>=16)state<=S_ERROR;
                else begin coeff_vlc_code<=coeff_vlc_code_next;coeff_vlc_len<=coeff_vlc_len_next;end
            end
            S_COEFF_SIGN: begin
                if(parser_at_end||(normal_target_index>63)||(residual_coeff_count>=MAX_COEFF_EVENTS))state<=S_ERROR;
                else begin
                    residual_coeff_index[residual_coeff_count[5:0]]<=normal_target_index[5:0];
                    residual_coeff_value[residual_coeff_count[5:0]]<=parser_current_bit?-$signed({7'd0,coeff_level_pending}):$signed({7'd0,coeff_level_pending});
                    residual_coeff_last[residual_coeff_count[5:0]]<=0;
                    residual_coeff_count<=residual_coeff_count+1'b1;
                    qfs_index<={1'b0,normal_target_index[5:0]}+7'd1;current_block_has_coeff<=1;
                    coeff_vlc_code<=0;coeff_vlc_len<=0;state<=S_COEFF_VLC;
                end
            end
            S_ESCAPE_RUN: begin
                if(parser_at_end)state<=S_ERROR;
                else begin escape_run_shift<=escape_run_next;if(escape_run_bit_count==5)begin escape_run_bit_count<=0;escape_level_shift<=0;escape_level_bit_count<=0;state<=S_ESCAPE_LEVEL;end else escape_run_bit_count<=escape_run_bit_count+1'b1;end
            end
            S_ESCAPE_LEVEL: begin
                if(parser_at_end)state<=S_ERROR;
                else begin
                    escape_level_shift<=escape_level_next;
                    if(escape_level_bit_count==11) begin
                        if((escape_level_next==12'h000)||(escape_level_next==12'h800)||(escape_target_index>63)||(residual_coeff_count>=MAX_COEFF_EVENTS))state<=S_ERROR;
                        else begin
                            residual_coeff_index[residual_coeff_count[5:0]]<=escape_target_index[5:0];
                            residual_coeff_value[residual_coeff_count[5:0]]<={escape_level_signed[11],escape_level_signed};
                            residual_coeff_last[residual_coeff_count[5:0]]<=0;
                            residual_coeff_count<=residual_coeff_count+1'b1;
                            qfs_index<={1'b0,escape_target_index[5:0]}+7'd1;current_block_has_coeff<=1;
                            coeff_vlc_code<=0;coeff_vlc_len<=0;state<=S_COEFF_VLC;
                        end
                    end else escape_level_bit_count<=escape_level_bit_count+1'b1;
                end
            end
            S_MB_DONE: begin
                sideband_valid<=1;sideband_index<=direction_index(current_direction);sideband_value<=$signed({cur_fx,cur_fy});
                if(!geometry_sent)state<=S_GEOMETRY;else state<=S_MB_B;
            end
            S_GEOMETRY: begin
                sideband_valid<=1;sideband_index<=6'h3c;sideband_value<=$signed({4'd0,picture_mb_width,picture_mb_height});geometry_sent<=1;state<=S_MB_B;
            end
            S_MB_B: begin
                sideband_valid<=1;sideband_index<=6'h3b;sideband_value<=$signed({cur_bx,cur_by});
                if(current_direction[0])begin fpx<=cur_fx;fpy<=cur_fy;end
                if(current_direction[1])begin bpx<=cur_bx;bpy<=cur_by;end
                last_direction<=current_direction;row_has_coded_mb<=1;
                if(current_col==picture_mb_width-1'b1)state<=S_STUFF;
                else begin current_col<=current_col+1'b1;mba_bits<=0;mba_len<=0;state<=S_MBA;end
            end
            S_STUFF: begin if(parser_at_end)state<=S_SUCCESS;else if(parser_current_bit)state<=S_ERROR;end
            S_SUCCESS: begin
                parse_active<=0;
                if(!row_has_coded_mb||(current_col!=picture_mb_width-1'b1))begin parser_error<=1;proof_done<=1;parse_hold<=0;end
                else if(boundary_final)begin
                    proof_done<=1;transform_slot<=0;t_coeff_read_index<=0;t_sample_count<=0;replay_slot<=0;replay_sample<=0;replay_active<=1;
                    if(residual_count!=0)rstate<=R_TSTART;else begin if(residual_coeff_count!=0)replay_error<=1;rstate<=R_FINISH;end
                end else begin
