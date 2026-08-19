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

        if(residual_load)begin residual_load<=0;residual_load_wait<=1;end
        if(residual_load_wait)begin
            residual_load_wait<=0;pred_sum<=0;tap_index<=0;pixel_setup<=1;
        end

        if(pixel_setup) begin
            pixel_setup<=0;
            if(mb_direction==0)begin
                if(!residual_hit)begin error<=1;if(!error)error_source<=5'd11;active<=0;persisted_seen<=1;timeout<=0;end
                else begin out_reg<=reconstructed_intra;emit<=1;end
            end else if(!source_bounds_ok)begin error<=1;if(!error)error_source<=5'd11;active<=0;persisted_seen<=1;timeout<=0;end
            else begin
                if(half_x||half_y)half_sample_seen<=1;
                req_kind<=0;
                lookup_wait<=1;
            end
        end

        if(lookup_wait&&ddram_lookup_ready) begin
            if(ddram_lookup_hit) begin
                if(tap_last) begin
                    lookup_wait<=0;
                    if((mb_direction==2'd3)&&!pred_direction) begin
                        forward_prediction<=lookup_selected_prediction;
                        pred_direction<=1;pred_sum<=0;tap_index<=0;
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
        if(req&&!ddram_busy)begin req<=0;waitresp<=1;tap_byte_sel<=src_x_tap[2:0];end

        if(ddram_dout_ready) begin
            if(!waitresp)begin error<=1;if(!error)error_source<=5'd12;end
            else begin
                waitresp<=0;
                if(!req_kind) begin
                    if(tap_last) begin
                        if((mb_direction==2'd3)&&!pred_direction) begin
                            forward_prediction<=selected_prediction;pred_direction<=1;pred_sum<=0;tap_index<=0;
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
                    end else begin pred_sum<=pred_sum_with_current;tap_index<=tap_index+1'b1;req<=1;end
                end else begin
                    if(ddram_dout!=resrows[verify_row])begin error<=1;if(!error)error_source<=5'd13;end
                    if(verify_row==7) begin
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
                    end else begin verify_row<=verify_row+1'b1;req<=1;end
                end
            end
        end

        if(emit) begin
            resrows[er][{el,3'b000}+:8]<=out_reg;emit<=0;
            if(ei==63)wait_store<=1;
            else begin
                ei<=ei+1'b1;
                pred_direction<=0;
                pred_sum<=0;
                tap_index<=0;
                if(next_pixel_early_lookup) begin
                    req_kind<=0;
                    lookup_wait<=1;
                end else begin
                    pixel_setup<=1;
                end
            end
        end

        if(wait_store&&store_block_stored)begin wait_store<=0;req_kind<=1;verify_row<=0;req<=1;end
    end
end
endmodule
