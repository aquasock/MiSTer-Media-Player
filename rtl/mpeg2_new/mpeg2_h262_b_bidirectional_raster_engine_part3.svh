                else begin
                    current_desc_slot<=desc_count[10:0];
                    desc_mem[desc_count[10:0]]<=sideband_value[13:0];
                    last_desc_word<=sideband_value[13:0];
                    desc_count<=desc_count+1'b1;desc_active<=1;sample_expected<=0;
                end
            end else if((sideband_index==6'h3f)&&
                        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF))) begin
                if((motion_count==row_motion_base)||motion_first_pending||metadata_done||!geometry_seen||
                   (motion_count!=(row_motion_base+{5'd0,mb_width}))||
                   ((sideband_value==16'shA3FF)&&(exec_row+1'b1!=mb_height))||
                   ((sideband_value==16'shA3FE)&&(exec_row+1'b1>=mb_height)))begin error<=1;if(!error)error_source<=5'd6;end
                else begin metadata_done<=1;row_motion_end<=motion_count;row_final_latched<=(sideband_value==16'shA3FF);end
            end else begin error<=1;if(!error)error_source<=5'd7;end
        end

        if(request&&!started)pending<=1;
        if(pending&&!started&&metadata_done) begin
            pending<=0;started<=1;active<=1;future_bank_latched<=future_reference_bank;scratch_bank_latched<=scratch_frame_bank;timeout<=26'h3ffffff;lookup_wait<=0;
            mbi<=row_motion_base;col<=0;mrow<=exec_row;blk<=0;ei<=0;exec_desc_slot<=0;pred_direction<=0;motion_load<=1;pixel_setup<=0;residual_load<=0;residual_load_wait<=0;persisted_seen<=0;
            if(!reference_valid||!geometry_ok||(motion_count==0))begin error<=1;if(!error)error_source<=5'd8;active<=0;persisted_seen<=1;timeout<=0;motion_load<=0;end
        end

        if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)begin error<=1;if(!error)error_source<=5'd9;end end

        if(motion_load) begin
            motion_load<=0;
            if((mbi>=row_motion_end)||(mbi>=motion_count)||(mbi>=MAX_MB))begin error<=1;if(!error)error_source<=5'd10;active<=0;persisted_seen<=1;timeout<=0;end
            else begin motion_word<=motion_mem[mbi];residual_load<=1;end
        end

        if(residual_load)begin
            residual_load<=0;residual_load_wait<=1;
            exec_direction<=mb_direction;
            if(blk<4) begin
                exec_fmvx<=mb_fmvx;exec_fmvy<=mb_fmvy;
                exec_bmvx<=mb_bmvx;exec_bmvy<=mb_bmvy;
                phase_mvx<=(mb_direction==2'd2)?mb_bmvx:mb_fmvx;
                phase_mvy<=(mb_direction==2'd2)?mb_bmvy:mb_fmvy;
            end else begin
                exec_fmvx<=chroma_half_vector(mb_fmvx);
                exec_fmvy<=chroma_half_vector(mb_fmvy);
                exec_bmvx<=chroma_half_vector(mb_bmvx);
                exec_bmvy<=chroma_half_vector(mb_bmvy);
                phase_mvx<=chroma_half_vector(
                    (mb_direction==2'd2)?mb_bmvx:mb_fmvx);
                phase_mvy<=chroma_half_vector(
                    (mb_direction==2'd2)?mb_bmvy:mb_fmvy);
            end
            phase_backward<=(mb_direction==2'd2);
        end
        if(residual_load_wait)begin
            residual_load_wait<=0;pred_sum<=0;tap_index<=0;pixel_setup<=1;
            phase_base_addr<=computed_phase_base_addr;
            phase_base_byte<=src_base_x[2:0];
            phase_row_words<=(blk<4)?7'd90:7'd45;
            phase_bounds_ok<=source_bounds_ok;
        end

        if(pixel_setup||precompute_after_advance) begin
            bidir_prelaunch_addr<=precompute_bidir_addr;
            bidir_prelaunch_byte<=precompute_bidir_src_x[2:0];
            bidir_prelaunch_valid<=
                (exec_direction==2'd3)&&precompute_bidir_bounds_ok;
            next_prelaunch_addr<=precompute_next_addr;
            next_prelaunch_byte<=precompute_next_src_x[2:0];
            next_prelaunch_valid<=
                (exec_direction!=0)&&precompute_next_bounds_ok;
        end

        if(pixel_setup) begin
            pixel_setup<=0;
            if(exec_direction==0)begin
                if(!residual_hit)begin error<=1;if(!error)error_source<=5'd11;active<=0;persisted_seen<=1;timeout<=0;end
                else begin out_reg<=reconstructed_intra;emit<=1;end
            end else if(!phase_bounds_ok)begin error<=1;if(!error)error_source<=5'd11;active<=0;persisted_seen<=1;timeout<=0;end
            else begin
                if(half_x||half_y)half_sample_seen<=1;
                lookup_wait<=1;
            end
        end

        if(lookup_wait&&ddram_lookup_ready) begin
            if(ddram_lookup_hit) begin
                if(tap_last) begin
                    lookup_wait<=0;
                    if((exec_direction==2'd3)&&!pred_direction) begin
                        forward_prediction<=lookup_selected_prediction;
                        pred_direction<=1;pred_sum<=0;tap_index<=0;
                        phase_mvx<=exec_bmvx;phase_mvy<=exec_bmvy;
                        phase_backward<=1;
                        phase_base_addr<=bidir_prelaunch_addr;
                        phase_base_byte<=bidir_prelaunch_byte;
                        phase_bounds_ok<=bidir_prelaunch_valid;
                        if(bidir_early_lookup) begin
                            if(early_half_x||early_half_y)
                                half_sample_seen<=1;
                            lookup_wait<=1;
                        end else begin
                            pixel_setup<=1;
                        end
                    end else begin
                        out_reg<=lookup_reconstructed_current;emit<=1;
                        if((mbi==0)&&(blk==0)&&(ei==0))begin
                            read_seen<=1;
                            sample_nonzero<=|lookup_final_prediction;
                        end
                    end
                end else begin
                    pred_sum<=lookup_pred_sum_with_current;
                    tap_index<=tap_index+1'b1;
                end
            end else begin lookup_wait<=0;req<=1;end
        end

        // kate - Commit 182: latch the returned-word byte select in the same
        // cycle the address is presented to DDR, so both come from one
        // evaluation of src_x_tap.
        if(req&&!ddram_busy)begin req<=0;waitresp<=1;tap_byte_sel<=phase_tap_byte;end

        if(ddram_dout_ready) begin
            if(!waitresp)begin error<=1;if(!error)error_source<=5'd12;end
            else begin
                waitresp<=0;
                if(tap_last) begin
                    if((exec_direction==2'd3)&&!pred_direction) begin
                        forward_prediction<=selected_prediction;pred_direction<=1;pred_sum<=0;tap_index<=0;
                        phase_mvx<=exec_bmvx;phase_mvy<=exec_bmvy;
                        phase_backward<=1;
                        phase_base_addr<=bidir_prelaunch_addr;
                        phase_base_byte<=bidir_prelaunch_byte;
                        phase_bounds_ok<=bidir_prelaunch_valid;
                        if(bidir_early_lookup) begin
                            if(early_half_x||early_half_y)
                                half_sample_seen<=1;
                            lookup_wait<=1;
                        end else begin
                            pixel_setup<=1;
                        end
                    end else begin
                        out_reg<=reconstructed_current;emit<=1;
                        if((mbi==0)&&(blk==0)&&(ei==0))begin read_seen<=1;sample_nonzero<=|final_prediction;end
                    end
                end else begin
                    pred_sum<=pred_sum_with_current;tap_index<=tap_index+1'b1;
                    if(miss_response_prelaunch&&!ddram_busy)begin
                        waitresp<=1;
                        tap_byte_sel<=miss_response_prelaunch_byte;
                    end else req<=1;
                end
            end
        end

        if(emit) begin
            emit<=0;
            if(!emit_advanced&&(ei==63))wait_store<=1;
            else if(!emit_advanced) begin
                ei<=ei+1'b1;
                pred_direction<=0;
                phase_mvx<=(exec_direction==2'd2)?exec_bmvx:exec_fmvx;
                phase_mvy<=(exec_direction==2'd2)?exec_bmvy:exec_fmvy;
                phase_backward<=(exec_direction==2'd2);
                phase_base_addr<=next_prelaunch_addr;
                phase_base_byte<=next_prelaunch_byte;
                phase_bounds_ok<=next_prelaunch_valid;
                pred_sum<=0;
                tap_index<=0;
                if(next_pixel_early_lookup) begin
                    lookup_wait<=1;
                end else begin
                    pixel_setup<=1;
                end
            end
        end

        if(pixel_completed) begin
            emit<=1;
            emit_advanced<=fast_pixel_advance;
            emit_x<={2'b11,dest_x[9:0]};
            emit_y<=(blk<4)?
                (scratch_bank_latched?{3'b001,luma_y[8:0]}:
                                      {3'b100,luma_y[8:0]}):
                (blk==4)?
                (scratch_bank_latched?{3'b010,chroma_y[8:0]}:
                                      {3'b101,chroma_y[8:0]}):
                (scratch_bank_latched?{3'b011,chroma_y[8:0]}:
                                      {3'b110,chroma_y[8:0]});
            emit_block_start<=(ei==0);
            emit_block_complete<=(ei==63);
        end

        if(fast_pixel_advance) begin
            if(ei==63)wait_store<=1;
            else begin
                ei<=ei+1'b1;
                pred_direction<=0;
                phase_mvx<=(exec_direction==2'd2)?exec_bmvx:exec_fmvx;
                phase_mvy<=(exec_direction==2'd2)?exec_bmvy:exec_fmvy;
                phase_backward<=(exec_direction==2'd2);
                phase_base_addr<=next_prelaunch_addr;
                phase_base_byte<=next_prelaunch_byte;
                phase_bounds_ok<=next_prelaunch_valid;
                pred_sum<=0;
                tap_index<=0;
                lookup_wait<=1;
            end
        end

        if(wait_store&&store_block_stored) begin
            // Entry 233: B output is display-only scratch. The writer's
            // all-eight-rows-accepted pulse is the complete persistence
            // barrier; rereading scratch cannot affect prediction.
            wait_store<=0;
            if(residual_hit)exec_desc_slot<=exec_desc_slot+1'b1;
            if(blk==5) begin
                if(col+1'b1>=mb_width) begin
                    if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=desc_count)begin error<=1;if(!error)error_source<=5'd14;end
                    if(mbi+1'b1!=row_motion_end)begin error<=1;if(!error)error_source<=5'd15;end
                    row_persisted<=1;active<=0;timeout<=0;
                    if(row_final_latched)begin persisted_seen<=1;reconstructed_seen<=1;end
                    else begin
                        started<=0;metadata_done<=0;desc_count<=0;last_desc_word<=0;current_desc_slot<=0;
                        desc_active<=0;sample_expected<=0;exec_desc_slot<=0;row_motion_base<=row_motion_end;
                        exec_row<=exec_row+1'b1;row_final_latched<=0;
                    end
                end else begin
                    mbi<=mbi+1'b1;col<=col+1'b1;
                    blk<=0;ei<=0;pred_direction<=0;motion_load<=1;
                end
            end else begin blk<=blk+1'b1;ei<=0;pred_direction<=0;residual_load<=1;end
        end
    end
end
endmodule
