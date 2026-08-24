// Entry 395: deterministic codec-independent PCM producer.
//
// This is a hardware proof source, not a codec. It advances waveform state
// only when valid && ready, so downstream backpressure cannot lose or duplicate
// source samples. A future decoder can replace this producer while retaining
// the same PCM-side contract.

module audio_pcm_test_source
(
    input  wire               clk,
    input  wire               reset,
    input  wire [2:0]         mode,
    input  wire               ready,

    output wire               valid,
    output wire signed [15:0] left,
    output wire signed [15:0] right,
    output wire               stereo,
    output wire               rate_48k
);

localparam [31:0] PHASE_440_44100 = 32'h028DDFB9;
localparam [31:0] PHASE_660_44100 = 32'h03D4CF96;
localparam [31:0] PHASE_440_48000 = 32'h0258BF26;
localparam [31:0] PHASE_660_48000 = 32'h03851EB8;

wire mode_valid = (mode >= 3'd1) && (mode <= 3'd4);
assign rate_48k = (mode == 3'd3) || (mode == 3'd4);
assign stereo   = (mode == 3'd2) || (mode == 3'd4);
assign valid    = mode_valid;

reg [31:0] phase_left;
reg [31:0] phase_right;

wire [31:0] left_step  = rate_48k ? PHASE_440_48000 : PHASE_440_44100;
wire [31:0] right_step = rate_48k ? PHASE_660_48000 : PHASE_660_44100;

assign left  = phase_left[31]  ? 16'sh2000 : -16'sh2000;
assign right = phase_right[31] ? 16'sh2000 : -16'sh2000;

always @(posedge clk) begin
    if (reset) begin
        phase_left  <= 32'd0;
        phase_right <= 32'd0;
    end
    else if (valid && ready) begin
        phase_left  <= phase_left  + left_step;
        phase_right <= phase_right + right_step;
    end
end

endmodule
