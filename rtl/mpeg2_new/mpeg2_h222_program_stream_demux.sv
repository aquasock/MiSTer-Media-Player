//============================================================================
// MiSTer Media Player - bounded H.222.0 MPEG-2 Program Stream video demux
//
// Entry 356: auto-detect a Program Stream by its initial pack_start_code,
// otherwise replay the four probe bytes and remain an exact raw elementary-
// stream pass-through.  Program Stream mode accepts MPEG-2 pack headers,
// length-delimited system/PES packets and one selected video stream_id.  It
// reconstructs validated PTS fields and associates each one only with the
// first picture_start_code whose complete prefix begins in that PES payload.
// deliberately does not implement MPEG-1 systems syntax, PTS scheduling,
// Program Stream Map interpretation, audio decode or error resynchronization.
//============================================================================
module mpeg2_h222_program_stream_demux
(
    input  wire       clk,
    input  wire       reset,
    input  wire [7:0] input_data,
    input  wire       input_valid,
    output reg        input_ready,
    input  wire       input_end,
    output reg  [7:0] video_data,
    output reg        video_valid,
    input  wire       video_ready,
    output reg        video_pts_valid,
    output reg [32:0] video_pts_90k,
    output reg        program_stream_detected,
    output reg        program_end_seen,
    output reg        systems_error,
    output reg  [3:0] systems_error_code
);

localparam [4:0] ST_DETECT       = 5'd0;
localparam [4:0] ST_RAW_REPLAY   = 5'd1;
localparam [4:0] ST_RAW_PASS     = 5'd2;
localparam [4:0] ST_PACK_FIXED   = 5'd3;
localparam [4:0] ST_PACK_STUFF   = 5'd4;
localparam [4:0] ST_BOUNDARY     = 5'd5;
localparam [4:0] ST_SYSTEM_LEN_H = 5'd6;
localparam [4:0] ST_SYSTEM_LEN_L = 5'd7;
localparam [4:0] ST_SYSTEM_SKIP  = 5'd8;
localparam [4:0] ST_PES_LEN_H    = 5'd9;
localparam [4:0] ST_PES_LEN_L    = 5'd10;
localparam [4:0] ST_PES_SKIP     = 5'd11;
localparam [4:0] ST_PES_FLAGS1   = 5'd12;
localparam [4:0] ST_PES_FLAGS2   = 5'd13;
localparam [4:0] ST_PES_HDR_LEN  = 5'd14;
localparam [4:0] ST_PES_HDR_SKIP = 5'd15;
localparam [4:0] ST_PES_PAYLOAD  = 5'd16;
localparam [4:0] ST_PS_DONE      = 5'd17;
localparam [4:0] ST_ERROR        = 5'd18;

localparam [3:0] ERR_BOUNDARY_PREFIX = 4'd1;
localparam [3:0] ERR_PACK_SYNTAX     = 4'd2;
localparam [3:0] ERR_PACK_STUFFING   = 4'd3;
localparam [3:0] ERR_PACKET_ID       = 4'd4;
localparam [3:0] ERR_ZERO_PES_LENGTH = 4'd5;
localparam [3:0] ERR_PES_FIXED_BITS  = 4'd6;
localparam [3:0] ERR_PTS_DTS_FLAGS   = 4'd7;
localparam [3:0] ERR_PES_LENGTH      = 4'd8;
localparam [3:0] ERR_TIMESTAMP       = 4'd9;
localparam [3:0] ERR_TRUNCATED       = 4'd10;

reg [4:0] state;
reg [31:0] detect_shift;
reg [2:0] detect_count;
reg [1:0] replay_index;
reg [1:0] boundary_index;
reg [3:0] pack_index;
reg [2:0] stuffing_remaining;
reg [15:0] program_mux_rate_high;
reg [7:0] length_high_byte;
reg [15:0] skip_remaining;
reg [15:0] pes_remaining;
reg [7:0] packet_stream_id;
reg       selected_video_valid;
reg [7:0] selected_video_id;
reg [1:0] pts_dts_flags;
reg [7:0] header_remaining;
reg [7:0] header_index;
reg [32:0] pts_build;
reg [32:0] pes_pts_90k;
reg        pes_pts_pending;
reg [23:0] payload_prefix;

