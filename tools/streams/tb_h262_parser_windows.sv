`timescale 1ns/1ps

module tb_h262_parser_windows;
    localparam integer MAX_STREAM_BYTES = 262144;

    reg clk = 0;
    reg reset = 1;
    reg [7:0] stream_data = 0;
    reg stream_valid = 0;
    reg [7:0] stream_mem [0:MAX_STREAM_BYTES-1];
    integer stream_len, stream_index, quiet_cycles, minimum_refills;
    integer p_refills = 0, b_refills = 0;
    integer p_picture_motion_events = 0, p_picture_completions = 0;
    reg [1023:0] hex_path;
    reg prior_p_error = 0, prior_b_error = 0;
    reg [5:0] prior_p_state = 0, prior_b_state = 0;

    wire p_candidate, p_seen, p_complete, p_hold, p_error;
    wire [5:0] p_width, p_height;
    wire [10:0] p_count;
    wire p_motion_valid;
    wire [10:0] p_motion_index;
    wire signed [7:0] p_motion_x, p_motion_y;
    wire [10:0] p_residual_read_mb;
    wire [2:0] p_residual_read_block;
    wire p_residual_read_intra;
    wire [4:0] p_residual_read_qscale;
    wire [11:0] p_residual_count;
    wire p_residual_present;
    wire [5:0] p_coeff_read_index;
    wire signed [12:0] p_coeff_read_value;
    wire p_coeff_read_last;
    wire [15:0] p_coeff_count;
    wire p_q_scale_type, p_alternate_scan;

    wire b_candidate, b_seen, b_complete, b_hold, b_replay;
    wire b_sideband_valid, b_first_valid, b_error;
    wire [5:0] b_sideband_index;
    wire signed [15:0] b_sideband_value, b_first_value;

    always #5 clk = ~clk;

    mpeg2_h262_p_wide_motion_syntax_probe p_parser(
        .clk(clk), .reset(reset), .stream_data(stream_data), .stream_valid(stream_valid),
        .intra_dc_precision(2'd0),
        .wide_candidate(p_candidate), .wide_seen(p_seen), .wide_complete_now(p_complete),
        .motion_event_valid(p_motion_valid), .motion_event_index(p_motion_index),
        .motion_event_x(p_motion_x), .motion_event_y(p_motion_y),
        .picture_mb_width(p_width), .picture_mb_height(p_height), .picture_mb_count(p_count),
        .residual_block_read_address(11'd0),
        .residual_block_read_mb(p_residual_read_mb),
        .residual_block_read_index(p_residual_read_block),
        .residual_block_read_intra(p_residual_read_intra),
        .residual_block_read_qscale(p_residual_read_qscale),
        .residual_block_count(p_residual_count), .residual_present(p_residual_present),
        .residual_coeff_read_address(15'd0),
        .residual_coeff_read_index(p_coeff_read_index),
        .residual_coeff_read_value(p_coeff_read_value),
        .residual_coeff_read_last(p_coeff_read_last),
        .residual_coeff_count(p_coeff_count), .q_scale_type(p_q_scale_type),
        .alternate_scan(p_alternate_scan), .parse_hold(p_hold), .probe_error(p_error)
    );

    mpeg2_h262_b_core_probe b_parser(
        .clk(clk), .reset(reset), .stream_data(stream_data), .stream_valid(stream_valid),
        .b_candidate(b_candidate), .b_seen(b_seen), .b_complete_now(b_complete),
        .parse_hold(b_hold), .replay_active(b_replay), .sideband_valid(b_sideband_valid),
        .sideband_index(b_sideband_index), .sideband_value(b_sideband_value),
        .first_sample_valid(b_first_valid), .first_sample_value(b_first_value),
        .probe_error(b_error)
    );

    initial begin
        if(!$value$plusargs("HEX=%s", hex_path)) $fatal(1, "missing +HEX");
        if(!$value$plusargs("LEN=%d", stream_len)) $fatal(1, "missing +LEN");
        if(!$value$plusargs("MIN_REFILLS=%d", minimum_refills)) minimum_refills = 0;
        if(stream_len <= 0 || stream_len > MAX_STREAM_BYTES)
            $fatal(1, "invalid stream length %0d", stream_len);
        $readmemh(hex_path, stream_mem, 0, stream_len-1);
        stream_index = 0;
        quiet_cycles = 0;
        repeat(5) @(posedge clk);
        reset <= 0;
    end

    // Drive transfers on the falling edge so stream_valid is already stable
    // before the DUT samples it and no byte leaks through a newly raised hold.
    always @(negedge clk) begin
        if(reset) begin
            stream_data <= 0;
            stream_valid <= 0;
        end else if(stream_index < stream_len) begin
            if(!p_hold && !b_hold) begin
                stream_data <= stream_mem[stream_index];
                stream_valid <= 1;
                stream_index <= stream_index + 1;
            end else begin
                stream_valid <= 0;
            end
        end else begin
            stream_valid <= 0;
            if(!p_hold && !b_hold && !b_replay)
                quiet_cycles <= quiet_cycles + 1;
            else
                quiet_cycles <= 0;
            if(quiet_cycles == 100) begin
                $display("RESULT p_seen=%0d p_error=%0d b_seen=%0d b_error=%0d p_count=%0d p_pictures=%0d p_refills=%0d b_refills=%0d",
                         p_seen, p_error, b_seen, b_error, p_count,
                         p_picture_completions, p_refills, b_refills);
                if(!p_seen || p_error || !b_seen || b_error || p_count != 1350 ||
                   p_picture_completions == 0 || p_picture_motion_events != 0 ||
                   p_refills < minimum_refills || b_refills < minimum_refills)
                    $fatal(1, "parser-window regression failed");
                $finish;
            end
        end
    end

    always @(posedge clk) begin
        if(p_motion_valid)
            p_picture_motion_events <= p_picture_motion_events + 1;
        if(p_complete) begin
            if((p_picture_motion_events + (p_motion_valid ? 1 : 0)) != 1350)
                $fatal(1, "P picture emitted %0d motion events, expected 1350",
                       p_picture_motion_events + (p_motion_valid ? 1 : 0));
            p_picture_motion_events <= 0;
            p_picture_completions <= p_picture_completions + 1;
        end
        if(p_parser.parse_active && p_parser.parser_at_end &&
           !p_parser.chunk_boundary_known)
            p_refills <= p_refills + 1;
        if(b_parser.parse_active && b_parser.parser_at_end &&
           !b_parser.chunk_boundary_known)
            b_refills <= b_refills + 1;
        if(p_error && !prior_p_error)
            $display("P_ERROR offset=%0d state=%0d byte=%0d/%0d bit=%0d started=%0d boundary=%0d",
                     stream_index, p_parser.parser_state, p_parser.parse_byte_index,
                     p_parser.parse_byte_limit, p_parser.parse_bit_index,
                     p_parser.slice_parser_started, p_parser.chunk_boundary_known);
        if(b_error && !prior_b_error)
            $display("B_ERROR offset=%0d state=%0d byte=%0d/%0d bit=%0d started=%0d boundary=%0d",
                     stream_index, b_parser.state, b_parser.parse_byte_index,
                     b_parser.parse_byte_limit, b_parser.parse_bit_index,
                     b_parser.slice_parser_started, b_parser.chunk_boundary_known);
        prior_p_error <= p_error;
        prior_b_error <= b_error;
        if(p_parser.parser_state == 22 && prior_p_state != 22)
            $display("P_STATE_ERROR offset=%0d prior=%0d byte=%0d/%0d bit=%0d col=%0d row=%0d",
                     stream_index, prior_p_state, p_parser.parse_byte_index,
                     p_parser.parse_byte_limit, p_parser.parse_bit_index,
                     p_parser.current_col, p_parser.slice_row_number);
        if(b_parser.state == 23 && prior_b_state != 23)
            $display("B_STATE_ERROR offset=%0d prior=%0d byte=%0d/%0d bit=%0d col=%0d row=%0d",
                     stream_index, prior_b_state, b_parser.parse_byte_index,
                     b_parser.parse_byte_limit, b_parser.parse_bit_index,
                     b_parser.current_col, b_parser.slice_row_number);
        prior_p_state <= p_parser.parser_state;
        prior_b_state <= b_parser.state;
    end

    initial begin
        repeat(2000000) @(posedge clk);
        $fatal(1, "parser-window regression timed out");
    end
endmodule
