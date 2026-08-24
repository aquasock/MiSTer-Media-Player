// Entry 395: codec-independent PCM clock-domain FIFO.
// Word layout: {end, rate_48k, stereo, left[15:0], right[15:0]}.
// 8192 samples provide 170.7 ms at 48 kHz, covering the longest measured
// Program Stream video-PES run while backpressure prevents producer overrun.

module audio_pcm_fifo
(
    input  wire        reset,

    input  wire        wr_clk,
    input  wire [34:0] wr_data,
    input  wire        wr_en,
    output wire        wr_full,
    output wire [12:0] wr_used,

    input  wire        rd_clk,
    input  wire        rd_en,
    output wire [34:0] rd_data,
    output wire        rd_empty,
    output wire [12:0] rd_used
);

dcfifo #(
    .lpm_numwords         (8192),
    .lpm_showahead        ("ON"),
    .lpm_type             ("dcfifo"),
    .lpm_width            (35),
    .lpm_widthu           (13),
    .overflow_checking    ("ON"),
    .underflow_checking   ("ON"),
    .use_eab              ("ON"),
    .rdsync_delaypipe     (4),
    .wrsync_delaypipe     (4),
    .write_aclr_synch     ("ON"),
    .read_aclr_synch      ("ON")
) pcm_fifo
(
    .aclr    (reset),

    .data    (wr_data),
    .wrclk   (wr_clk),
    .wrreq   (wr_en),
    .wrfull  (wr_full),
    .wrusedw (wr_used),

    .q       (rd_data),
    .rdclk   (rd_clk),
    .rdreq   (rd_en),
    .rdempty (rd_empty),
    .rdusedw (rd_used)
);

endmodule
