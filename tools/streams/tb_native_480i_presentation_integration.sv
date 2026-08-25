`timescale 1ns/1ps

module tb_native_480i_presentation_integration;

reg clk_video = 1'b0;
reg clk_mpeg2 = 1'b0;
reg reset_video = 1'b1;
reg reset_mpeg2 = 1'b1;
reg native_request = 1'b0;

always #9.259 clk_video = ~clk_video;
always #8.333 clk_mpeg2 = ~clk_mpeg2;

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

mpeg2_video_output_timing timing
(
    .clk                   (clk_video),
    .reset                 (reset_video),
    .native_request_async  (native_request),
    .top_field_first_async (1'b1),
    .native_active         (native_active),
    .ce_pixel              (ce_pixel),
    .h_pos                 (h_pos),
    .v_pos                 (v_pos),
    .pixel_en              (pixel_en),
    .h_sync                (h_sync),
    .v_sync                (v_sync),
    .field                 (field),
    .field_window          (field_window),
    .frame_window          (frame_window)
);

reg cadence_window_video = 1'b0;
reg swap_window_video = 1'b0;
reg [2:0] cadence_window_sync = 3'b000;
reg [2:0] swap_window_sync = 3'b000;

always @(posedge clk_video) begin
    if (reset_video) begin
        cadence_window_video <= 1'b0;
        swap_window_video <= 1'b0;
    end
    else begin
        cadence_window_video <= field_window;
        swap_window_video <= frame_window;
    end
end

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        cadence_window_sync <= 3'b000;
        swap_window_sync <= 3'b000;
    end
    else begin
        cadence_window_sync <=
            {cadence_window_sync[1:0], cadence_window_video};
        swap_window_sync <= {swap_window_sync[1:0], swap_window_video};
    end
end

wire cadence_tick_pulse =
    cadence_window_sync[1] && !cadence_window_sync[2];
wire swap_window_pulse = swap_window_sync[1] && !swap_window_sync[2];

reg frame_waiting = 1'b0;
reg non_b_picture_start = 1'b0;
reg [1:0] completed_frame_bank = 2'd1;
reg [1:0] next_frame_bank = 2'd1;
reg [1:0] feeder_state = 2'd0;

wire [1:0] display_frame_bank;
wire display_scratch;
wire display_scratch_bank;
wire decode_scratch_bank;
wire [2:0] framebuffer_swap_reset_count;
wire presentation_complete;
wire presentation_error;

mpeg2_h262_b_presentation_scheduler scheduler
(
    .clk                         (clk_mpeg2),
    .reset                       (reset_mpeg2),
    .swap_window_pulse           (swap_window_pulse),
    .cadence_tick_pulse          (cadence_tick_pulse),
    .frame_rate_code             (4'h4),
    .timestamp_candidate_active  (1'b0),
    .timestamp_candidate_due     (1'b0),
    .frame_waiting               (frame_waiting),
    .completed_frame_bank        (completed_frame_bank),
    .reference_frame_bank        (2'd0),
    .reference_promotion_count   (8'd0),
    .b_picture_start             (1'b0),
    .non_b_picture_start         (non_b_picture_start),
    .i_picture_start             (1'b0),
    .p_picture_start             (1'b0),
    .sequence_end                (1'b0),
    .b_user_success              (1'b0),
    .b_decode_error              (1'b0),
    .display_frame_bank          (display_frame_bank),
    .display_scratch             (display_scratch),
    .display_scratch_bank        (display_scratch_bank),
    .decode_scratch_bank         (decode_scratch_bank),
    .framebuffer_swap_reset_count(framebuffer_swap_reset_count),
    .presentation_complete       (presentation_complete),
    .presentation_error          (presentation_error)
);

integer cadence_ticks = 0;
integer frame_windows = 0;
integer presentations = 0;
integer pulse_gap = 1000;
reg [1:0] display_frame_bank_d = 2'd0;

always @(posedge clk_mpeg2) begin
    frame_waiting <= 1'b0;
    non_b_picture_start <= 1'b0;

    if (reset_mpeg2) begin
        feeder_state <= 2'd0;
        completed_frame_bank <= 2'd1;
        next_frame_bank <= 2'd1;
        cadence_ticks <= 0;
        frame_windows <= 0;
        presentations <= 0;
        pulse_gap <= 1000;
        display_frame_bank_d <= 2'd0;
    end
    else begin
        if (cadence_tick_pulse) begin
            cadence_ticks <= cadence_ticks + 1;
            pulse_gap <= 0;
        end
        else if (pulse_gap < 1000)
            pulse_gap <= pulse_gap + 1;

        if (swap_window_pulse) begin
            frame_windows <= frame_windows + 1;
            if (cadence_tick_pulse)
                $fatal(1, "native cadence and swap pulses remained coincident");
            if (pulse_gap < 2)
                $fatal(1, "native cadence-to-swap CDC gap=%0d", pulse_gap);
        end

        if (display_frame_bank != display_frame_bank_d) begin
            presentations <= presentations + 1;
            display_frame_bank_d <= display_frame_bank;
        end

        case (feeder_state)
            2'd0: begin
                if (!scheduler.pending_frame_valid) begin
                    completed_frame_bank <= next_frame_bank;
                    next_frame_bank <=
                        (next_frame_bank == 2'd1) ? 2'd2 : 2'd1;
                    frame_waiting <= 1'b1;
                    feeder_state <= 2'd1;
                end
            end
            2'd1: begin
                non_b_picture_start <= 1'b1;
                feeder_state <= 2'd2;
            end
            default: begin
                if (scheduler.pending_frame_valid)
                    feeder_state <= 2'd0;
            end
        endcase
    end
end

initial begin
    repeat (8) @(posedge clk_video);
    reset_video = 1'b0;
    native_request = 1'b1;

    wait (native_active);
    repeat (4) @(posedge clk_mpeg2);
    reset_mpeg2 = 1'b0;
    wait (frame_windows == 6);
    repeat (12) @(posedge clk_mpeg2);

    if (cadence_ticks != 12)
        $fatal(1, "cadence ticks=%0d expected=12", cadence_ticks);
    if (presentations != 6)
        $fatal(1, "presentations=%0d expected=6", presentations);
    if (presentation_error)
        $fatal(1, "scheduler reported presentation error");

    $display({"NATIVE_PRESENTATION_INTEGRATION_PASS fields=12 ",
              "frame_windows=6 presentations=6 rate=30000/1001"});
    $finish;
end

initial begin
    #300000000;
    $fatal(1, "timeout");
end

endmodule
