`timescale 1ns/1ps

module tb_audio_spdif_route;
    reg         spdif_enable;
    reg         spdif_non_audio;
    reg  [15:0] processed_l;
    reg  [15:0] processed_r;
    reg  [15:0] raw_l;
    reg  [15:0] raw_r;
    wire [15:0] i2s_l;
    wire [15:0] i2s_r;
    wire [15:0] spdif_l;
    wire [15:0] spdif_r;
    wire        spdif_channel_non_audio;

    audio_spdif_route dut(
        .spdif_enable(spdif_enable),
        .spdif_non_audio(spdif_non_audio),
        .processed_l(processed_l),
        .processed_r(processed_r),
        .raw_l(raw_l),
        .raw_r(raw_r),
        .i2s_l(i2s_l),
        .i2s_r(i2s_r),
        .spdif_l(spdif_l),
        .spdif_r(spdif_r),
        .spdif_channel_non_audio(spdif_channel_non_audio)
    );

    task check;
        input [15:0] expected_i2s_l;
        input [15:0] expected_i2s_r;
        input [15:0] expected_spdif_l;
        input [15:0] expected_spdif_r;
        input        expected_non_audio;
        begin
            #1;
            if (i2s_l !== expected_i2s_l || i2s_r !== expected_i2s_r ||
                spdif_l !== expected_spdif_l || spdif_r !== expected_spdif_r ||
                spdif_channel_non_audio !== expected_non_audio)
                $fatal(1,
                    "route mismatch enable=%0d non_audio=%0d i2s=%h/%h spdif=%h/%h status=%0d",
                    spdif_enable, spdif_non_audio, i2s_l, i2s_r,
                    spdif_l, spdif_r, spdif_channel_non_audio);
        end
    endtask

    initial begin
        processed_l = 16'h1234;
        processed_r = 16'hFEDC;
        raw_l = 16'hF872;
        raw_r = 16'h4E1F;

        // HDMI selection: processed PCM on I2S, S/PDIF muted.
        spdif_enable = 0; spdif_non_audio = 0;
        check(16'h1234, 16'hFEDC, 16'h0000, 16'h0000, 1'b0);

        // S/PDIF PCM: processed samples, ordinary audio channel status.
        spdif_enable = 1; spdif_non_audio = 0;
        check(16'h0000, 16'h0000, 16'h1234, 16'hFEDC, 1'b0);

        // S/PDIF IEC 61937: raw burst words, non-audio channel status.
        spdif_enable = 1; spdif_non_audio = 1;
        check(16'h0000, 16'h0000, 16'hF872, 16'h4E1F, 1'b1);

        // A stale non-audio flag cannot affect HDMI selection.
        spdif_enable = 0; spdif_non_audio = 1;
        check(16'h1234, 16'hFEDC, 16'h0000, 16'h0000, 1'b0);

        $display("AUDIO_SPDIF_ROUTE_PASS");
        $finish;
    end
endmodule
