`timescale 1ns/1ps

module tb_h262_prediction_error_sources;
reg clk=0;
always #5 clk=~clk;

reg reset=1;
reg p_forward_vector_valid=0;
reg signed [12:0] p_forward_vector_x=0;
reg signed [12:0] p_forward_vector_y=0;
reg p_residual_sample_valid=0;
reg [5:0] p_residual_sample_index=0;
reg signed [15:0] p_residual_sample_value=0;
wire probe_error;
wire [2:0] probe_error_source;
wire [4:0] probe_error_detail;

task send_sideband;
    input [5:0] index;
    input signed [15:0] value;
    begin
        @(negedge clk);
        p_residual_sample_index=index;
        p_residual_sample_value=value;
        p_residual_sample_valid=1;
        @(negedge clk);
        p_residual_sample_valid=0;
    end
endtask

task expect_error;
    input [2:0] source;
    input [4:0] detail;
    begin
        repeat(2) @(posedge clk);
        if(!probe_error || probe_error_source!==source ||
           probe_error_detail!==detail) begin
            $display("FAIL error=%b source=%0d detail=%0d expected=%0d/%0d",
                     probe_error,probe_error_source,probe_error_detail,
                     source,detail);
            $fatal(1);
        end
    end
endtask

mpeg2_h262_reference_read_probe dut(
    .clk(clk),.reset(reset),
    .horizontal_size(14'd720),.vertical_size(14'd480),
    .p_vector_proof_seen(1'b1),
    .p_forward_vector_valid(p_forward_vector_valid),
    .p_forward_vector_x(p_forward_vector_x),
    .p_forward_vector_y(p_forward_vector_y),
    .forward_f_code_horizontal(4'd1),
    .forward_f_code_vertical(4'd1),
    .p_implicit_reconstruct_request(1'b0),
    .p_residual_sample_valid(p_residual_sample_valid),
    .p_residual_sample_index(p_residual_sample_index),
    .p_residual_sample_value(p_residual_sample_value),
    .reference_frame_valid(1'b1),.reference_frame_bank(1'b0),
    .destination_frame_bank(1'b1),.p_store_block_stored(1'b0),
    .ddram_busy(1'b0),.ddram_dout(64'd0),.ddram_dout_ready(1'b0),
    .probe_error(probe_error),.probe_error_source(probe_error_source),
    .probe_error_detail(probe_error_detail)
);

initial begin
    repeat(3) @(posedge clk);
    reset=0;

    // Generalized P is POWER=2.  An unrecognized metadata word is DISK=8.
    send_sideband(6'h3e,16'sd0);
    send_sideband(6'h3b,16'sd0);
    expect_error(3'd2,5'd8);
    // A later malformed descriptor must not relabel the first assertion.
    send_sideband(6'h3c,-16'sd1);
    expect_error(3'd2,5'd8);

    @(negedge clk);
    reset=1;
    repeat(2) @(posedge clk);
    @(negedge clk);
    reset=0;
    p_forward_vector_valid=1;
    p_forward_vector_x=13'sd2047;
    p_forward_vector_y=-13'sd2048;

    // B/history is POWER=3.  An unrecognized metadata word is DISK=7.
    send_sideband(6'h38,16'sd0);
    send_sideband(6'h3e,16'sd0);
    expect_error(3'd3,5'd7);
    // A later duplicate direction word must leave the first detail intact.
    send_sideband(6'h38,16'sd0);
    expect_error(3'd3,5'd7);

    $display("PASS prediction error source/detail capture");
    $finish;
end
endmodule
