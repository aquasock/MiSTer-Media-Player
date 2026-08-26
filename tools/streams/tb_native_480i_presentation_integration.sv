`timescale 1ns/1ps

// A decoder model takes three native fields (about 50 ms) per all-I picture.
// This matches the measured hardware latency closely enough to reproduce the
// old 15 fps decode/present serialization and prove that the third ordinary
// bank removes only the avoidable full-frame wait.
module native_all_i_feeder #(
    parameter integer DECODE_FIELDS = 3,
    parameter integer FRAME_LIMIT = 0
)
(
    input  wire       clk,
    input  wire       reset,
    input  wire       cadence_tick,
    input  wire       presentation_hold,
    output reg        frame_waiting,
    output reg [1:0]  completed_bank,
    output reg [1:0]  active_bank,
    output reg        i_picture_start,
    output reg        non_b_picture_start,
    output reg        sequence_end,
    output reg [15:0] decoded_count
);
reg decoding;
reg [2:0] fields_remaining;
reg sequence_end_sent;

function automatic [1:0] next_bank(input [1:0] bank);
begin
    next_bank = (bank == 2'd2) ? 2'd0 : bank + 1'b1;
end
endfunction

always @(posedge clk) begin
    frame_waiting <= 1'b0;
    i_picture_start <= 1'b0;
    non_b_picture_start <= 1'b0;
    sequence_end <= 1'b0;
    if (reset) begin
        frame_waiting <= 1'b0;
        completed_bank <= 2'd0;
        active_bank <= 2'd1;
        i_picture_start <= 1'b0;
        non_b_picture_start <= 1'b0;
        sequence_end <= 1'b0;
        decoding <= 1'b1;
        fields_remaining <= DECODE_FIELDS;
        decoded_count <= 16'd0;
        sequence_end_sent <= 1'b0;
    end else begin
        if (!decoding && !presentation_hold &&
            ((FRAME_LIMIT == 0) || (decoded_count < FRAME_LIMIT))) begin
            i_picture_start <= 1'b1;
            non_b_picture_start <= 1'b1;
            decoding <= 1'b1;
            fields_remaining <= DECODE_FIELDS;
        end
        if ((FRAME_LIMIT != 0) && !decoding && !presentation_hold &&
            (decoded_count == FRAME_LIMIT) && !sequence_end_sent) begin
            sequence_end <= 1'b1;
            sequence_end_sent <= 1'b1;
        end
        if (cadence_tick && decoding && !presentation_hold) begin
            if (fields_remaining == 3'd1) begin
                frame_waiting <= 1'b1;
                completed_bank <= active_bank;
                active_bank <= next_bank(active_bank);
                decoded_count <= decoded_count + 1'b1;
                decoding <= 1'b0;
                fields_remaining <= 3'd0;
            end else
                fields_remaining <= fields_remaining - 1'b1;
        end
    end
end
endmodule

module tb_native_480i_presentation_integration;
reg clk_video = 1'b0;
reg clk_mpeg2 = 1'b0;
reg reset_video = 1'b1;
reg reset_mpeg2 = 1'b1;
reg native_request = 1'b0;
always #9.259 clk_video = ~clk_video;
always #8.333 clk_mpeg2 = ~clk_mpeg2;

wire native_active,ce_pixel,pixel_en,h_sync,v_sync,field;
wire field_window,frame_window;
wire [11:0] h_pos,v_pos;
mpeg2_video_output_timing timing
(
    .clk(clk_video),.reset(reset_video),
    .native_request_async(native_request),
    .top_field_first_async(1'b1),.native_active(native_active),
    .ce_pixel(ce_pixel),.h_pos(h_pos),.v_pos(v_pos),.pixel_en(pixel_en),
    .h_sync(h_sync),.v_sync(v_sync),.field(field),
    .field_window(field_window),.frame_window(frame_window)
);

reg cadence_window_video = 1'b0;
reg swap_window_video = 1'b0;
reg [2:0] cadence_window_sync = 3'b000;
reg [2:0] swap_window_sync = 3'b000;
always @(posedge clk_video) begin
    if (reset_video) begin
        cadence_window_video <= 1'b0;
        swap_window_video <= 1'b0;
    end else begin
        cadence_window_video <= field_window;
        swap_window_video <= frame_window;
    end
end
always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        cadence_window_sync <= 3'b000;
        swap_window_sync <= 3'b000;
    end else begin
        cadence_window_sync <= {cadence_window_sync[1:0],cadence_window_video};
        swap_window_sync <= {swap_window_sync[1:0],swap_window_video};
    end
end
wire cadence_tick_pulse = cadence_window_sync[1]&&!cadence_window_sync[2];
wire swap_window_pulse = swap_window_sync[1]&&!swap_window_sync[2];

wire base_waiting,base_i_start,base_non_b_start,base_sequence_end;
wire [1:0] base_completed_bank,base_active_bank,base_display_bank;
wire base_hold,base_error;
wire [15:0] base_decoded_count;
wire overlap_waiting,overlap_i_start,overlap_non_b_start,overlap_sequence_end;
wire [1:0] overlap_completed_bank,overlap_active_bank,overlap_display_bank;
wire overlap_hold,overlap_error;
wire [15:0] overlap_decoded_count;
wire accelerated_waiting,accelerated_i_start,accelerated_non_b_start;
wire [1:0] accelerated_completed_bank,accelerated_active_bank;
wire [1:0] accelerated_display_bank;
wire accelerated_hold,accelerated_error;
wire [15:0] accelerated_decoded_count;
wire accelerated_sequence_end;
wire terminal_waiting,terminal_i_start,terminal_non_b_start;
wire terminal_sequence_end;
wire [1:0] terminal_completed_bank,terminal_active_bank;
wire [1:0] terminal_display_bank;
wire terminal_hold,terminal_error;
wire [15:0] terminal_decoded_count;

native_all_i_feeder baseline_feeder
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),.cadence_tick(cadence_tick_pulse),
    .presentation_hold(base_hold),.frame_waiting(base_waiting),
    .completed_bank(base_completed_bank),.active_bank(base_active_bank),
    .i_picture_start(base_i_start),
    .non_b_picture_start(base_non_b_start),
    .sequence_end(base_sequence_end),.decoded_count(base_decoded_count)
);
native_all_i_feeder overlap_feeder
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),.cadence_tick(cadence_tick_pulse),
    .presentation_hold(overlap_hold),.frame_waiting(overlap_waiting),
    .completed_bank(overlap_completed_bank),.active_bank(overlap_active_bank),
    .i_picture_start(overlap_i_start),
    .non_b_picture_start(overlap_non_b_start),
    .sequence_end(overlap_sequence_end),
    .decoded_count(overlap_decoded_count)
);
native_all_i_feeder #(.DECODE_FIELDS(1)) accelerated_feeder
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),.cadence_tick(cadence_tick_pulse),
    .presentation_hold(accelerated_hold),.frame_waiting(accelerated_waiting),
    .completed_bank(accelerated_completed_bank),
    .active_bank(accelerated_active_bank),
    .i_picture_start(accelerated_i_start),
    .non_b_picture_start(accelerated_non_b_start),
    .sequence_end(accelerated_sequence_end),
    .decoded_count(accelerated_decoded_count)
);
native_all_i_feeder #(.DECODE_FIELDS(1),.FRAME_LIMIT(8)) terminal_feeder
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),.cadence_tick(cadence_tick_pulse),
    .presentation_hold(terminal_hold),.frame_waiting(terminal_waiting),
    .completed_bank(terminal_completed_bank),
    .active_bank(terminal_active_bank),
    .i_picture_start(terminal_i_start),
    .non_b_picture_start(terminal_non_b_start),
    .sequence_end(terminal_sequence_end),
    .decoded_count(terminal_decoded_count)
);

mpeg2_h262_b_presentation_scheduler baseline_scheduler
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .swap_window_pulse(swap_window_pulse),
    .cadence_tick_pulse(cadence_tick_pulse),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b0),
    .active_frame_bank(base_active_bank),.frame_waiting(base_waiting),
    .completed_frame_bank(base_completed_bank),.reference_frame_bank(2'd0),
    .reference_promotion_count(8'd0),.b_picture_start(1'b0),
    .non_b_picture_start(base_non_b_start),.i_picture_start(base_i_start),
    .p_picture_start(1'b0),.sequence_end(base_sequence_end),
    .b_user_success(1'b0),
    .b_decode_error(1'b0),.display_frame_bank(base_display_bank),
    .presentation_hold(base_hold),.presentation_error(base_error)
);
mpeg2_h262_b_presentation_scheduler overlap_scheduler
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .swap_window_pulse(swap_window_pulse),
    .cadence_tick_pulse(cadence_tick_pulse),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b1),
    .active_frame_bank(overlap_active_bank),.frame_waiting(overlap_waiting),
    .completed_frame_bank(overlap_completed_bank),.reference_frame_bank(2'd0),
    .reference_promotion_count(8'd0),.b_picture_start(1'b0),
    .non_b_picture_start(overlap_non_b_start),.i_picture_start(overlap_i_start),
    .p_picture_start(1'b0),.sequence_end(overlap_sequence_end),
    .b_user_success(1'b0),
    .b_decode_error(1'b0),.display_frame_bank(overlap_display_bank),
    .presentation_hold(overlap_hold),.presentation_error(overlap_error)
);
mpeg2_h262_b_presentation_scheduler accelerated_scheduler
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .swap_window_pulse(swap_window_pulse),
    .cadence_tick_pulse(cadence_tick_pulse),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b1),
    .active_frame_bank(accelerated_active_bank),
    .frame_waiting(accelerated_waiting),
    .completed_frame_bank(accelerated_completed_bank),
    .reference_frame_bank(2'd0),.reference_promotion_count(8'd0),
    .b_picture_start(1'b0),
    .non_b_picture_start(accelerated_non_b_start),
    .i_picture_start(accelerated_i_start),.p_picture_start(1'b0),
    .sequence_end(accelerated_sequence_end),
    .b_user_success(1'b0),.b_decode_error(1'b0),
    .display_frame_bank(accelerated_display_bank),
    .presentation_hold(accelerated_hold),
    .presentation_error(accelerated_error)
);
mpeg2_h262_b_presentation_scheduler terminal_scheduler
(
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .swap_window_pulse(swap_window_pulse),
    .cadence_tick_pulse(cadence_tick_pulse),.frame_rate_code(4'h4),
    .timestamp_candidate_active(1'b0),.timestamp_candidate_due(1'b0),
    .native_ordinary_overlap_enable(1'b1),
    .active_frame_bank(terminal_active_bank),
    .frame_waiting(terminal_waiting),
    .completed_frame_bank(terminal_completed_bank),
    .reference_frame_bank(2'd0),.reference_promotion_count(8'd0),
    .b_picture_start(1'b0),.non_b_picture_start(terminal_non_b_start),
    .i_picture_start(terminal_i_start),.p_picture_start(1'b0),
    .sequence_end(terminal_sequence_end),
    .b_user_success(1'b0),.b_decode_error(1'b0),
    .display_frame_bank(terminal_display_bank),
    .presentation_hold(terminal_hold),.presentation_error(terminal_error)
);

integer cadence_ticks = 0;
integer frame_windows = 0;
integer base_presentations = 0;
integer overlap_presentations = 0;
integer accelerated_presentations = 0;
integer terminal_presentations = 0;
reg [1:0] base_display_q = 2'd0;
reg [1:0] overlap_display_q = 2'd0;
reg [1:0] accelerated_display_q = 2'd0;
reg [1:0] terminal_display_q = 2'd0;
reg [15:0] base_generation_by_bank [0:2];
reg [15:0] overlap_generation_by_bank [0:2];
reg [15:0] accelerated_generation_by_bank [0:2];
reg [15:0] terminal_generation_by_bank [0:2];
reg [2:0] base_generation_valid = 3'b000;
reg [2:0] overlap_generation_valid = 3'b000;
reg [2:0] accelerated_generation_valid = 3'b000;
reg [2:0] terminal_generation_valid = 3'b000;
reg [15:0] base_last_generation = 16'd0;
reg [15:0] overlap_last_generation = 16'd0;
reg [15:0] accelerated_last_generation = 16'd0;
reg [15:0] terminal_last_generation = 16'd0;
reg accelerated_secondary_seen = 1'b0;
reg accelerated_backpressure_seen = 1'b0;
reg terminal_secondary_seen = 1'b0;
reg terminal_sequence_seen = 1'b0;
integer bank_index;
always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        cadence_ticks <= 0;
        frame_windows <= 0;
        base_presentations <= 0;
        overlap_presentations <= 0;
        accelerated_presentations <= 0;
        terminal_presentations <= 0;
        base_display_q <= 2'd0;
        overlap_display_q <= 2'd0;
        accelerated_display_q <= 2'd0;
        terminal_display_q <= 2'd0;
        base_generation_valid <= 3'b000;
        overlap_generation_valid <= 3'b000;
        accelerated_generation_valid <= 3'b000;
        terminal_generation_valid <= 3'b000;
        base_last_generation <= 16'd0;
        overlap_last_generation <= 16'd0;
        accelerated_last_generation <= 16'd0;
        terminal_last_generation <= 16'd0;
        for (bank_index = 0; bank_index < 3; bank_index = bank_index + 1) begin
            base_generation_by_bank[bank_index] <= 16'd0;
            overlap_generation_by_bank[bank_index] <= 16'd0;
            accelerated_generation_by_bank[bank_index] <= 16'd0;
            terminal_generation_by_bank[bank_index] <= 16'd0;
        end
        accelerated_secondary_seen <= 1'b0;
        accelerated_backpressure_seen <= 1'b0;
        terminal_secondary_seen <= 1'b0;
        terminal_sequence_seen <= 1'b0;
    end else begin
        if (cadence_tick_pulse) cadence_ticks <= cadence_ticks + 1;
        if (swap_window_pulse) frame_windows <= frame_windows + 1;
        if (base_waiting) begin
            base_generation_by_bank[base_completed_bank] <= base_decoded_count;
            base_generation_valid[base_completed_bank] <= 1'b1;
        end
        if (overlap_waiting) begin
            overlap_generation_by_bank[overlap_completed_bank] <=
                overlap_decoded_count;
            overlap_generation_valid[overlap_completed_bank] <= 1'b1;
        end
        if (accelerated_waiting) begin
            accelerated_generation_by_bank[accelerated_completed_bank] <=
                accelerated_decoded_count;
            accelerated_generation_valid[accelerated_completed_bank] <= 1'b1;
        end
        if (terminal_waiting) begin
            terminal_generation_by_bank[terminal_completed_bank] <=
                terminal_decoded_count;
            terminal_generation_valid[terminal_completed_bank] <= 1'b1;
        end
        if (base_display_bank != base_display_q) begin
            if (!base_generation_valid[base_display_bank])
                $fatal(1,"serialized displayed untagged bank=%0d",
                       base_display_bank);
            if (base_generation_by_bank[base_display_bank] !=
                base_last_generation + 1'b1)
                $fatal(1,{"serialized generation order last=%0d next=%0d ",
                          "bank=%0d"},base_last_generation,
                       base_generation_by_bank[base_display_bank],
                       base_display_bank);
            base_presentations <= base_presentations + 1;
            base_display_q <= base_display_bank;
            base_last_generation <= base_generation_by_bank[base_display_bank];
        end
        if (overlap_display_bank != overlap_display_q) begin
            if (!overlap_generation_valid[overlap_display_bank])
                $fatal(1,"overlap displayed untagged bank=%0d",
                       overlap_display_bank);
            if (overlap_generation_by_bank[overlap_display_bank] !=
                overlap_last_generation + 1'b1)
                $fatal(1,{"overlap generation order last=%0d next=%0d ",
                          "bank=%0d"},overlap_last_generation,
                       overlap_generation_by_bank[overlap_display_bank],
                       overlap_display_bank);
            overlap_presentations <= overlap_presentations + 1;
            overlap_display_q <= overlap_display_bank;
            overlap_last_generation <=
                overlap_generation_by_bank[overlap_display_bank];
        end
        if (accelerated_display_bank != accelerated_display_q) begin
            if (!accelerated_generation_valid[accelerated_display_bank])
                $fatal(1,"accelerated displayed untagged bank=%0d",
                       accelerated_display_bank);
            if (accelerated_generation_by_bank[accelerated_display_bank] !=
                accelerated_last_generation + 1'b1)
                $fatal(1,{"accelerated generation order last=%0d next=%0d ",
                          "bank=%0d"},accelerated_last_generation,
                       accelerated_generation_by_bank[accelerated_display_bank],
                       accelerated_display_bank);
            accelerated_presentations <= accelerated_presentations + 1;
            accelerated_display_q <= accelerated_display_bank;
            accelerated_last_generation <=
                accelerated_generation_by_bank[accelerated_display_bank];
        end
        if (accelerated_scheduler.ordinary_secondary_valid)
            accelerated_secondary_seen <= 1'b1;
        if (accelerated_scheduler.ordinary_secondary_valid &&
            accelerated_hold)
            accelerated_backpressure_seen <= 1'b1;
        if (terminal_display_bank != terminal_display_q) begin
            if (!terminal_generation_valid[terminal_display_bank])
                $fatal(1,"terminal displayed untagged bank=%0d",
                       terminal_display_bank);
            if (terminal_generation_by_bank[terminal_display_bank] !=
                terminal_last_generation + 1'b1)
                $fatal(1,{"terminal generation order last=%0d next=%0d ",
                          "bank=%0d"},terminal_last_generation,
                       terminal_generation_by_bank[terminal_display_bank],
                       terminal_display_bank);
            terminal_presentations <= terminal_presentations + 1;
            terminal_display_q <= terminal_display_bank;
            terminal_last_generation <=
                terminal_generation_by_bank[terminal_display_bank];
        end
        if (terminal_scheduler.ordinary_secondary_valid)
            terminal_secondary_seen <= 1'b1;
        if (terminal_sequence_end)
            terminal_sequence_seen <= 1'b1;
    end
end

initial begin
    repeat (8) @(posedge clk_video);
    reset_video = 1'b0;
    native_request = 1'b1;
    wait (native_active);
    repeat (4) @(posedge clk_mpeg2);
    reset_mpeg2 = 1'b0;
    wait (frame_windows == 20);
    repeat (12) @(posedge clk_mpeg2);
    if (cadence_ticks != 40)
        $fatal(1,"cadence ticks=%0d expected=40",cadence_ticks);
    if (base_error || overlap_error || accelerated_error || terminal_error)
        $fatal(1,{"presentation error baseline=%0d overlap=%0d ",
                  "accelerated=%0d terminal=%0d"},
               base_error,overlap_error,accelerated_error,terminal_error);
    if (base_decoded_count != 16'd10)
        $fatal(1,"serialized decoded=%0d expected=10",base_decoded_count);
    if (overlap_decoded_count != 16'd13)
        $fatal(1,"overlap decoded=%0d expected=13",overlap_decoded_count);
    if (base_presentations != 10)
        $fatal(1,"serialized presentations=%0d expected=10",base_presentations);
    if (overlap_presentations != 13)
        $fatal(1,"overlap presentations=%0d expected=13",overlap_presentations);
    if (!accelerated_secondary_seen || !accelerated_backpressure_seen)
        $fatal(1,"accelerated queue was not exercised secondary=%0d hold=%0d",
               accelerated_secondary_seen,accelerated_backpressure_seen);
    if (accelerated_decoded_count != 16'd21)
        $fatal(1,"accelerated decoded=%0d expected=21",
               accelerated_decoded_count);
    if (accelerated_presentations != 20)
        $fatal(1,"accelerated presentations=%0d expected=20",
               accelerated_presentations);
    if (!terminal_secondary_seen || !terminal_sequence_seen)
        $fatal(1,"terminal queue was not exercised secondary=%0d end=%0d",
               terminal_secondary_seen,terminal_sequence_seen);
    if (terminal_decoded_count != 16'd8 || terminal_presentations != 8)
        $fatal(1,"terminal decoded/presented=%0d/%0d expected=8/8",
               terminal_decoded_count,terminal_presentations);
    if (base_last_generation != base_presentations ||
        overlap_last_generation != overlap_presentations ||
        accelerated_last_generation != accelerated_presentations ||
        terminal_last_generation != terminal_presentations)
        $fatal(1,{"generation totals base=%0d/%0d overlap=%0d/%0d ",
                  "accelerated=%0d/%0d terminal=%0d/%0d"},
               base_last_generation,base_presentations,
               overlap_last_generation,overlap_presentations,
               accelerated_last_generation,accelerated_presentations,
               terminal_last_generation,terminal_presentations);
    if (terminal_scheduler.pending_frame_valid ||
        terminal_scheduler.ordinary_secondary_valid ||
        terminal_scheduler.ordinary_terminal_drain_pending || terminal_hold)
        $fatal(1,"terminal ownership did not drain");
    $display({"NATIVE_PRESENTATION_LATENCY_PASS windows=20 fields=40 ",
              "serialized_decoded=10 overlap_decoded=13 ",
              "serialized_presented=10 overlap_presented=13 ",
              "accelerated_decoded=21 accelerated_presented=20 ",
              "accelerated_queue=1 terminal_decoded=8 ",
              "terminal_presented=8 terminal_empty=1 generation_order=1"});
    $finish;
end
initial begin
    #1000000000;
    $fatal(1,"timeout");
end
endmodule
