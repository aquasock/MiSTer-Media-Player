wire [11:0] chroma_y=({6'd0,mrow}<<3)+{9'd0,er};
wire [11:0] dest_x=(blk<4)?luma_x:chroma_x;
wire [11:0] dest_y=(blk<4)?luma_y:chroma_y;
wire signed [13:0] src_base_x=$signed({1'b0,dest_x})+$signed(exec_int_x);
wire signed [13:0] src_base_y=$signed({1'b0,dest_y})+$signed(exec_int_y);
wire [11:0] plane_width=(blk<4)?padded_luma_width:padded_chroma_width;
wire [11:0] plane_height=(blk<4)?padded_luma_height:padded_chroma_height;
wire signed [13:0] src_last_x=src_base_x+(half_x?14'sd1:14'sd0);
wire signed [13:0] src_last_y=src_base_y+(half_y?14'sd1:14'sd0);
wire source_bounds_ok=(src_base_x>=0)&&(src_base_y>=0)&&
    (src_last_x<$signed({2'b00,plane_width}))&&(src_last_y<$signed({2'b00,plane_height}));

// Entry 239: complete backward/current and following-pixel word addresses stay
// registered ahead of the cache. A fast final response advances these
// registers concurrently with the writer output.
wire [5:0] precompute_current_ei=
    precompute_after_advance?(ei+1'b1):ei;
wire [5:0] precompute_next_ei=precompute_current_ei+1'b1;
wire [2:0] precompute_current_er=precompute_current_ei[5:3];
wire [2:0] precompute_current_el=precompute_current_ei[2:0];
wire [2:0] precompute_next_er=precompute_next_ei[5:3];
wire [2:0] precompute_next_el=precompute_next_ei[2:0];

wire signed [8:0] backward_int_x=$signed(exec_bmvx)>>>1;
wire signed [8:0] backward_int_y=$signed(exec_bmvy)>>>1;
wire next_use_backward=(exec_direction==2'd2);
wire signed [7:0] next_exec_mvx=
    next_use_backward?exec_bmvx:exec_fmvx;
wire signed [7:0] next_exec_mvy=
    next_use_backward?exec_bmvy:exec_fmvy;
wire signed [8:0] next_int_x=$signed(next_exec_mvx)>>>1;
wire signed [8:0] next_int_y=$signed(next_exec_mvy)>>>1;

wire [11:0] precompute_current_luma_x=
    ({6'd0,col}<<4)+{8'd0,blk[0],precompute_current_el};
wire [11:0] precompute_current_luma_y=
    ({6'd0,mrow}<<4)+{8'd0,blk[1],precompute_current_er};
wire [11:0] precompute_current_chroma_x=
    ({6'd0,col}<<3)+{9'd0,precompute_current_el};
wire [11:0] precompute_current_chroma_y=
    ({6'd0,mrow}<<3)+{9'd0,precompute_current_er};
wire [11:0] precompute_current_dest_x=
    (blk<4)?precompute_current_luma_x:precompute_current_chroma_x;
wire [11:0] precompute_current_dest_y=
    (blk<4)?precompute_current_luma_y:precompute_current_chroma_y;
wire signed [13:0] precompute_bidir_src_x=
    $signed({1'b0,precompute_current_dest_x})+$signed(backward_int_x);
wire signed [13:0] precompute_bidir_src_y=
    $signed({1'b0,precompute_current_dest_y})+$signed(backward_int_y);
wire signed [13:0] precompute_bidir_last_x=
    precompute_bidir_src_x+(exec_bmvx[0]?14'sd1:14'sd0);
wire signed [13:0] precompute_bidir_last_y=
    precompute_bidir_src_y+(exec_bmvy[0]?14'sd1:14'sd0);
wire precompute_bidir_bounds_ok=
    (precompute_bidir_src_x>=0)&&(precompute_bidir_src_y>=0)&&
    (precompute_bidir_last_x<$signed({2'b00,plane_width}))&&
    (precompute_bidir_last_y<$signed({2'b00,plane_height}));
wire [28:0] precompute_bidir_addr=pixel_addr(
    future_off,blk,precompute_bidir_src_x[11:0],
    precompute_bidir_src_y[11:0]);

wire [11:0] precompute_next_luma_x=
    ({6'd0,col}<<4)+{8'd0,blk[0],precompute_next_el};
wire [11:0] precompute_next_luma_y=
    ({6'd0,mrow}<<4)+{8'd0,blk[1],precompute_next_er};
wire [11:0] precompute_next_chroma_x=
    ({6'd0,col}<<3)+{9'd0,precompute_next_el};
wire [11:0] precompute_next_chroma_y=
    ({6'd0,mrow}<<3)+{9'd0,precompute_next_er};
wire [11:0] precompute_next_dest_x=
    (blk<4)?precompute_next_luma_x:precompute_next_chroma_x;
wire [11:0] precompute_next_dest_y=
    (blk<4)?precompute_next_luma_y:precompute_next_chroma_y;
wire signed [13:0] precompute_next_src_x=
    $signed({1'b0,precompute_next_dest_x})+$signed(next_int_x);
wire signed [13:0] precompute_next_src_y=
    $signed({1'b0,precompute_next_dest_y})+$signed(next_int_y);
wire signed [13:0] precompute_next_last_x=
    precompute_next_src_x+(next_exec_mvx[0]?14'sd1:14'sd0);
wire signed [13:0] precompute_next_last_y=
    precompute_next_src_y+(next_exec_mvy[0]?14'sd1:14'sd0);
wire precompute_next_bounds_ok=
    (precompute_current_ei!=6'd63)&&
    (precompute_next_src_x>=0)&&(precompute_next_src_y>=0)&&
    (precompute_next_last_x<$signed({2'b00,plane_width}))&&
    (precompute_next_last_y<$signed({2'b00,plane_height}));
wire [28:0] precompute_next_addr=pixel_addr(
    next_use_backward?future_off:past_off,blk,
    precompute_next_src_x[11:0],precompute_next_src_y[11:0]);

wire tap_dx=(half_x&&half_y)?tap_index[0]:(half_x?tap_index[0]:1'b0);
wire tap_dy=(half_x&&half_y)?tap_index[1]:(half_y?tap_index[0]:1'b0);
wire tap_last=(half_x&&half_y)?(tap_index==2'd3):((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire lookup_phase_complete=lookup_wait&&ddram_lookup_ready&&
    ddram_lookup_hit&&tap_last;
wire ddr_phase_complete=waitresp&&ddram_dout_ready&&tap_last;
wire prediction_phase_complete=lookup_phase_complete||ddr_phase_complete;
wire bidir_lookup_candidate=prediction_phase_complete&&
    (exec_direction==2'd3)&&!pred_direction;
wire predicted_pixel_complete=prediction_phase_complete&&
    !((exec_direction==2'd3)&&!pred_direction);
wire next_pixel_lookup_candidate=
    predicted_pixel_complete&&(ei!=6'd63);
wire bidir_early_lookup=
    bidir_lookup_candidate&&bidir_prelaunch_valid;
wire next_pixel_early_lookup=
    next_pixel_lookup_candidate&&next_prelaunch_valid;
wire early_lookup=bidir_early_lookup||next_pixel_early_lookup;
wire [28:0] early_lookup_addr=
    bidir_early_lookup?bidir_prelaunch_addr:next_prelaunch_addr;
wire early_half_x=
    bidir_early_lookup?exec_bmvx[0]:next_exec_mvx[0];
wire early_half_y=
    bidir_early_lookup?exec_bmvy[0]:next_exec_mvy[0];
// Entry 243: while a registered DDR miss response retires, present the
// following tap address to the cache request
// port. The cache captures it on that response edge; req remains asserted
// afterward until the unchanged one-outstanding downstream handshake accepts
// it. This removes the idle capture bubble without adding transaction depth.
wire miss_response_prelaunch=waitresp&&ddram_dout_ready&&!tap_last;
wire [3:0] miss_prelaunch_tap_byte_sum=
    {1'b0,phase_base_byte}+next_tap_dx;
wire [2:0] miss_response_prelaunch_byte=
    miss_prelaunch_tap_byte_sum[2:0];
assign fast_pixel_advance=predicted_pixel_complete&&
    ((ei==6'd63)||next_prelaunch_valid);
assign slow_pixel_advance=emit&&!emit_advanced&&(ei!=6'd63);
assign precompute_after_advance=
    (fast_pixel_advance&&(ei!=6'd63))||slow_pixel_advance;
wire signed [13:0] src_x_tap_signed=src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire [1:0] next_tap_index=tap_index+1'b1;
wire next_tap_dx=(half_x&&half_y)?next_tap_index[0]:
    (half_x?next_tap_index[0]:1'b0);
wire next_tap_dy=(half_x&&half_y)?next_tap_index[1]:
    (half_y?next_tap_index[0]:1'b0);
wire signed [13:0] next_src_x_tap_signed=
    src_base_x+$signed({13'd0,next_tap_dx});
wire signed [13:0] next_src_y_tap_signed=
    src_base_y+$signed({13'd0,next_tap_dy});
wire [11:0] next_src_x_tap=next_src_x_tap_signed[11:0];
wire [11:0] next_src_y_tap=next_src_y_tap_signed[11:0];
wire [28:0] selected_reference_off=phase_backward?future_off:past_off;
wire [28:0] computed_phase_base_addr=pixel_addr(
    selected_reference_off,blk,src_base_x[11:0],src_base_y[11:0]);

wire residual_hit=(exec_desc_slot<desc_count)&&
    (desc_word[13:3]==mbi)&&
    (desc_word[2:0]==blk);
wire pixel_completed=
    (pixel_setup&&(exec_direction==0)&&residual_hit)||
    predicted_pixel_complete;
// Commit 231: overlap the synchronous read of the next in-block residual with
// the current pixel's reference lookup. Block boundaries continue through the
// staged residual_load path so descriptor changes retain the full RAM latency.
wire residual_read_ahead=
    (pixel_setup||lookup_wait||req||waitresp||emit)&&(ei!=6'd63);
wire [5:0] residual_read_index=
    (fast_pixel_advance&&(ei<6'd62)) ? (ei+2'd2) :
    residual_read_ahead ? (ei+1'b1) : ei;
wire [16:0] residual_mem_index=
    {exec_desc_slot,6'b000000}+{11'd0,residual_read_index};
reg signed [15:0] residual_pel;
assign residual_store_write=capture_enable&&sideband_valid&&desc_active&&
    (sideband_index==sample_expected);
assign residual_store_write_address=
    {current_desc_slot,6'b000000}+{11'd0,sideband_index};
assign residual_store_write_data=sideband_value;
assign residual_store_read_address=residual_mem_index;
// kate - Commit 182: byte select is the copy registered at request accept, not
// the live combinational address.  Same value, captured a cycle earlier.
wire [7:0] current_tap_sample=bat(ddram_dout,tap_byte_sel);
wire [10:0] pred_sum_with_current=pred_sum+{3'd0,current_tap_sample};
wire [7:0] selected_prediction=round_prediction(pred_sum_with_current,half_x,half_y);
wire [8:0] bidir_sum={1'b0,forward_prediction}+{1'b0,selected_prediction}+9'd1;
wire [7:0] bidir_prediction=bidir_sum[8:1];
wire [7:0] final_prediction=(exec_direction==2'd3)?bidir_prediction:selected_prediction;
wire [7:0] reconstructed_current=clip(final_prediction,residual_pel);
wire [7:0] reconstructed_intra=clip(8'd0,residual_pel);
wire [3:0] phase_tap_byte_sum={1'b0,phase_base_byte}+tap_dx;
wire [2:0] phase_tap_byte=phase_tap_byte_sum[2:0];
wire [7:0] lookup_tap_sample=bat(ddram_lookup_data,phase_tap_byte);
wire [10:0] lookup_pred_sum_with_current=pred_sum+{3'd0,lookup_tap_sample};
wire [7:0] lookup_selected_prediction=
    round_prediction(lookup_pred_sum_with_current,half_x,half_y);
wire [8:0] lookup_bidir_sum=
    {1'b0,forward_prediction}+{1'b0,lookup_selected_prediction}+9'd1;
wire [7:0] lookup_bidir_prediction=lookup_bidir_sum[8:1];
wire [7:0] lookup_final_prediction=
    (exec_direction==2'd3)?lookup_bidir_prediction:lookup_selected_prediction;
wire [7:0] lookup_reconstructed_current=
    clip(lookup_final_prediction,residual_pel);
wire lookup_advance=lookup_wait&&ddram_lookup_ready&&
    ddram_lookup_hit&&!tap_last;
wire prediction_lookup=
    (pixel_setup&&(exec_direction!=0)&&phase_bounds_ok)||lookup_advance||
    early_lookup;
wire advance_tap_address=lookup_advance||miss_response_prelaunch;
wire address_tap_dx=advance_tap_address?next_tap_dx:tap_dx;
wire address_tap_dy=advance_tap_address?next_tap_dy:tap_dy;
wire [3:0] address_tap_byte_sum=
    {1'b0,phase_base_byte}+address_tap_dx;
wire [28:0] normal_lookup_addr=phase_base_addr+
    (address_tap_dy?{22'd0,phase_row_words}:29'd0)+
    {28'd0,address_tap_byte_sum[3]};

assign ddram_burstcnt=(req||miss_response_prelaunch)?8'd1:8'd0;
assign ddram_addr=miss_response_prelaunch?normal_lookup_addr:
    req?normal_lookup_addr:
    prediction_lookup?
        (early_lookup?early_lookup_addr:normal_lookup_addr):29'd0;
assign ddram_rd=req||miss_response_prelaunch;
assign ddram_cacheable=req||miss_response_prelaunch||prediction_lookup;
assign ddram_lookup_request=prediction_lookup;
assign ddram_lookup_consume=
    lookup_wait&&ddram_lookup_ready&&ddram_lookup_hit;
assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&emit_block_start;
assign store_block_complete=emit&&emit_block_complete;
// Wide B scratch tag: X[11:10]=11 identifies scratch; Y[11:9]
// identifies Y/Cb/Cr while preserving 10-bit X and 9-bit Y coordinates.
assign store_pixel_x=emit_x;
assign store_pixel_y=emit_y;

wire descriptor_order_error=(desc_count!=0)&&
    ({sideband_value[13:3],sideband_value[2:0]}<=
     {last_desc_word[13:3],last_desc_word[2:0]});
wire first_direction_word=(sideband_index==6'h37)||(sideband_index==6'h38)||(sideband_index==6'h39)||(sideband_index==6'h3a);
wire [1:0] direction_word=(sideband_index==6'h37)?2'd0:(sideband_index==6'h38)?2'd1:(sideband_index==6'h39)?2'd2:2'd3;
wire geometry_word=(sideband_index==6'h3c)&&(sideband_value[15:12]==4'd0);
wire descriptor_word=(sideband_index==6'h3f)&&sideband_value[15]&&
    (sideband_value!=16'shA3FE)&&(sideband_value!=16'shA3FF);

always @(posedge clk) begin
    if(reset) begin
        desc_word<=0;
        residual_pel<=0;
    end else begin
        desc_word<=desc_mem[exec_desc_slot];
        if(residual_load_wait||
           (fast_pixel_advance&&(ei!=6'd63))||
           slow_pixel_advance)
            residual_pel<=residual_hit?residual_store_read_data:16'sd0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        mb_width<=0;mb_height<=0;geometry_seen<=0;motion_count<=0;motion_word<=0;motion_load<=0;
        motion_first_pending<=0;pending_direction<=0;pending_fmvx<=0;pending_fmvy<=0;
        exec_direction<=0;exec_fmvx<=0;exec_fmvy<=0;exec_bmvx<=0;exec_bmvy<=0;
        phase_mvx<=0;phase_mvy<=0;phase_backward<=0;
        bidir_prelaunch_addr<=0;next_prelaunch_addr<=0;
        bidir_prelaunch_byte<=0;next_prelaunch_byte<=0;
        bidir_prelaunch_valid<=0;next_prelaunch_valid<=0;
        phase_base_addr<=0;phase_base_byte<=0;phase_row_words<=0;
        phase_bounds_ok<=0;
        desc_count<=0;last_desc_word<=0;current_desc_slot<=0;desc_active<=0;sample_expected<=0;metadata_done<=0;exec_desc_slot<=0;
        pending<=0;started<=0;active<=0;future_bank_latched<=0;scratch_bank_latched<=0;req<=0;waitresp<=0;lookup_wait<=0;
        mbi<=0;col<=0;mrow<=0;blk<=0;timeout<=0;emit<=0;wait_store<=0;pixel_setup<=0;residual_load<=0;residual_load_wait<=0;ei<=0;
        pred_direction<=0;tap_index<=0;pred_sum<=0;forward_prediction<=0;out_reg<=0;tap_byte_sel<=0;
        emit_advanced<=0;emit_x<=0;emit_y<=0;emit_block_start<=0;emit_block_complete<=0;
        read_seen<=0;sample_nonzero<=0;half_sample_seen<=0;reconstructed_seen<=0;persisted_seen<=0;row_persisted<=0;error<=0;error_source<=0;
        row_motion_base<=0;row_motion_end<=0;exec_row<=0;row_final_latched<=0;
    end else begin
        row_persisted<=0;
        if(capture_enable&&sideband_valid) begin
            if(desc_active) begin
                if(sideband_index!=sample_expected)begin error<=1;if(!error)error_source<=5'd1;end
                else if(sideband_index==6'd63)desc_active<=0;
                else sample_expected<=sample_expected+1'b1;
            end else if(first_direction_word) begin
                if(metadata_done||motion_first_pending||(motion_count>=MAX_MB)||(desc_count!=0))begin error<=1;if(!error)error_source<=5'd2;end
                else begin pending_direction<=direction_word;pending_fmvx<=sideband_value[15:8];pending_fmvy<=sideband_value[7:0];motion_first_pending<=1;end
            end else if(geometry_word) begin
                if(metadata_done||geometry_seen||!motion_first_pending||(motion_count!=0)||
                   (sideband_value[11:6]==0)||(sideband_value[11:6]>6'd45)||(sideband_value[5:0]==0)||(sideband_value[5:0]>6'd30))begin error<=1;if(!error)error_source<=5'd3;end
                else begin mb_width<=sideband_value[11:6];mb_height<=sideband_value[5:0];geometry_seen<=1;end
            end else if(sideband_index==6'h3b) begin
                if(metadata_done||!motion_first_pending||(motion_count>=MAX_MB)||!geometry_seen)begin error<=1;if(!error)error_source<=5'd4;end
                else begin
                    motion_mem[motion_count]<={pending_direction,pending_fmvx,pending_fmvy,sideband_value[15:8],sideband_value[7:0]};
                    motion_count<=motion_count+1'b1;motion_first_pending<=0;
                end
            end else if(descriptor_word) begin
                if((motion_count==0)||motion_first_pending||metadata_done||(desc_count>=MAX_BLOCKS)||
                   (sideband_value[13:3]>=MAX_MB)||(sideband_value[2:0]>=6)||descriptor_order_error)begin error<=1;if(!error)error_source<=5'd5;end