wire input_fire = input_valid && input_ready;

function automatic is_length_delimited_packet;
    input [7:0] stream_id;
    begin
        is_length_delimited_packet =
            (stream_id == 8'hbc) || (stream_id == 8'hbd) ||
            (stream_id == 8'hbe) || (stream_id == 8'hbf) ||
            ((stream_id >= 8'hc0) && (stream_id <= 8'hef)) ||
            (stream_id == 8'hf0) || (stream_id == 8'hf1) ||
            (stream_id == 8'hf2) || (stream_id == 8'hf3) ||
            (stream_id == 8'hf8) || (stream_id == 8'hff);
    end
endfunction

function automatic timestamp_byte_valid;
    input [1:0] flags;
    input [7:0] index;
    input [3:0] prefix;
    input       marker;
    begin
        timestamp_byte_valid = 1'b1;
        if (flags == 2'b10) begin
            if (index == 0)
                timestamp_byte_valid =
                    (prefix == 4'b0010) && marker;
            else if ((index == 2) || (index == 4))
                timestamp_byte_valid = marker;
        end
        else if (flags == 2'b11) begin
            if (index == 0)
                timestamp_byte_valid =
                    (prefix == 4'b0011) && marker;
            else if ((index == 2) || (index == 4) ||
                     (index == 7) || (index == 9))
                timestamp_byte_valid = marker;
            else if (index == 5)
                timestamp_byte_valid =
                    (prefix == 4'b0001) && marker;
        end
    end
endfunction

always @* begin
    input_ready = 1'b0;
    video_data  = input_data;
    video_valid = 1'b0;
    case (state)
        ST_DETECT,
        ST_PACK_FIXED,
        ST_PACK_STUFF,
        ST_BOUNDARY,
        ST_SYSTEM_LEN_H,
        ST_SYSTEM_LEN_L,
        ST_SYSTEM_SKIP,
        ST_PES_LEN_H,
        ST_PES_LEN_L,
        ST_PES_SKIP,
        ST_PES_FLAGS1,
        ST_PES_FLAGS2,
        ST_PES_HDR_LEN,
        ST_PES_HDR_SKIP: input_ready = 1'b1;

        ST_RAW_REPLAY: begin
            video_valid = 1'b1;
            case (replay_index)
                2'd0: video_data = detect_shift[31:24];
                2'd1: video_data = detect_shift[23:16];
                2'd2: video_data = detect_shift[15:8];
                default: video_data = detect_shift[7:0];
            endcase
        end

        ST_RAW_PASS,
        ST_PES_PAYLOAD: begin
            input_ready = video_ready;
            video_valid = input_valid;
        end

        default: begin
            input_ready = 1'b0;
            video_valid = 1'b0;
        end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        state                   <= ST_DETECT;
        detect_shift            <= 32'd0;
        detect_count            <= 3'd0;
        replay_index            <= 2'd0;
        boundary_index          <= 2'd0;
        pack_index              <= 4'd0;
        stuffing_remaining      <= 3'd0;
        program_mux_rate_high   <= 16'd0;
        length_high_byte        <= 8'd0;
        skip_remaining          <= 16'd0;
        pes_remaining           <= 16'd0;
        packet_stream_id        <= 8'd0;
        selected_video_valid    <= 1'b0;
        selected_video_id       <= 8'd0;
        pts_dts_flags           <= 2'd0;
        header_remaining        <= 8'd0;
        header_index            <= 8'd0;
        pts_build               <= 33'd0;
        pes_pts_90k             <= 33'd0;
        pes_pts_pending         <= 1'b0;
        payload_prefix          <= 24'hffffff;
        video_pts_valid         <= 1'b0;
        video_pts_90k           <= 33'd0;
        program_stream_detected <= 1'b0;
        program_end_seen        <= 1'b0;
        systems_error           <= 1'b0;
        systems_error_code      <= 4'd0;
    end
    else begin
        video_pts_valid <= 1'b0;
        case (state)
            ST_DETECT: if (input_fire) begin
                detect_shift <= {detect_shift[23:0], input_data};
                if (detect_count == 3) begin
                    if ({detect_shift[23:0], input_data} == 32'h000001ba) begin
                        program_stream_detected <= 1'b1;
                        pack_index <= 4'd0;
                        state <= ST_PACK_FIXED;
                    end
                    else begin
                        replay_index <= 2'd0;
                        state <= ST_RAW_REPLAY;
                    end
                end
                else
                    detect_count <= detect_count + 3'd1;
            end

            ST_RAW_REPLAY: if (video_ready) begin
                if (replay_index == 3)
                    state <= ST_RAW_PASS;
                else
                    replay_index <= replay_index + 2'd1;
            end

            ST_RAW_PASS: begin
                // Raw elementary streams retain their historical byte path.
            end

            ST_PACK_FIXED: if (input_fire) begin
                case (pack_index)
                    4'd0: if ((input_data[7:6] != 2'b01) || !input_data[2]) begin
                        systems_error <= 1'b1;
                        systems_error_code <= ERR_PACK_SYNTAX;
                        state <= ST_ERROR;
                    end
                    4'd2: if (!input_data[2]) begin
                        systems_error <= 1'b1;
                        systems_error_code <= ERR_PACK_SYNTAX;
                        state <= ST_ERROR;
                    end
                    4'd4: if (!input_data[2]) begin
                        systems_error <= 1'b1;
                        systems_error_code <= ERR_PACK_SYNTAX;
                        state <= ST_ERROR;
                    end
                    4'd5: if (!input_data[0]) begin
                        systems_error <= 1'b1;
                        systems_error_code <= ERR_PACK_SYNTAX;
                        state <= ST_ERROR;
                    end
                    4'd6: program_mux_rate_high[15:8] <= input_data;
                    4'd7: program_mux_rate_high[7:0] <= input_data;
                    4'd8: begin
                        if ((input_data[1:0] != 2'b11) ||
                            ({program_mux_rate_high,input_data[7:2]} == 22'd0)) begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_PACK_SYNTAX;
                            state <= ST_ERROR;
                        end
                    end
                    4'd9: begin
                        if (input_data[7:3] != 5'b11111) begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_PACK_SYNTAX;
                            state <= ST_ERROR;
                        end
                        else if (input_data[2:0] == 0) begin
                            boundary_index <= 2'd0;
                            state <= ST_BOUNDARY;
                        end
                        else begin
                            stuffing_remaining <= input_data[2:0];
                            state <= ST_PACK_STUFF;
                        end
                    end
                    default: begin end
                endcase
                if ((state == ST_PACK_FIXED) && (pack_index != 9))
                    pack_index <= pack_index + 4'd1;
            end

            ST_PACK_STUFF: if (input_fire) begin
                if (input_data != 8'hff) begin
                    systems_error <= 1'b1;
                    systems_error_code <= ERR_PACK_STUFFING;
                    state <= ST_ERROR;
                end
                else if (stuffing_remaining == 1) begin
                    stuffing_remaining <= 3'd0;
                    boundary_index <= 2'd0;
                    state <= ST_BOUNDARY;
                end
                else
                    stuffing_remaining <= stuffing_remaining - 3'd1;
            end

            ST_BOUNDARY: if (input_fire) begin
                case (boundary_index)
                    2'd0: begin
                        if (input_data != 8'h00) begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_BOUNDARY_PREFIX;
                            state <= ST_ERROR;
                        end
                        else boundary_index <= 2'd1;
                    end
                    2'd1: begin
                        if (input_data != 8'h00) begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_BOUNDARY_PREFIX;
                            state <= ST_ERROR;
                        end
                        else boundary_index <= 2'd2;
                    end
                    2'd2: begin
                        if (input_data != 8'h01) begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_BOUNDARY_PREFIX;
                            state <= ST_ERROR;
                        end
                        else boundary_index <= 2'd3;
                    end
                    default: begin
                        boundary_index <= 2'd0;
                        if (input_data == 8'hba) begin
                            pack_index <= 4'd0;
                            state <= ST_PACK_FIXED;
                        end
                        else if (input_data == 8'hbb)
                            state <= ST_SYSTEM_LEN_H;
                        else if (input_data == 8'hb9) begin
                            program_end_seen <= 1'b1;
                            state <= ST_PS_DONE;
                        end
                        else if (is_length_delimited_packet(input_data)) begin
                            packet_stream_id <= input_data;
                            state <= ST_PES_LEN_H;
                        end
                        else begin
                            systems_error <= 1'b1;
                            systems_error_code <= ERR_PACKET_ID;
                            state <= ST_ERROR;
                        end
                    end
                endcase
            end

            ST_SYSTEM_LEN_H: if (input_fire) begin
                length_high_byte <= input_data;
                state <= ST_SYSTEM_LEN_L;
            end

            ST_SYSTEM_LEN_L: if (input_fire) begin
                if ({length_high_byte,input_data} == 0) begin
                    boundary_index <= 2'd0;
                    state <= ST_BOUNDARY;
                end
                else begin
                    skip_remaining <= {length_high_byte,input_data};
                    state <= ST_SYSTEM_SKIP;
                end
            end

            ST_SYSTEM_SKIP: if (input_fire) begin
                if (skip_remaining == 1) begin
                    skip_remaining <= 16'd0;
                    boundary_index <= 2'd0;
                    state <= ST_BOUNDARY;
                end
                else
                    skip_remaining <= skip_remaining - 16'd1;
            end

            ST_PES_LEN_H: if (input_fire) begin
                length_high_byte <= input_data;
                state <= ST_PES_LEN_L;
            end

            ST_PES_LEN_L: if (input_fire) begin
                pes_remaining <= {length_high_byte,input_data};
                if ({length_high_byte,input_data} == 0) begin
                    systems_error <= 1'b1;
                    systems_error_code <= ERR_ZERO_PES_LENGTH;
                    state <= ST_ERROR;
                end
                else if ((packet_stream_id >= 8'he0) &&
                         (packet_stream_id <= 8'hef) &&
                         (!selected_video_valid ||
                          (packet_stream_id == selected_video_id))) begin
                    if (!selected_video_valid) begin
                        selected_video_valid <= 1'b1;
                        selected_video_id <= packet_stream_id;
                    end
                    pts_build <= 33'd0;
                    pes_pts_pending <= 1'b0;
                    state <= ST_PES_FLAGS1;
                end
                else begin
                    skip_remaining <= {length_high_byte,input_data};
                    state <= ST_PES_SKIP;
                end
            end

            ST_PES_SKIP: if (input_fire) begin
                if (skip_remaining == 1) begin
                    skip_remaining <= 16'd0;
                    boundary_index <= 2'd0;
                    state <= ST_BOUNDARY;
                end
                else
                    skip_remaining <= skip_remaining - 16'd1;
            end

            ST_PES_FLAGS1: if (input_fire) begin
                if ((pes_remaining < 3) || (input_data[7:6] != 2'b10)) begin
                    systems_error <= 1'b1;
                    systems_error_code <=
                        (pes_remaining < 3) ? ERR_PES_LENGTH : ERR_PES_FIXED_BITS;
                    state <= ST_ERROR;
                end
                else begin
                    pes_remaining <= pes_remaining - 16'd1;
                    state <= ST_PES_FLAGS2;
                end
            end

            ST_PES_FLAGS2: if (input_fire) begin
                pts_dts_flags <= input_data[7:6];
                if (input_data[7:6] == 2'b01) begin
                    systems_error <= 1'b1;
                    systems_error_code <= ERR_PTS_DTS_FLAGS;
                    state <= ST_ERROR;
                end
                else begin
                    pes_remaining <= pes_remaining - 16'd1;
                    state <= ST_PES_HDR_LEN;
                end
            end

            ST_PES_HDR_LEN: if (input_fire) begin
                if (({8'd0,input_data} > (pes_remaining - 16'd1)) ||
                    ((pts_dts_flags == 2'b10) && (input_data < 5)) ||
                    ((pts_dts_flags == 2'b11) && (input_data < 10))) begin
                    systems_error <= 1'b1;
                    systems_error_code <= ERR_PES_LENGTH;
                    state <= ST_ERROR;
                end
                else begin
                    pes_remaining <= pes_remaining - 16'd1;
                    header_remaining <= input_data;
                    header_index <= 8'd0;
                    if (input_data != 0)
                        state <= ST_PES_HDR_SKIP;
                    else if (pes_remaining == 1) begin
                        boundary_index <= 2'd0;
                        state <= ST_BOUNDARY;
                    end
                    else begin
                        payload_prefix <= 24'hffffff;
                        state <= ST_PES_PAYLOAD;
                    end
                end
            end

            ST_PES_HDR_SKIP: if (input_fire) begin
                if (!timestamp_byte_valid(pts_dts_flags,header_index,
                                          input_data[7:4],input_data[0])) begin
                    systems_error <= 1'b1;
                    systems_error_code <= ERR_TIMESTAMP;
                    state <= ST_ERROR;
                end
                else begin
                    if ((pts_dts_flags != 2'b00) && (header_index <= 4)) begin
                        case (header_index)
                            0: pts_build[32:30] <= input_data[3:1];
                            1: pts_build[29:22] <= input_data;
                            2: pts_build[21:15] <= input_data[7:1];
                            3: pts_build[14:7]  <= input_data;
                            4: begin
                                pts_build[6:0] <= input_data[7:1];
                                pes_pts_90k <= {pts_build[32:7],input_data[7:1]};
                                pes_pts_pending <= 1'b1;
                            end
                            default: begin end
                        endcase
                    end
                    header_index <= header_index + 8'd1;
                    header_remaining <= header_remaining - 8'd1;
                    pes_remaining <= pes_remaining - 16'd1;
                    if (header_remaining == 1) begin
                        if (pes_remaining == 1) begin
                            boundary_index <= 2'd0;
                            state <= ST_BOUNDARY;
                        end
                        else begin
                            payload_prefix <= 24'hffffff;
                            state <= ST_PES_PAYLOAD;
                        end
                    end
                end
            end

            ST_PES_PAYLOAD: if (input_fire) begin
                payload_prefix <= {payload_prefix[15:0],input_data};
                if (pes_pts_pending &&
                    ({payload_prefix,input_data} == 32'h00000100)) begin
                    video_pts_valid <= 1'b1;
                    video_pts_90k <= pes_pts_90k;
                    pes_pts_pending <= 1'b0;
                end
                pes_remaining <= pes_remaining - 16'd1;
                if (pes_remaining == 1) begin
                    boundary_index <= 2'd0;
                    state <= ST_BOUNDARY;
                end
            end

            default: begin end
        endcase

        if (input_end && program_stream_detected && !program_end_seen &&
            !systems_error) begin
            systems_error <= 1'b1;
            systems_error_code <= ERR_TRUNCATED;
            state <= ST_ERROR;
        end
    end
end

endmodule
