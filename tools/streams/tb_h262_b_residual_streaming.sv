`timescale 1ns/1ps

module tb_h262_b_residual_streaming;
    localparam integer MAX_STREAM_BYTES=262144;
    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0,quiet_cycles=0;
    integer motion_events=0,residual_blocks=0,residual_samples=0;
    integer residual_writes=0;
    integer store_samples=0,stripe_store_samples=0,stripe_changed_samples=0;
    reg [6:0] samples_remaining=0;

    wire b_candidate,b_seen,b_complete,b_hold,b_replay;
    wire sideband_valid,first_valid,core_error;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value,first_value;

    wire residual_store_write;
    wire [16:0] residual_store_write_address;
    wire signed [15:0] residual_store_write_data;
    wire [16:0] residual_store_read_address;
    reg signed [15:0] residual_store_read_data=0;
    reg signed [15:0] residual_store[0:131071];
    wire [7:0] burstcnt,store_value;
    wire [28:0] ddram_addr;
    wire ddram_rd,store_select,store_valid,store_start,store_complete;
    wire [11:0] store_x,store_y;
    wire raster_active,read_seen,sample_nonzero,half_seen;
    wire reconstructed_seen,persisted_seen,raster_error;
    wire [4:0] raster_error_source;
    reg [63:0] ddram_dout=0;
    reg ddram_dout_ready=0,store_block_stored=0;

    function automatic is_stripe_mb;
        input [10:0] index;
        integer row,column;
        begin
            row=index/45;
            column=index%45;
            is_stripe_mb=(row>=5)&&(row<=24)&&(column==20);
        end
    endfunction

    always #5 clk=~clk;

    mpeg2_h262_b_core_probe parser(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.b_candidate(b_candidate),
        .b_seen(b_seen),.b_complete_now(b_complete),.parse_hold(b_hold),
        .replay_active(b_replay),.sideband_valid(sideband_valid),
        .sideband_index(sideband_index),.sideband_value(sideband_value),
        .first_sample_valid(first_valid),.first_sample_value(first_value),
        .probe_error(core_error)
    );

    mpeg2_h262_b_bidirectional_raster_engine raster(
        .clk(clk),.reset(reset),.capture_enable(1'b1),.request(b_seen),
        .sideband_valid(sideband_valid),.sideband_index(sideband_index),
        .sideband_value(sideband_value),
        .residual_store_write(residual_store_write),
        .residual_store_write_address(residual_store_write_address),
        .residual_store_write_data(residual_store_write_data),
        .residual_store_read_address(residual_store_read_address),
        .residual_store_read_data(residual_store_read_data),
        .reference_valid(1'b1),.future_reference_bank(1'b1),
        .store_block_stored(store_block_stored),.ddram_busy(1'b0),
        .ddram_dout(ddram_dout),.ddram_dout_ready(ddram_dout_ready),
        .ddram_burstcnt(burstcnt),
        .ddram_addr(ddram_addr),.ddram_rd(ddram_rd),
        .store_select(store_select),.store_pixel_value(store_value),
        .store_pixel_x(store_x),.store_pixel_y(store_y),
        .store_pixel_valid(store_valid),.store_block_start(store_start),
        .store_block_complete(store_complete),.active(raster_active),
        .read_seen(read_seen),.sample_nonzero(sample_nonzero),
        .half_sample_seen(half_seen),.reconstructed_seen(reconstructed_seen),
        .persisted_seen(persisted_seen),.error(raster_error),
        .error_source(raster_error_source)
    );

    always @(posedge clk) begin
        ddram_dout_ready<=0;
        store_block_stored<=store_complete;
        if(ddram_rd) begin
            ddram_dout_ready<=1;
            if(raster.req_kind)
                ddram_dout<=raster.resrows[raster.verify_row];
            else
                ddram_dout<={8{8'd50}};
        end

        if(residual_store_write) begin
            residual_store[residual_store_write_address]
                <=residual_store_write_data;
            residual_writes<=residual_writes+1;
        end
        residual_store_read_data<=residual_store[residual_store_read_address];

        if(store_valid) begin
            store_samples<=store_samples+1;
            if(is_stripe_mb(raster.mbi)) begin
                stripe_store_samples<=stripe_store_samples+1;
                if(store_value!=8'd50)
                    stripe_changed_samples<=stripe_changed_samples+1;
            end else if(store_value!=8'd50)
                $fatal(1,"non-stripe sample changed at MB %0d",raster.mbi);
        end

        if(sideband_valid) begin
            if(samples_remaining!=0) begin
                if(sideband_index!=(7'd64-samples_remaining))
                    $fatal(1,"sample order %0d remaining %0d",
                           sideband_index,samples_remaining);
                residual_samples<=residual_samples+1;
                samples_remaining<=samples_remaining-1'b1;
            end else if((sideband_index==6'h3f)&&
                        (sideband_value[15:14]==2'b11)) begin
                residual_blocks<=residual_blocks+1;
                samples_remaining<=7'd64;
            end else if((sideband_index==6'h38)||
                        (sideband_index==6'h39)||
                        (sideband_index==6'h3a)) begin
                motion_events<=motion_events+1;
            end
        end

        if(persisted_seen&&quiet_cycles==0)quiet_cycles<=1;
        else if(quiet_cycles!=0)quiet_cycles<=quiet_cycles+1;

        if(quiet_cycles==100) begin
            $display("RESULT b_seen=%0d core_error=%0d raster_error=%0d motion=%0d blocks=%0d samples=%0d writes=%0d stores=%0d stripe=%0d changed=%0d",
                     b_seen,core_error,raster_error,motion_events,
                     residual_blocks,residual_samples,residual_writes,
                     store_samples,stripe_store_samples,stripe_changed_samples);
            if(!b_seen||core_error||raster_error||motion_events!=1350||
               residual_blocks!=120||residual_samples!=7680||
               residual_writes!=7680||samples_remaining!=0||
               raster.desc_count!=120||!raster.metadata_done||
               !read_seen||!reconstructed_seen||!persisted_seen||
               store_samples!=518400||stripe_store_samples!=7680||
               stripe_changed_samples!=7680)
                $fatal(1,"B residual streaming regression failed");
            $finish;
        end
    end

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN");
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset)begin stream_valid<=0;stream_data<=0;end
        else if(stream_index<stream_len)begin
            if(!b_hold)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else stream_valid<=0;
    end

    initial begin
        repeat(15000000)@(posedge clk);
        $fatal(1,"B residual streaming regression timed out");
    end
endmodule
