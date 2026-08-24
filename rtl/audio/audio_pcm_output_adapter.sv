// Entry 395: MiSTer PCM output adapter.
//
// CLK_AUDIO is 24.576 MHz. 48 kHz is exactly one sample per 512 clocks.
// 44.1 kHz uses an integer phase accumulator: its average rate is exact and
// each sample event is scheduled with at most one CLK_AUDIO period of jitter.

module audio_pcm_output_adapter #(
    parameter [12:0] PREFILL_SAMPLES = 13'd2048
)
(
    input  wire        clk,
    input  wire        reset,

    input  wire [34:0] fifo_data,
    input  wire        fifo_empty,
    input  wire [12:0] fifo_used,
    input  wire        source_ended,
    output reg         fifo_rd,

    output reg  [15:0] audio_l,
    output reg  [15:0] audio_r,
    output reg         underrun,
    output reg         playback_complete
);

localparam [25:0] AUDIO_CLK_HZ = 26'd24576000;
localparam [25:0] RATE_44100   = 26'd44100;
localparam [25:0] RATE_48000   = 26'd48000;

wire        fifo_end      = fifo_data[34];
wire        fifo_rate_48k = fifo_data[33];
wire        fifo_stereo   = fifo_data[32];
wire [15:0] fifo_left     = fifo_data[31:16];
wire [15:0] fifo_right    = fifo_data[15:0];

reg         started;
reg         starvation_waiting;
reg         current_rate_48k;
reg  [25:0] phase_accum;

wire [25:0] rate_step = current_rate_48k ? RATE_48000 : RATE_44100;
wire [26:0] phase_sum = {1'b0, phase_accum} + {1'b0, rate_step};
wire prefill_ready = (fifo_used >= PREFILL_SAMPLES) || source_ended;

always @(posedge clk) begin
    if (reset) begin
        fifo_rd          <= 1'b0;
        audio_l          <= 16'd0;
        audio_r          <= 16'd0;
        underrun         <= 1'b0;
        playback_complete <= 1'b0;
        started          <= 1'b0;
        starvation_waiting <= 1'b0;
        current_rate_48k <= 1'b0;
        phase_accum      <= 26'd0;
    end
    else begin
        fifo_rd <= 1'b0;

        if (!started) begin
            phase_accum <= 26'd0;
            if (!playback_complete && prefill_ready && !fifo_empty) begin
                fifo_rd <= 1'b1;
                if (fifo_end) begin
                    audio_l <= 16'd0;
                    audio_r <= 16'd0;
                    starvation_waiting <= 1'b0;
                    playback_complete <= 1'b1;
                end
                else begin
                    audio_l          <= fifo_left;
                    audio_r          <= fifo_stereo ? fifo_right : fifo_left;
                    current_rate_48k <= fifo_rate_48k;
                    started          <= 1'b1;
                    starvation_waiting <= 1'b0;
                end
            end
        end
        else if (phase_sum >= {1'b0, AUDIO_CLK_HZ}) begin
            phase_accum <= phase_sum[25:0] - AUDIO_CLK_HZ;
            if (!fifo_empty) begin
                fifo_rd <= 1'b1;
                if (fifo_end) begin
                    audio_l  <= 16'd0;
                    audio_r  <= 16'd0;
                    started  <= 1'b0;
                    starvation_waiting <= 1'b0;
                    playback_complete <= 1'b1;
                end
                else begin
                    audio_l          <= fifo_left;
                    audio_r          <= fifo_stereo ? fifo_right : fifo_left;
                    current_rate_48k <= fifo_rate_48k;
                    if (starvation_waiting)
                        underrun <= 1'b1;
                    starvation_waiting <= 1'b0;
                end
            end
            else begin
                audio_l  <= 16'd0;
                audio_r  <= 16'd0;
                starvation_waiting <= 1'b1;
            end
        end
        else begin
            phase_accum <= phase_sum[25:0];
        end
    end
end

endmodule
