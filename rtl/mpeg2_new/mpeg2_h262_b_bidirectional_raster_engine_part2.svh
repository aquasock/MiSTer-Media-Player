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

wire tap_dx=(half_x&&half_y)?tap_index[0]:(half_x?tap_index[0]:1'b0);
wire tap_dy=(half_x&&half_y)?tap_index[1]:(half_y?tap_index[0]:1'b0);
wire tap_last=(half_x&&half_y)?(tap_index==2'd3):((half_x||half_y)?(tap_index==2'd1):(tap_index==2'd0));
wire signed [13:0] src_x_tap_signed=src_base_x+$signed({13'd0,tap_dx});
wire signed [13:0] src_y_tap_signed=src_base_y+$signed({13'd0,tap_dy});
wire [11:0] src_x_tap=src_x_tap_signed[11:0];
wire [11:0] src_y_tap=src_y_tap_signed[11:0];
wire [28:0] selected_reference_off=use_backward?future_off:past_off;

wire residual_hit=(exec_desc_slot<desc_count)&&
    (desc_word[13:3]==mbi)&&
    (desc_word[2:0]==blk);
wire [16:0] residual_mem_index={exec_desc_slot,6'b000000}+{11'd0,ei};
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
wire [7:0] final_prediction=(mb_direction==2'd3)?bidir_prediction:selected_prediction;
wire [7:0] reconstructed_current=clip(final_prediction,residual_pel);
wire [7:0] reconstructed_intra=clip(8'd0,residual_pel);

assign ddram_burstcnt=req?8'd1:8'd0;
assign ddram_addr=req?(req_kind?block_addr(scratch_bank_latched,col,mrow,blk,verify_row):pixel_addr(selected_reference_off,blk,src_x_tap,src_y_tap)):29'd0;
assign ddram_rd=req;
assign ddram_cacheable=req&&!req_kind;
assign store_select=emit;
assign store_pixel_value=out_reg;
assign store_pixel_valid=emit;
assign store_block_start=emit&&(ei==0);
assign store_block_complete=emit&&(ei==63);
// Wide B scratch tag: X[11:10]=11 identifies scratch; Y[11:9]
// identifies Y/Cb/Cr while preserving 10-bit X and 9-bit Y coordinates.
assign store_pixel_x={2'b11,dest_x[9:0]};
assign store_pixel_y=(blk<4)?(scratch_bank_latched?{3'b001,luma_y[8:0]}:{3'b100,luma_y[8:0]}):
                     (blk==4)?(scratch_bank_latched?{3'b010,chroma_y[8:0]}:{3'b101,chroma_y[8:0]}):
                              (scratch_bank_latched?{3'b011,chroma_y[8:0]}:{3'b110,chroma_y[8:0]});

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
        residual_pel<=residual_hit?residual_store_read_data:16'sd0;
    end
end

always @(posedge clk) begin
    if(reset) begin
        mb_width<=0;mb_height<=0;geometry_seen<=0;motion_count<=0;motion_word<=0;motion_load<=0;
        motion_first_pending<=0;pending_direction<=0;pending_fmvx<=0;pending_fmvy<=0;
        desc_count<=0;last_desc_word<=0;current_desc_slot<=0;desc_active<=0;sample_expected<=0;metadata_done<=0;exec_desc_slot<=0;
        pending<=0;started<=0;active<=0;future_bank_latched<=0;scratch_bank_latched<=0;req<=0;waitresp<=0;req_kind<=0;
        mbi<=0;col<=0;mrow<=0;blk<=0;timeout<=0;emit<=0;wait_store<=0;pixel_setup<=0;residual_load<=0;residual_load_wait<=0;ei<=0;verify_row<=0;
        pred_direction<=0;tap_index<=0;pred_sum<=0;forward_prediction<=0;out_reg<=0;tap_byte_sel<=0;
        read_seen<=0;sample_nonzero<=0;half_sample_seen<=0;reconstructed_seen<=0;persisted_seen<=0;row_persisted<=0;error<=0;error_source<=0;
        row_motion_base<=0;row_motion_end<=0;exec_row<=0;row_final_latched<=0;
        for(i=0;i<8;i=i+1)resrows[i]<=0;
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
