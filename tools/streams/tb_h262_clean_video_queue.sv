`timescale 1ns/1ps
// Entry 464: prove that decoder backpressure no longer prevents the in-band
// extractor from reaching PCM, while clean bytes and timestamps remain ordered.
module tb_h262_clean_video_queue;

reg clk = 0;
reg reset = 1;
reg [7:0] input_data = 0;
reg input_valid = 0;
wire input_ready;
reg input_end = 0;

wire [7:0] extracted_data;
wire extracted_valid;
wire extracted_ready;
wire [32:0] extracted_pts;
wire extracted_metadata_valid;
wire extracted_metadata_ready;
wire [1:0] picture_structure;
wire top_field_first;
wire repeat_first_field;
wire progressive_frame;
wire [7:0] metadata_count;
wire [15:0] pcm_left;
wire [15:0] pcm_right;
wire pcm_stereo;
wire pcm_rate_48k;
wire pcm_valid;
wire pcm_end;
reg pcm_ready = 1;
wire [13:0] pcm_sample_count;
wire pcm_protocol_error;

wire [7:0] output_data;
wire output_valid;
reg output_ready = 0;
wire [32:0] output_metadata_pts;
wire output_metadata_valid;

always #5 clk = ~clk;

mpeg2_h262_inband_metadata extractor
(
    .clk(clk),.reset(reset),
    .input_data(input_data),.input_valid(input_valid),
    .input_ready(input_ready),.input_end(input_end),
    .stream_data(extracted_data),.stream_valid(extracted_valid),
    .stream_ready(extracted_ready),
    .pts_90k(extracted_pts),.picture_structure(picture_structure),
    .top_field_first(top_field_first),
    .repeat_first_field(repeat_first_field),
    .progressive_frame(progressive_frame),
    .metadata_valid(extracted_metadata_valid),
    .metadata_ready(extracted_metadata_ready),
    .metadata_count(metadata_count),
    .pcm_left(pcm_left),.pcm_right(pcm_right),
    .pcm_stereo(pcm_stereo),.pcm_rate_48k(pcm_rate_48k),
    .pcm_valid(pcm_valid),.pcm_end(pcm_end),.pcm_ready(pcm_ready),
    .pcm_sample_count(pcm_sample_count),
    .pcm_protocol_error(pcm_protocol_error)
);

mpeg2_h262_clean_video_queue queue
(
    .clk(clk),.reset(reset),
    .input_data(extracted_data),.input_valid(extracted_valid),
    .input_ready(extracted_ready),
    .input_metadata_pts(extracted_pts),
    .input_metadata_valid(extracted_metadata_valid),
    .input_metadata_ready(extracted_metadata_ready),
    .output_data(output_data),.output_valid(output_valid),
    .output_ready(output_ready),
    .output_metadata_pts(output_metadata_pts),
    .output_metadata_valid(output_metadata_valid)
);

reg [7:0] expected [0:255];
reg [7:0] received [0:255];
integer expected_count = 0;
integer received_count = 0;
integer pcm_seen = 0;
integer metadata_seen = 0;
integer metadata_position [0:3];
reg [32:0] metadata_pts [0:3];

always @(posedge clk) begin
    if (!reset && pcm_valid)
        pcm_seen = pcm_seen + 1;
    if (!reset && output_metadata_valid) begin
        metadata_position[metadata_seen] = received_count;
        metadata_pts[metadata_seen] = output_metadata_pts;
        metadata_seen = metadata_seen + 1;
    end
    if (!reset && output_valid) begin
        received[received_count] = output_data;
        received_count = received_count + 1;
    end
end

task send(input [7:0] value);
    begin
        @(negedge clk);
        while (!input_ready) @(negedge clk);
        input_data = value;
        input_valid = 1;
        @(negedge clk);
        input_valid = 0;
    end
endtask

task send_video(input [7:0] value);
    begin
        expected[expected_count] = value;
        expected_count = expected_count + 1;
        send(value);
    end
endtask

task send_pts(input [32:0] value);
    reg [39:0] payload;
    begin
        payload = {value,7'd0};
        send(8'h00); send(8'h00); send(8'h01); send(8'hB0);
        send(payload[39:32]); send(payload[31:24]); send(payload[23:16]);
        send(payload[15:8]); send(payload[7:0]);
    end
endtask

integer i;
initial begin
    repeat (4) @(posedge clk);
    reset = 0;

    // Hold the decoder for the whole input burst.  The extractor must still
    // cross both timestamp records and reach the three-frame PCM record.
    for (i = 0; i < 32; i = i + 1)
        send_video(8'h40 + i[7:0]);
    send_pts(33'd90000);
    for (i = 0; i < 64; i = i + 1)
        send_video(8'h80 + i[7:0]);
    send_pts(33'd180000);

    send(8'h00); send(8'h00); send(8'h01); send(8'hB1);
    send(8'h0F); // three 48 kHz stereo frames
    send(8'h00); send(8'h01); send(8'h00); send(8'h02);
    send(8'h00); send(8'h03); send(8'h00); send(8'h04);
    send(8'h00); send(8'h05); send(8'h00); send(8'h06);

    for (i = 0; i < 64; i = i + 1)
        send_video(8'h20 + i[7:0]);

    @(negedge clk);
    input_end = 1;
    repeat (20) @(posedge clk);
    @(negedge clk);
    input_end = 0;

    if (received_count != 0)
        $fatal(1,"decoder received %0d bytes while held",received_count);
    if (metadata_seen != 0)
        $fatal(1,"metadata outran queued video");
    if (pcm_seen != 3 || pcm_sample_count != 3)
        $fatal(1,"PCM remained blocked behind video: seen=%0d count=%0d",
               pcm_seen,pcm_sample_count);
    if (pcm_protocol_error)
        $fatal(1,"valid PCM run reported a protocol error");

    @(negedge clk);
    output_ready = 1;
    repeat (220) @(posedge clk);

    if (received_count != expected_count)
        $fatal(1,"clean byte count %0d expected %0d",
               received_count,expected_count);
    for (i = 0; i < expected_count; i = i + 1)
        if (received[i] !== expected[i])
            $fatal(1,"clean byte %0d got %h expected %h",
                   i,received[i],expected[i]);
    if (metadata_seen != 2 || metadata_position[0] != 32 ||
        metadata_position[1] != 96 || metadata_pts[0] != 33'd90000 ||
        metadata_pts[1] != 33'd180000)
        $fatal(1,"metadata ordering failed seen=%0d pos=%0d/%0d pts=%0d/%0d",
               metadata_seen,metadata_position[0],metadata_position[1],
               metadata_pts[0],metadata_pts[1]);

    $display("H262_CLEAN_VIDEO_QUEUE_PASS bytes=%0d pcm=%0d metadata=%0d",
             received_count,pcm_seen,metadata_seen);
    $finish;
end

endmodule

// Minimal show-ahead behavioral model for both queue instances.
module scfifo #(
    parameter integer lpm_numwords = 16,
    parameter lpm_showahead = "ON",
    parameter lpm_type = "scfifo",
    parameter integer lpm_width = 8,
    parameter integer lpm_widthu = 4,
    parameter overflow_checking = "ON",
    parameter underflow_checking = "ON",
    parameter use_eab = "ON"
)(
    input wire aclr,
    input wire clock,
    input wire [lpm_width-1:0] data,
    input wire wrreq,
    output wire full,
    output wire [lpm_width-1:0] q,
    input wire rdreq,
    output wire empty
);

reg [lpm_width-1:0] memory [0:lpm_numwords-1];
integer write_pointer = 0;
integer read_pointer = 0;
integer count = 0;

assign full = count == lpm_numwords;
assign empty = count == 0;
assign q = memory[read_pointer];

always @(posedge clock or posedge aclr) begin
    if (aclr) begin
        write_pointer <= 0;
        read_pointer <= 0;
        count <= 0;
    end
    else begin
        case ({wrreq && !full,rdreq && !empty})
        2'b10: begin
            memory[write_pointer] <= data;
            write_pointer <= (write_pointer + 1) % lpm_numwords;
            count <= count + 1;
        end
        2'b01: begin
            read_pointer <= (read_pointer + 1) % lpm_numwords;
            count <= count - 1;
        end
        2'b11: begin
            memory[write_pointer] <= data;
            write_pointer <= (write_pointer + 1) % lpm_numwords;
            read_pointer <= (read_pointer + 1) % lpm_numwords;
        end
        default: begin end
        endcase
    end
end

endmodule
