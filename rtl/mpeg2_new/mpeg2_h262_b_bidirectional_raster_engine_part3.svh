                else begin
                    current_desc_slot<=desc_count[3:0];
                    desc_mb[desc_count[3:0]]<=sideband_value[13:3];
                    desc_block[desc_count[3:0]]<=sideband_value[2:0];
                    desc_count<=desc_count+1'b1;desc_active<=1;sample_expected<=0;
                end
            end else if((sideband_index==6'h3f)&&(sideband_value==16'shA3FF)) begin
                if((motion_count==0)||motion_first_pending||metadata_done||!geometry_seen)error<=1;else metadata_done<=1;
            end else error<=1;
        end

        if(request&&!started)pending<=1;
        if(pending&&!started&&metadata_done) begin
            pending<=0;started<=1;active<=1;future_bank_latched<=future_reference_bank;timeout<=26'h3ffffff;
            mbi<=0;col<=0;mrow<=0;blk<=0;ei<=0;exec_desc_slot<=0;pred_direction<=0;motion_load<=1;pixel_setup<=0;persisted_seen<=0;
            if(!reference_valid||!geometry_ok||(motion_count==0))begin error<=1;active<=0;persisted_seen<=1;timeout<=0;motion_load<=0;end
        end

        if(started&&!persisted_seen&&timeout!=0)begin timeout<=timeout-1'b1;if(timeout==1)error<=1;end

        if(motion_load) begin
            motion_load<=0;
            if((mbi>=motion_count)||(mbi>=MAX_MB))begin error<=1;active<=0;persisted_seen<=1;timeout<=0;end
            else begin motion_word<=motion_mem[mbi];pixel_setup<=1;end
        end

        if(pixel_setup) begin
            pixel_setup<=0;pred_sum<=0;tap_index<=0;
            if((mb_direction==0)||!source_bounds_ok)begin error<=1;active<=0;persisted_seen<=1;timeout<=0;end
            else begin if(half_x||half_y)half_sample_seen<=1;req_kind<=0;req<=1;end
        end

        if(req&&!ddram_busy)begin req<=0;waitresp<=1;end

        if(ddram_dout_ready) begin
            if(!waitresp)error<=1;
            else begin
                waitresp<=0;
                if(!req_kind) begin
                    if(tap_last) begin
                        if((mb_direction==2'd3)&&!pred_direction) begin
                            forward_prediction<=selected_prediction;pred_direction<=1;pred_sum<=0;tap_index<=0;pixel_setup<=1;
                        end else begin
                            out_reg<=reconstructed_current;emit<=1;
                            if((mbi==0)&&(blk==0)&&(ei==0))begin read_seen<=1;sample_nonzero<=|final_prediction;end
                        end
                    end else begin pred_sum<=pred_sum_with_current;tap_index<=tap_index+1'b1;req<=1;end
                end else begin
                    if(ddram_dout!=resrows[verify_row])error<=1;
                    if(verify_row==7) begin
                        if(residual_hit)exec_desc_slot<=exec_desc_slot+1'b1;
                        if(blk==5) begin
                            if((col+1'b1>=mb_width)&&(mrow+1'b1>=mb_height)) begin
                                if((exec_desc_slot+(residual_hit?1'b1:1'b0))!=desc_count)error<=1;
                                if(mbi+1'b1!=motion_count)error<=1;
                                persisted_seen<=1;reconstructed_seen<=1;active<=0;timeout<=0;
                            end else begin
                                mbi<=mbi+1'b1;if(col+1'b1>=mb_width)begin col<=0;mrow<=mrow+1'b1;end else col<=col+1'b1;
                                blk<=0;ei<=0;pred_direction<=0;motion_load<=1;
                            end
                        end else begin blk<=blk+1'b1;ei<=0;pred_direction<=0;pixel_setup<=1;end
                    end else begin verify_row<=verify_row+1'b1;req<=1;end
                end
            end
        end

        if(emit) begin
            resrows[er][{el,3'b000}+:8]<=out_reg;emit<=0;
            if(ei==63)wait_store<=1;else begin ei<=ei+1'b1;pred_direction<=0;pixel_setup<=1;end
        end

        if(wait_store&&store_block_stored)begin wait_store<=0;req_kind<=1;verify_row<=0;req<=1;end
    end
end
endmodule
