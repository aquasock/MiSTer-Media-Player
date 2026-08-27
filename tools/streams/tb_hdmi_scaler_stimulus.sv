`timescale 1ps/1ps
// Generate a cycle-exact, run-length-compressed trace at ASCAL's input.
// Production timing, framebuffer control outputs, sync_fix and scanlines are
// instantiated unchanged. RGB alone is replaced by an independently labelled
// source at the framebuffer output; this does NOT simulate MPEG reconstruction.
module tb_hdmi_scaler_stimulus #(parameter TRACE_ONLY = 1);
    reg done = 0;
    reg clk = 0;
    always #9259 clk = ~clk;
    reg mem_clk = 0;
    always #8333 mem_clk = ~mem_clk;
    reg reset = 1;
    reg request = 0;
    reg tff = 1;
    wire native_active, ce, de, hs, vs, field, fw, frame_window;
    wire [11:0] x, y;
    mpeg2_video_output_timing timing (
        .clk(clk), .reset(reset), .native_request_async(request),
        .top_field_first_async(tff), .native_active(native_active),
        .ce_pixel(ce), .h_pos(x), .v_pos(y), .pixel_en(de),
        .h_sync(hs), .v_sync(vs), .field(field), .field_window(fw),
        .frame_window(frame_window)
    );
    wire fb_de, fb_hs, fb_vs;
    reg swap_resets = 1;
    reg [2:0] window_sync = 0, native_sync = 0;
    reg window_prev = 0;
    reg [2:0] swap_reset_count = 0;
    integer reset_events = 0;
    // Same crossing and four decoder-clock reset width as top_04/top_06 and
    // b_presentation_scheduler. Model a ready picture at each frame window;
    // this is stimulus, not a model of the scheduler's ownership decisions.
    always @(posedge mem_clk) begin
        if (reset) begin
            window_sync<=0; native_sync<=0; window_prev<=0; swap_reset_count<=0;
        end else begin
            window_sync<={window_sync[1:0],frame_window};
            native_sync<={native_sync[1:0],native_active};
            window_prev<=window_sync[2];
            if (window_sync[2] && !window_prev) begin
                swap_reset_count<=4;
                reset_events++;
            end else if (swap_reset_count!=0) swap_reset_count<=swap_reset_count-1'b1;
        end
    end
    wire framebuffer_reset = reset || (swap_resets &&
        ((swap_reset_count!=0) || (native_sync[1]!=native_sync[2])));
    mpeg2_luma_framebuffer framebuffer (
        .reset(framebuffer_reset), .mem_clk(mem_clk), .picture_complete(1'b0),
        .horizontal_size(14'd720), .vertical_size(14'd480),
        .native_interlaced(native_active), .top_field_first(tff),
        .framebuffer_generation(8'd0), .write_read_expected_region(3'd0),
        .write_read_expected_valid(1'b0),
        .write_read_expected_even_fingerprint(32'd0),
        .write_read_expected_odd_fingerprint(32'd0),
        .ddram_busy(1'b0), .ddram_dout(64'd0), .ddram_dout_ready(1'b0),
        .rd_clk(clk), .h_pos(x), .v_pos(y), .pixel_ce(ce), .pixel_en(de),
        .h_sync(hs), .v_sync(vs), .video_de(fb_de),
        .video_hs(fb_hs), .video_vs(fb_vs)
    );
    wire fixed_hs, fixed_vs;
    sync_fix sync_h(clk, fb_hs, fixed_hs);
    sync_fix sync_v(clk, fb_vs, fixed_vs);
    reg [23:0] rgb = 0;
    wire [23:0] out_rgb;
    wire out_de, out_hs, out_vs, out_ce;
    scanlines #(0) pipeline (
        .clk(clk), .scanlines(2'b00), .din(fb_de ? rgb : 24'd0),
        .hs_in(fixed_hs), .vs_in(fixed_vs), .de_in(fb_de), .ce_in(ce),
        .dout(out_rgb), .hs_out(out_hs), .vs_out(out_vs),
        .de_out(out_de), .ce_out(out_ce)
    );

    integer fields = 0, pictures = 0, limit = 20;
    integer hold_start = 0, hold_length = 0;
    integer generation, logical_generation, bar_left;
    reg progressive = 0, identical = 0, stale = 0;
    reg prev_field = 0, prev_native = 0, prev_window = 0;
    // Green identifies the input parity. Red identifies its source picture.
    // The hold and stale cases intentionally alter the SOURCE, never the DUT.
    always @(posedge clk) begin
        if (ce && !reset) begin
            prev_field <= field;
            prev_native <= native_active;
            prev_window <= frame_window;
            if (native_active && (!prev_native || field != prev_field)) begin
                fields = fields + 1;
                if (field == !tff) pictures = pictures + 1;
            end
            if (progressive && frame_window && !prev_window) begin
                pictures = pictures + 1;
                fields = fields + 1;
            end
            generation = pictures;
            if (hold_length > 0 && pictures >= hold_start) begin
                if (pictures < hold_start + hold_length) generation = hold_start;
                else generation = pictures - hold_length;
            end
            logical_generation = generation;
            if (stale && native_active && field == 0 && pictures >= 6)
                generation = 5;
            bar_left = (generation * 16 + ((!identical && field) ? 4 : 0)) % 640;
            rgb <= {8'(32 + generation * 2),
                    (identical || progressive || !field) ? 8'd64 : 8'd192,
                    ((x >= bar_left) && (x < bar_left+32) &&
                     (y >= 64) && (y < 416)) ? 8'd224 : 8'd96};
        end
    end

    integer fd, runs = 0, phase = 0, cycles = 0;
    reg [115:0] packet = 0, previous = 0;
    string trace_path;
    // Each packet contains four consecutive input-clock samples, including
    // CE and changes BETWEEN CE pulses. This preserves raw VS/field timing.
    always @(negedge clk) begin
        packet[phase*29 +: 29] = {out_ce, out_de, out_hs, out_vs, field, out_rgb};
        phase = phase + 1;
        cycles = cycles + 1;
        if (phase == 4) begin
            if (runs != 0 && packet != previous) begin
                if (TRACE_ONLY) $fdisplay(fd, "%0d %029h", runs, previous);
                runs = 0;
            end
            previous = packet;
            runs = runs + 1;
            phase = 0;
            if (!done && fields >= limit && (progressive ? frame_window : fw)) begin
                done = 1;
                if (TRACE_ONLY) begin
                    $fdisplay(fd, "%0d %029h", runs, previous);
                    $fclose(fd);
                end
                $display("STIMULUS fields=%0d pictures=%0d cycles=%0d progressive=%0d identical=%0d stale=%0d", fields, pictures, cycles, progressive, identical, stale);
                if (TRACE_ONLY) $finish;
            end
        end
    end
    initial begin
        if (TRACE_ONLY && !$value$plusargs("TRACE=%s", trace_path)) $fatal(1, "TRACE required");
        if ($value$plusargs("FIELDS=%d", limit)) begin end
        if ($value$plusargs("HOLD_START=%d", hold_start)) begin end
        if ($value$plusargs("HOLD_LENGTH=%d", hold_length)) begin end
        progressive = $test$plusargs("PROGRESSIVE");
        swap_resets = !$test$plusargs("NO_SWAP_RESETS");
        identical = $test$plusargs("IDENTICAL");
        stale = $test$plusargs("STALE");
        tff = !$test$plusargs("BFF");
        if (TRACE_ONLY) begin
            fd = $fopen(trace_path, "w");
            if (fd == 0) $fatal(1, "Cannot open trace");
        end
        repeat (16) @(negedge clk);
        reset = 0;
        request = !progressive;
    end
endmodule
