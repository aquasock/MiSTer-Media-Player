`timescale 1ns/1ps

// Standalone unit test for rtl/mpeg2_new/mpeg2_h262_live_deadlock_probe.sv.
// Verifies: (1) pixels outside the probe's fixed box pass the base color
// through unchanged, (2) both rows draw the fixed (1,0,1,0) alignment
// prefix the decode tool checks, and (3) the two data words drawn match
// the live mpeg2-domain inputs, including the free-running progress
// counters advancing only on their own pulse.
module test_live_deadlock_probe;

reg clk_mpeg2=0, reset_mpeg2=1;
reg clk_video=0, reset_video=1;
reg pixel_ce=1;
reg [11:0] h_pos=0, v_pos=0;
reg [7:0] base_r=8'hAB, base_g=8'hCD, base_b=8'hEF;

reg stream_full=0, burst_ready=0;
reg p_destination_ownership_hold=0, b_presentation_hold=0;
reg [1:0] active_frame_bank=0, display_frame_bank=0;
reg display_scratch=0;
reg picture_complete_pulse=0, display_swap_pulse=0;

wire [7:0] video_r, video_g, video_b;

always #5  clk_mpeg2 = ~clk_mpeg2;
always #3  clk_video = ~clk_video;

mpeg2_h262_live_deadlock_probe dut(
    .clk_mpeg2(clk_mpeg2), .reset_mpeg2(reset_mpeg2),
    .clk_video(clk_video), .reset_video(reset_video),
    .pixel_ce(pixel_ce), .h_pos(h_pos), .v_pos(v_pos),
    .base_r(base_r), .base_g(base_g), .base_b(base_b),
    .stream_full(stream_full), .burst_ready(burst_ready),
    .p_destination_ownership_hold(p_destination_ownership_hold),
    .b_presentation_hold(b_presentation_hold),
    .active_frame_bank(active_frame_bank),
    .display_frame_bank(display_frame_bank),
    .display_scratch(display_scratch),
    .picture_complete_pulse(picture_complete_pulse),
    .display_swap_pulse(display_swap_pulse),
    .video_r(video_r), .video_g(video_g), .video_b(video_b)
);

task fail; input [8*160-1:0] message; begin $display("FAIL: %0s",message); $fatal(1); end endtask

// One video-domain sample: drive h_pos/v_pos, wait a clk_video edge for the
// registered draw stage, then read back video_r/g/b.
task sample; input [11:0] h; input [11:0] v; output [7:0] r; output [7:0] g; output [7:0] b;
begin
    @(negedge clk_video); h_pos=h; v_pos=v;
    @(posedge clk_video); #1;
    r=video_r; g=video_g; b=video_b;
end
endtask

reg [7:0] r,g,b;
integer col;
reg [31:0] word0, word1;

initial begin
    repeat(4) @(posedge clk_mpeg2);
    reset_mpeg2=0; reset_video=0;
    repeat(4) @(posedge clk_mpeg2);

    // Pixel well outside the probe's box must pass the base color through.
    sample(12'd500, 12'd500, r,g,b);
    if (r!==base_r || g!==base_g || b!==base_b)
        fail("pixel outside the probe box did not pass the base color through");

    // Drive distinct live state and two picture completions plus one
    // display swap, then let the double-flop synchronizer settle.
    stream_full=1; burst_ready=0;
    p_destination_ownership_hold=1; b_presentation_hold=0;
    active_frame_bank=2'd1; display_frame_bank=2'd2; display_scratch=0;
    @(negedge clk_mpeg2); picture_complete_pulse=1; @(negedge clk_mpeg2); picture_complete_pulse=0;
    @(negedge clk_mpeg2); picture_complete_pulse=1; @(negedge clk_mpeg2); picture_complete_pulse=0;
    @(negedge clk_mpeg2); display_swap_pulse=1; @(negedge clk_mpeg2); display_swap_pulse=0;
    repeat(6) @(posedge clk_video); // let the 2-flop CDC settle

    // Row 0: fixed prefix, then word0 data bits.
    for (col=0; col<4; col=col+1) begin
        sample(12'd8 + col*4, 12'd616, r,g,b);
        if (col[0]==1'b0) begin // columns 0,2 expect prefix bit 1
            if (r!==8'hFF) fail("row 0 prefix bit expected set (1) but was clear");
        end else begin
            if (r!==8'h00) fail("row 0 prefix bit expected clear (0) but was set");
        end
    end
    word0 = 0;
    for (col=0; col<32; col=col+1) begin
        sample(12'd8 + (col+4)*4, 12'd616, r,g,b);
        word0 = word0 | ((r==8'hFF) << col);
    end
    if (word0[15:0] !== 16'd2)
        fail("decode_progress_count did not read back as 2 after two completions");
    if (word0[17:16] !== active_frame_bank) fail("active_frame_bank field mismatch");
    if (word0[19:18] !== display_frame_bank) fail("display_frame_bank field mismatch");
    if (word0[20] !== display_scratch) fail("display_scratch field mismatch");
    if (word0[21] !== stream_full) fail("stream_full field mismatch");
    if (word0[22] !== burst_ready) fail("burst_ready field mismatch");
    if (word0[23] !== p_destination_ownership_hold) fail("p_destination_ownership_hold field mismatch");
    if (word0[24] !== b_presentation_hold) fail("b_presentation_hold field mismatch");

    // Row 1: fixed prefix, then word1 (display_progress_count).
    for (col=0; col<4; col=col+1) begin
        sample(12'd8 + col*4, 12'd620, r,g,b);
        if (col[0]==1'b0) begin
            if (r!==8'hFF) fail("row 1 prefix bit expected set (1) but was clear");
        end else begin
            if (r!==8'h00) fail("row 1 prefix bit expected clear (0) but was set");
        end
    end
    word1 = 0;
    for (col=0; col<32; col=col+1) begin
        sample(12'd8 + (col+4)*4, 12'd620, r,g,b);
        word1 = word1 | ((r==8'hFF) << col);
    end
    if (word1[15:0] !== 16'd1)
        fail("display_progress_count did not read back as 1 after one swap pulse");

    // A picture completion alone must not move the display counter, and
    // vice versa - the two counters are independent.
    @(negedge clk_mpeg2); picture_complete_pulse=1; @(negedge clk_mpeg2); picture_complete_pulse=0;
    repeat(6) @(posedge clk_video);
    sample(12'd8+4*4, 12'd620, r,g,b);
    if (r!==8'hFF) fail("display_progress_count LSB moved on a decode-only pulse");

    $display("PASS: live deadlock probe draws a correct box, prefix and live data words");
    $finish;
end
endmodule
