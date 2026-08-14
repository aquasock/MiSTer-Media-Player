//============================================================================
// MiSTer Media Player - P diagnostic controller
//
// kate - Phase 1U-j keeps the accepted diagnostic clients and adds a bounded
// per-slice parse hold for the generalized f_code=(2,2) raster observer.  The
// observer may now pause compressed input after a slice start-code boundary
// while its sequential Table B.1/address parser consumes the preceding row.
// Final picture-boundary hold ownership still transfers to the existing DDR
// persistence watchdog before input resumes.
//============================================================================

module mpeg2_h262_p_diagnostic_controller
(
    input  wire        clk,
    input  wire        reset,
    input  wire [7:0]  stream_data,
    input  wire        stream_valid,
    input  wire        p_picture_expected,
    input  wire        p_persistence_complete,

    output wire        stream_hold,
    output wire        p_macroblock_type_seen,
    output wire        p_forward_vector_valid,
    output wire signed [12:0] p_forward_vector_x,
    output wire signed [12:0] p_forward_vector_y,
    output wire        p_residual_required,
    output wire        p_residual_success,
    output wire        p_first_residual_sample_valid,
    output wire signed [15:0] p_first_residual_sample_value,
    output wire        p_residual_sample_valid,
    output wire [5:0]  p_residual_sample_index,
    output wire signed [15:0] p_residual_sample_value,
    output wire        probe_error
);

wire syntax_error_raw;
wire mb_seen_raw;
wire vector_valid_raw;
wire signed [12:0] vector_x_raw;
wire signed [12:0] vector_y_raw;

wire two_mb_seen;
wire two_mb_error;

wire four_mb_candidate;
wire four_mb_seen;
wire four_mb_complete_now;
wire four_mb_parse_hold;
wire four_mb_error;

wire residual_decision;
wire residual_required_raw;
wire residual_success_raw;
wire first_valid_raw;
wire signed [15:0] first_value_raw;
wire residual_valid_raw;
wire [5:0] residual_index_raw;
wire signed [15:0] residual_value_raw;
wire residual_error;
wire hold_seen;
wire hold_error;
wire old_stream_hold;

// Once either semantic multi-MB observer completes, publish the exact zero
// vector it proved. While the generalized raster candidate is being parsed,
// suppress the older first-macroblock vector so the raster engine cannot start
// before all slice rows have been semantically verified.
assign p_forward_vector_valid =
    four_mb_seen ? 1'b1 :
    two_mb_seen  ? 1'b1 :
    four_mb_candidate ? 1'b0 : vector_valid_raw;
assign p_forward_vector_x =
    (four_mb_seen || two_mb_seen) ? 13'sd0 : vector_x_raw;
assign p_forward_vector_y =
    (four_mb_seen || two_mb_seen) ? 13'sd0 : vector_y_raw;

assign p_residual_required           = residual_required_raw;
assign p_residual_success            = residual_success_raw;
assign p_first_residual_sample_valid = first_valid_raw;
assign p_first_residual_sample_value = first_value_raw;
assign p_residual_sample_valid       = residual_valid_raw;
assign p_residual_sample_index       = residual_index_raw;
assign p_residual_sample_value       = residual_value_raw;

wire mb_seen_combined =
    four_mb_candidate ? four_mb_seen :
    (mb_seen_raw || two_mb_seen || four_mb_seen);
wire mb_seen_decoded =
    mb_seen_combined &&
    (!p_picture_expected ||
     (residual_decision &&
      (!residual_required_raw || residual_success_raw)));

wire two_mb_wait  = two_mb_seen  && !p_persistence_complete;
wire four_mb_wait = four_mb_seen && !p_persistence_complete;
wire mb_seen_for_hold = mb_seen_decoded && !two_mb_wait && !four_mb_wait;

reg        four_hold_active;
reg        four_hold_seen;
reg        four_hold_error;
reg [19:0] four_hold_timeout;

