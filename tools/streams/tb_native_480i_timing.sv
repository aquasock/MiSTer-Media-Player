`timescale 1ns/1ps

module tb_native_480i_timing;

reg clk = 1'b0;
reg reset = 1'b1;
reg native_request = 1'b0;
reg top_field_first = 1'b1;

wire native_active;
wire ce_pixel;
wire [11:0] h_pos;
wire [11:0] v_pos;
wire pixel_en;
wire h_sync;
wire v_sync;
wire field;
wire field_window;
wire frame_window;

mpeg2_video_output_timing dut
(
    .clk                     (clk),
    .reset                   (reset),
    .native_request_async    (native_request),
    .top_field_first_async   (top_field_first),
    .native_active           (native_active),
    .ce_pixel                (ce_pixel),
    .h_pos                   (h_pos),
    .v_pos                   (v_pos),
    .pixel_en                (pixel_en),
    .h_sync                  (h_sync),
    .v_sync                  (v_sync),
    .field                   (field),
    .field_window            (field_window),
    .frame_window            (frame_window)
);

always #9.259 clk = ~clk;

integer errors;
integer clock_gap;
integer field_ticks;
integer active_ticks;
integer hsync_low_ticks;
integer vsync_low_ticks;
integer field_count;
integer field_window_rises;
integer frame_window_rises;
integer line_sample_count [0:239];
integer i;
reg sampled_field;
reg old_field_window;
reg old_frame_window;
reg bff;

task fail;
    input [8*160-1:0] message;
    begin
        $display("FAIL: %0s", message);
        errors = errors + 1;
    end
endtask

task clear_field_counts;
    begin
        field_ticks = 0;
        active_ticks = 0;
        hsync_low_ticks = 0;
        vsync_low_ticks = 0;
        for (i = 0; i < 240; i = i + 1)
            line_sample_count[i] = 0;
    end
endtask

task check_completed_field;
    input completed_field;
    begin
        if (field_ticks != 225225) begin
            $display("field %0d ticks=%0d expected=225225",
                     completed_field, field_ticks);
            errors = errors + 1;
        end
        if (active_ticks != 172800) begin
            $display("field %0d active=%0d expected=172800",
                     completed_field, active_ticks);
            errors = errors + 1;
        end
        if (vsync_low_ticks != 2574) begin
            $display("field %0d vsync_low=%0d expected=2574",
                     completed_field, vsync_low_ticks);
            errors = errors + 1;
        end
        if (!completed_field && (hsync_low_ticks != 16244)) begin
            $display("top hsync_low=%0d expected=16244", hsync_low_ticks);
            errors = errors + 1;
        end
        if (completed_field && (hsync_low_ticks != 16306)) begin
            $display("bottom hsync_low=%0d expected=16306", hsync_low_ticks);
            errors = errors + 1;
        end
        for (i = 0; i < 240; i = i + 1) begin
            if (line_sample_count[i] != 720) begin
                $display("field %0d line %0d samples=%0d expected=720",
                         completed_field, i, line_sample_count[i]);
                errors = errors + 1;
            end
        end
    end
endtask

initial begin
    errors = 0;
    clock_gap = 0;
    field_count = 0;
    field_window_rises = 0;
    frame_window_rises = 0;
    old_field_window = 1'b0;
    old_frame_window = 1'b0;
    bff = $test$plusargs("BFF");
    top_field_first = !bff;

    repeat (8) @(posedge clk);
    reset = 1'b0;
    native_request = 1'b1;

    wait (native_active);
    @(negedge clk);

    sampled_field = field;
    if (sampled_field != bff)
        fail("native mode did not begin with the authored field");
    clear_field_counts();

    while (field_count < 4) begin
        @(negedge clk);
        clock_gap = clock_gap + 1;

        if (ce_pixel) begin
            if ((field_ticks != 0) && (clock_gap != 4)) begin
                $display("native CE gap=%0d expected=4", clock_gap);
                errors = errors + 1;
            end
            clock_gap = 0;

            if (field != sampled_field) begin
                check_completed_field(sampled_field);
                field_count = field_count + 1;
                sampled_field = field;
                clear_field_counts();
            end

            field_ticks = field_ticks + 1;
            if (!h_sync)
                hsync_low_ticks = hsync_low_ticks + 1;
            if (!v_sync)
                vsync_low_ticks = vsync_low_ticks + 1;

            if (pixel_en) begin
                active_ticks = active_ticks + 1;
                if (h_pos >= 720)
                    fail("active native sample lies outside h=0..719");
                if (v_pos[0] != field)
                    fail("native source-line parity does not match field");
                if (v_pos[8:1] >= 240)
                    fail("native source line lies outside 480-line frame");
                else
                    line_sample_count[v_pos[8:1]] =
                        line_sample_count[v_pos[8:1]] + 1;
            end

            if (field_window && !old_field_window)
                field_window_rises = field_window_rises + 1;
            if (frame_window && !old_frame_window)
                frame_window_rises = frame_window_rises + 1;
            old_field_window = field_window;
            old_frame_window = frame_window;
        end
    end

    if (field_window_rises != 4) begin
        $display("field-window rises=%0d expected=4", field_window_rises);
        errors = errors + 1;
    end
    if (frame_window_rises != 2) begin
        $display("frame-window rises=%0d expected=2", frame_window_rises);
        errors = errors + 1;
    end

    if (errors != 0) begin
        $display("RESULT mode=%s errors=%0d", bff ? "BFF" : "TFF", errors);
        $fatal(1);
    end

    $display({"RESULT mode=%s fields=4 field_ticks=225225 active=172800 ",
              "vsync=2574 half_line=429 ce_div=4 PASS"},
             bff ? "BFF" : "TFF");
    $finish;
end

initial begin
    #200000000;
    $fatal(1, "timeout");
end

endmodule
