`timescale 1ns/1ps

// Commit 211: controlled B-intra parser and transform transaction.
module tb_h262_b_intra_macroblocks;
    localparam integer STREAM_LEN=182458;
    reg clk=0,reset=1,stream_valid=0;
    reg [7:0] stream_data=0;
    reg [7:0] stream_mem[0:STREAM_LEN-1];
    integer stream_index=0,quiet_cycles=0;
    integer pictures=0,rows=0,motion=0,intra_motion=0;
    integer blocks=0,intra_blocks=0,samples=0,coefficients=0;
    reg [6:0] samples_remaining=0;
    reg current_descriptor_intra=0;

    wire candidate,seen,complete,hold,replay,sideband_valid,error;
    wire [5:0] sideband_index;
    wire signed [15:0] sideband_value;
    wire row_retired=sideband_valid&&(sideband_index==6'h3f)&&
        ((sideband_value==16'shA3FE)||(sideband_value==16'shA3FF));

    always #5 clk=~clk;
    mpeg2_h262_b_core_probe dut(
        .clk(clk),.reset(reset),.stream_data(stream_data),
        .stream_valid(stream_valid),.row_retired(row_retired),
        .b_candidate(candidate),.b_seen(seen),.b_complete_now(complete),
        .parse_hold(hold),.replay_active(replay),
        .sideband_valid(sideband_valid),.sideband_index(sideband_index),
        .sideband_value(sideband_value),.first_sample_valid(),
        .first_sample_value(),.probe_error(error));

    initial begin
        $readmemh("/tmp/b_intra.hex",stream_mem);
        repeat(5)@(posedge clk);reset<=0;
    end
    always @(negedge clk) begin
        if(reset)begin stream_valid<=0;stream_data<=0;end
        else if((stream_index<STREAM_LEN)&&!hold)begin
            stream_data<=stream_mem[stream_index];stream_valid<=1;
            stream_index<=stream_index+1;
        end else stream_valid<=0;
    end
    always @(posedge clk) begin
        if(error)$fatal(1,"B-intra error offset=%0d state=%0d row=%0d col=%0d",stream_index,dut.state,dut.slice_row_number,dut.current_col);
        if(complete)pictures<=pictures+1;
        if(sideband_valid)begin
            if(samples_remaining!=0)begin
                if(sideband_index!=(7'd64-samples_remaining))$fatal(1,"sample order");
                samples<=samples+1;samples_remaining<=samples_remaining-1'b1;
            end else if((sideband_index==6'h3f)&&sideband_value[15]&&
                        (sideband_value!=16'shA3FE)&&(sideband_value!=16'shA3FF))begin
                blocks<=blocks+1;current_descriptor_intra<=!sideband_value[14];
                if(!sideband_value[14])intra_blocks<=intra_blocks+1;
                samples_remaining<=64;
            end else if(sideband_index==6'h37)begin
                motion<=motion+1;intra_motion<=intra_motion+1;
            end else if((sideband_index==6'h38)||(sideband_index==6'h39)||(sideband_index==6'h3a))motion<=motion+1;
            if(row_retired)begin rows<=rows+1;coefficients<=coefficients+dut.residual_coeff_count;end
        end
        if((stream_index==STREAM_LEN)&&!hold&&!replay)quiet_cycles<=quiet_cycles+1;else quiet_cycles<=0;
        if(quiet_cycles==100)begin
            $display("B_INTRA_RESULT pictures=%0d rows=%0d motion=%0d intra_motion=%0d blocks=%0d intra_blocks=%0d coeffs=%0d samples=%0d",
                     pictures,rows,motion,intra_motion,blocks,intra_blocks,coefficients,samples);
            if(!seen||error||pictures!=1||rows!=30||motion!=1350||intra_motion!=2||
               blocks!=12||intra_blocks!=12||coefficients!=12||samples!=768||samples_remaining!=0)
                $fatal(1,"B-intra regression failed");
            $finish;
        end
    end
    initial begin repeat(30000000)@(posedge clk);$fatal(1,"timeout %0d",stream_index);end
endmodule