always @(posedge clk) begin
    if (reset) begin
        four_hold_active  <= 1'b0;
        four_hold_seen    <= 1'b0;
        four_hold_error   <= 1'b0;
        four_hold_timeout <= 20'd0;
    end
    else begin
        // four_mb_complete_now now arrives after the last buffered slice row has
        // been parsed while four_mb_parse_hold is already active.  This handoff
        // therefore has no cycle in which compressed input can escape between
        // semantic completion and DDR copy/readback persistence.
        if (four_mb_complete_now && !four_hold_seen) begin
            four_hold_active  <= 1'b1;
            four_hold_seen    <= 1'b1;
            four_hold_timeout <= 20'hFFFFF;
        end

        if (four_hold_active) begin
            if (p_persistence_complete) begin
                four_hold_active  <= 1'b0;
                four_hold_timeout <= 20'd0;
            end
            else if (four_hold_timeout == 20'd1) begin
                four_hold_active  <= 1'b0;
                four_hold_timeout <= 20'd0;
                four_hold_error   <= 1'b1;
            end
            else if (four_hold_timeout != 20'd0) begin
                four_hold_timeout <= four_hold_timeout - 20'd1;
            end
        end
    end
end

wire hold_seen_combined = four_mb_seen ? four_hold_seen : hold_seen;

assign p_macroblock_type_seen =
    mb_seen_decoded &&
    (!p_picture_expected ||
     (hold_seen_combined && !two_mb_wait && !four_mb_wait));

assign stream_hold =
    four_mb_parse_hold ||
    four_hold_active ||
    (!four_mb_candidate && old_stream_hold);

// The older first-macroblock passive syntax probe intentionally expects a
// different bounded capture. Suppress its raw error only after an independent
// semantic multi-MB observer proves the complete controlled syntax.
wire syntax_error = syntax_error_raw && !two_mb_seen && !four_mb_seen;
wire progress_error = p_picture_expected && !p_macroblock_type_seen;

assign probe_error =
    syntax_error |
    two_mb_error |
    four_mb_error |
    residual_error |
    hold_error |
    four_hold_error |
    progress_error;

mpeg2_h262_p_syntax_probe syntax_probe
(
    .clk                    (clk),
    .reset                  (reset),
    .stream_data            (stream_data),
    .stream_valid           (stream_valid),
    .p_picture_expected     (p_picture_expected),
    .p_macroblock_type_seen (mb_seen_raw),
    .p_forward_vector_valid (vector_valid_raw),
    .p_forward_vector_x     (vector_x_raw),
    .p_forward_vector_y     (vector_y_raw),
    .probe_error            (syntax_error_raw)
);

mpeg2_h262_p_two_mb_syntax_probe two_mb_probe
(
    .clk          (clk),
    .reset        (reset),
    .stream_data  (stream_data),
    .stream_valid (stream_valid),
    .two_mb_seen  (two_mb_seen),
    .probe_error  (two_mb_error)
);

mpeg2_h262_p_four_mb_two_row_syntax_probe four_mb_probe
(
    .clk                  (clk),
    .reset                (reset),
    .stream_data          (stream_data),
    .stream_valid         (stream_valid),
    .four_mb_candidate    (four_mb_candidate),
    .four_mb_seen         (four_mb_seen),
    .four_mb_complete_now (four_mb_complete_now),
    .parse_hold           (four_mb_parse_hold),
    .probe_error          (four_mb_error)
);

mpeg2_h262_p_residual_probe residual_probe
(
    .clk                  (clk),
    .reset                (reset),
    .stream_data          (stream_data),
    .stream_valid         (stream_valid),
    .p_picture_expected   (p_picture_expected),
    .decision_complete    (residual_decision),
    .residual_required    (residual_required_raw),
    .residual_success     (residual_success_raw),
    .first_sample_valid   (first_valid_raw),
    .first_sample_value   (first_value_raw),
    .residual_sample_valid(residual_valid_raw),
    .residual_sample_index(residual_index_raw),
    .residual_sample_value(residual_value_raw),
    .probe_error          (residual_error)
);

mpeg2_h262_p_stream_hold hold_probe
(
    .clk                    (clk),
    .reset                  (reset),
    .stream_data            (stream_data),
    .stream_valid           (stream_valid),
    .p_picture_active       (p_picture_expected && !four_mb_candidate),
    .p_macroblock_type_seen (mb_seen_for_hold),
    .p_residual_required    (residual_required_raw),
    .p_persistence_complete (p_persistence_complete),
    .stream_hold            (old_stream_hold),
    .hold_seen              (hold_seen),
    .hold_error             (hold_error)
);

endmodule
