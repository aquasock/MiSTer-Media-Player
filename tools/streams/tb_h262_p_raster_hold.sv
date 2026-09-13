`timescale 1ns/1ps

// Entry 208 final-row persistence ordering regression.  The raster engine
// asserts row_persisted and persisted_seen together on the final row.  The
// streamed parser observes row retirement and raises wide_complete_now one
// cycle later.  Completion must consume that saved persistence proof instead
// of arming the raster-hold timeout after the proof has been withdrawn.
module tb_h262_p_raster_hold;
    localparam integer MAX_STREAM_BYTES=262144;

    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:MAX_STREAM_BYTES-1];
    reg [1023:0] hex_path;
    integer stream_len,stream_index=0;
    integer row_count=0,completion_age=-1;
    reg row_persistence=0,picture_persistence=0;

    wire stream_hold,macroblock_seen,vector_valid;
    wire signed [12:0] vector_x,vector_y;
    wire residual_required,residual_success,first_valid,replay_valid;
    wire signed [15:0] first_value,replay_value;
    wire [5:0] replay_index;
    wire probe_error;
    wire [3:0] probe_error_source,progress_detail;

    wire row_terminator=replay_valid&&(replay_index==6'h3f)&&
        ((replay_value==16'shA2FE)||(replay_value==16'shA2FF));
    wire final_terminator=row_terminator&&(replay_value==16'shA2FF);

    always #5 clk=~clk;

    mpeg2_h262_p_diagnostic_controller dut(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.p_picture_expected(1'b1),
        .p_persistence_complete(picture_persistence),
        .p_row_persistence_complete(row_persistence),
        .intra_dc_precision(2'd0),.stream_hold(stream_hold),
        .p_macroblock_type_seen(macroblock_seen),
        .p_forward_vector_valid(vector_valid),
        .p_forward_vector_x(vector_x),.p_forward_vector_y(vector_y),
        .p_residual_required(residual_required),
        .p_residual_success(residual_success),
        .p_first_residual_sample_valid(first_valid),
        .p_first_residual_sample_value(first_value),
        .p_residual_sample_valid(replay_valid),
        .p_residual_sample_index(replay_index),
        .p_residual_sample_value(replay_value),.probe_error(probe_error),
        .probe_error_source(probe_error_source),
        .progress_detail(progress_detail)
    );

    initial begin
        if(!$value$plusargs("HEX=%s",hex_path))$fatal(1,"missing +HEX");
        if(!$value$plusargs("LEN=%d",stream_len))$fatal(1,"missing +LEN");
        if((stream_len<=0)||(stream_len>MAX_STREAM_BYTES))
            $fatal(1,"invalid LEN %0d",stream_len);
        $readmemh(hex_path,stream_mem,0,stream_len-1);
        repeat(5)@(posedge clk);
        reset<=0;
    end

    always @(negedge clk) begin
        if(reset)begin
            stream_valid<=0;
            stream_data<=0;
        end else if(stream_index<stream_len)begin
            if(!stream_hold)begin
                stream_data<=stream_mem[stream_index];
                stream_valid<=1;
                stream_index<=stream_index+1;
            end else stream_valid<=0;
        end else stream_valid<=0;
    end

    always @(posedge clk) begin
        row_persistence<=0;
        picture_persistence<=0;

        if(row_terminator)begin
            row_persistence<=1;
            row_count<=row_count+1;
            if(final_terminator)picture_persistence<=1;
        end

        if(dut.wide_complete_now)completion_age<=0;
        else if(completion_age>=0)completion_age<=completion_age+1;

        if(completion_age==2)begin
            $display("P_RASTER_HOLD_RESULT rows=%0d bytes=%0d active=%0d ready=%0d error=%0d source=%0d accepted=%0d",
                     row_count,stream_index,dut.raster_hold_active,
                     dut.raster_hold_ready,probe_error,probe_error_source,
                     macroblock_seen);
            if(row_count!=30||dut.raster_hold_active||!dut.raster_hold_ready||
               probe_error||probe_error_source!=0||!macroblock_seen)
                $fatal(1,"final-row persistence proof was not accepted");
            $finish;
        end
    end

    initial begin
        repeat(50000000)@(posedge clk);
        $fatal(1,"P raster-hold regression timed out at byte %0d",stream_index);
    end

    wire unused=&{1'b0,vector_valid,vector_x,vector_y,residual_required,
        residual_success,first_valid,first_value,progress_detail};
endmodule
