//============================================================================
// MiSTer Media Player - MPEG-2 Program Stream / PES demultiplexer
//
// Entry 979: first stage of moving Program Stream demux, audio decode and
// overlay rendering into the FPGA core so a plain .mpg file can be loaded
// the same way any ROM-loading MiSTer core loads a ROM - stock Main streams
// the raw file bytes in, and everything downstream (this module included)
// lives in RTL. Scope matches core-reference.md's adopted H.222.0 records
// H222-001 through H222-006: pack header/stuffing, PES framing via the
// 16-bit PES_packet_length, video (stream_id 0xE0-0xEF) / audio (stream_id
// 0xC0-0xDF) stream_id routing, and both PES optional-header forms - the
// MPEG-2 form (marker bits '10', an explicit header_data_length) and the
// legacy MPEG-1 form (optional 0xFF stuffing bytes, an optional one 2-byte
// STD_buffer_scale/size marker, then either a bare PTS marker '0010', a
// PTS+DTS marker '0011', or the no-timestamp marker 0x0F - no explicit
// length field of its own). Entry 979 assumed no real file would still use
// the legacy form; entry 983's hardware test proved that wrong - the
// project's own primary test file uses it - so both are handled here, the
// same way host/arm/media_player_helper.c's parse_pes_header() already did
// in software.
//
// Unlike the ARM helper's replacement scheme, there is no need to smuggle
// audio or overlay data back through the video elementary-stream pipe as
// in-band metadata (mpeg2_h262_inband_metadata's whole reason to exist):
// this module outputs video and audio elementary bytes as two independent
// ready/valid streams, each with its own directly-attached PTS, so nothing
// downstream needs to parse an invented escape protocol back out again.
//============================================================================
module mpeg2_h262_program_stream_demux #(parameter ENABLE_FILE_POSITION=0)
(
    input  wire        clk,
    input  wire        reset,

    input  wire [7:0]  in_data,
    input  wire        in_valid,
    output wire        in_ready,

    output reg  [7:0]  video_data,
    output reg         video_valid,
    input  wire        video_ready,
    output reg  [32:0] video_pts,
    output reg         video_pts_valid,

    output reg  [7:0]  audio_data,
    output reg         audio_valid,
    input  wire        audio_ready,
    output reg  [32:0] audio_pts,
    output reg         audio_pts_valid,

    output reg         stream_end,
    output reg         demux_error,
    input wire [40:0] input_file_position,
    output reg [40:0] video_file_position, video_pack_position
);

localparam [4:0]
    S_SYNC            = 5'd0,
    S_CODE            = 5'd1,
    S_PACK_B0         = 5'd2,
    S_PACK_SKIP       = 5'd3,
    S_PACK_STUFF_LEN  = 5'd4,
    S_PACK_STUFF      = 5'd5,
    S_LEN_HI          = 5'd6,
    S_LEN_LO          = 5'd7,
    S_SKIP_PAYLOAD    = 5'd8,
    S_PES_HDR_B0      = 5'd9,
    S_PES_HDR_B1      = 5'd10,
    S_PES_HDR_B2      = 5'd11,
    S_PES_PTS         = 5'd12,
    S_PES_HDR_SKIP    = 5'd13,
    S_PES_PAYLOAD     = 5'd14,
    S_PES_LEGACY_STUFF= 5'd15,
    S_PES_LEGACY_STD2 = 5'd16,
    S_PES_LEGACY_TS_CHECK = 5'd17;

reg [4:0]  state;
reg [1:0]  zero_run;
reg [7:0]  code;
reg [7:0] selected_video, selected_audio;
reg selected_video_valid, selected_audio_valid;
reg        is_video;
reg        is_pack_mpeg2;
reg [15:0] pes_length;    // PES_packet_length: bytes remaining after this field
reg [15:0] skip_count;    // generic "bytes left in this run" counter
reg [15:0] payload_len;   // elementary bytes left once the PES header is done
reg [1:0]  pts_dts_flags;
reg [2:0]  pts_byte_index;
reg [39:0] pts_shift;     // 5 bytes captured MSB-first
reg        pts_pending;   // this PES has a PTS to publish with its first payload byte
reg        pts_is_legacy; // this PTS capture came from the legacy header form
reg        legacy_has_dts;
reg [15:0] legacy_prefix_bytes; // legacy stuffing/STD bytes consumed before the timestamp marker

// Each output is an elastic one-byte register. A consumer may withdraw
// ready immediately after an input transfer; retain that byte and its PTS.
assign in_ready = (!video_valid || video_ready) &&
                  (!audio_valid || audio_ready);

wire accept = in_valid && in_ready;
reg [40:0] pack_position;
always @(posedge clk) begin
    if(reset) begin pack_position<=0; video_file_position<=0; video_pack_position<=0; end
    else if(ENABLE_FILE_POSITION && accept) begin
        if(state==S_CODE && in_data==8'hba) pack_position<=input_file_position-41'd3;
        if(state==S_PES_PAYLOAD && is_video) begin
            video_file_position<=input_file_position; video_pack_position<=pack_position;
        end
    end
end

wire [32:0] decoded_pts = {
    pts_shift[35:33],
    pts_shift[31:24],
    pts_shift[23:17],
    pts_shift[15:8],
    pts_shift[7:1]
};

// pes_length (loaded before this state) minus 3 fixed optional-header
// bytes minus header_data_len (in_data, being latched this same cycle):
// computed with an extra guard bit so an internally-inconsistent header
// (declared length too short for its own header_data_len) is caught as
// underflow instead of wrapping to a huge unsigned payload count.
wire [16:0] payload_len_calc = {1'b0, pes_length} - 17'd3 - {9'd0, in_data};
wire        payload_len_valid = !payload_len_calc[16];

// Legacy-form payload length once the timestamp marker byte (this cycle's
// in_data) is identified: total header bytes are legacy_prefix_bytes
// (stuffing/STD consumed so far) plus 5 PTS bytes plus 5 more DTS bytes
// when this is the '0011' marker, all guarded against underflow exactly
// like the MPEG-2 calculation above.
wire [17:0] legacy_ts_payload_calc =
    {2'b0, pes_length} - {2'b0, legacy_prefix_bytes} - 18'd5 -
    (in_data[7:4] == 4'h3 ? 18'd5 : 18'd0);
wire        legacy_ts_payload_valid = !legacy_ts_payload_calc[17];
// Legacy no-timestamp marker (0x0F): header is legacy_prefix_bytes plus
// this one byte.
wire [17:0] legacy_none_payload_calc =
    {2'b0, pes_length} - {2'b0, legacy_prefix_bytes} - 18'd1;
wire        legacy_none_payload_valid = !legacy_none_payload_calc[17];

always @(posedge clk) begin
    if (video_ready) begin video_valid <= 1'b0; video_pts_valid <= 1'b0; end
    if (audio_ready) begin audio_valid <= 1'b0; audio_pts_valid <= 1'b0; end
    stream_end      <= 1'b0;

    if (reset) begin
        video_valid <= 1'b0;
        audio_valid <= 1'b0;
        video_pts_valid <= 1'b0;
        audio_pts_valid <= 1'b0;
        pts_pending <= 1'b0;
        selected_video_valid <= 1'b0;
        selected_audio_valid <= 1'b0;
        state       <= S_SYNC;
        zero_run    <= 2'd0;
        demux_error <= 1'b0;
    end else if (accept) begin
        case (state)
        S_SYNC: begin
            if (zero_run == 2'd2 && in_data == 8'h01) begin
                state    <= S_CODE;
                zero_run <= 2'd0;
            end else if (in_data == 8'h00) begin
                if (zero_run != 2'd2) zero_run <= zero_run + 2'd1;
            end else begin
                zero_run <= 2'd0;
            end
        end

        S_CODE: begin
            code <= in_data;
            if (in_data == 8'hba) begin
                state <= S_PACK_B0;
            end else if (in_data == 8'hb9) begin
                stream_end <= 1'b1;
                state      <= S_SYNC;
                zero_run   <= 2'd0;
            end else if (in_data == 8'hb7 || in_data == 8'hb8 || in_data == 8'h00) begin
                // slice/reserved/picture-adjacent start codes cannot appear
                // at the Program Stream layer between packs; resync rather
                // than misread one as a length-prefixed packet.
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                is_video <= (in_data[7:4] == 4'he);
                state    <= S_LEN_HI;
            end
        end

        // The byte that identified this as a pack (0xba) is `code`; this
        // state reads the next byte, the real first pack_header byte,
        // which carries the MPEG-1-vs-MPEG-2 form marker.
        S_PACK_B0: begin
            if (in_data[7:6] == 2'b01) begin
                // MPEG-2 pack_header: 8 more fixed bytes (SCR/mux_rate/
                // marker/reserved), then a stuffing-length byte.
                is_pack_mpeg2 <= 1'b1;
                skip_count    <= 16'd8;
                state         <= S_PACK_SKIP;
            end else if (in_data[7:4] == 4'h2) begin
                // MPEG-1 pack_header: 7 more fixed bytes, no stuffing field.
                is_pack_mpeg2 <= 1'b0;
                skip_count    <= 16'd7;
                state         <= S_PACK_SKIP;
            end else begin
                demux_error <= 1'b1;
                state       <= S_SYNC;
                zero_run    <= 2'd0;
            end
        end

        S_PACK_SKIP: begin
            if (skip_count == 16'd1) begin
                if (is_pack_mpeg2) begin
                    state <= S_PACK_STUFF_LEN;
                end else begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end
            end else begin
                skip_count <= skip_count - 16'd1;
            end
        end

        S_PACK_STUFF_LEN: begin
            if (in_data[2:0] == 3'd0) begin
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                skip_count <= {13'd0, in_data[2:0]};
                state      <= S_PACK_STUFF;
            end
        end

        S_PACK_STUFF: begin
            if (skip_count == 16'd1) begin
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                skip_count <= skip_count - 16'd1;
            end
        end

        S_LEN_HI: begin
            pes_length[15:8] <= in_data;
            state            <= S_LEN_LO;
        end

        S_LEN_LO: begin
            pes_length[7:0] <= in_data;
            if ((code[7:4] == 4'he && (!selected_video_valid || code == selected_video)) ||
                (code[7:5] == 3'b110 && (!selected_audio_valid || code == selected_audio))) begin
                if (code[7:4] == 4'he) begin
                    selected_video <= code;
                    selected_video_valid <= 1'b1;
                end else begin
                    selected_audio <= code;
                    selected_audio_valid <= 1'b1;
                end
                if ({pes_length[15:8], in_data} == 16'd0) begin
                    demux_error <= 1'b1;
                    // A zero-length video PES is only legal in a Transport
                    // Stream, never here; a zero-length audio PES carries
                    // nothing to decode either way. Resync.
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    // legacy_prefix_bytes must read as 0 the moment
                    // S_PES_HDR_B0 evaluates its own first byte, in case
                    // that very byte is already the timestamp marker with
                    // no stuffing/STD field ahead of it (confirmed the
                    // common case on real files, not just a corner case).
                    pts_pending <= 1'b0;
                    legacy_prefix_bytes <= 16'd0;
                    state <= S_PES_HDR_B0;
                end
            end else if ({pes_length[15:8], in_data} == 16'd0) begin
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                // system_header, program_stream_map, private/padding
                // streams and anything else with a length field: not
                // needed downstream, skip the whole packet body.
                skip_count <= {pes_length[15:8], in_data};
                state      <= S_SKIP_PAYLOAD;
            end
        end

        S_SKIP_PAYLOAD: begin
            if (skip_count == 16'd1) begin
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                skip_count <= skip_count - 16'd1;
            end
        end

        S_PES_HDR_B0: begin
            if (in_data[7:6] == 2'b10) begin
                state <= S_PES_HDR_B1;
            end else if (in_data == 8'hff) begin
                // Legacy form: stuffing byte, at least one more header byte
                // follows.
                legacy_prefix_bytes <= 16'd1;
                state               <= S_PES_LEGACY_STUFF;
            end else if (in_data[7:6] == 2'b01) begin
                // Legacy form: 2-byte STD_buffer_scale/size marker.
                legacy_prefix_bytes <= 16'd1;
                state               <= S_PES_LEGACY_STD2;
            end else if (in_data[7:4] == 4'h2 || in_data[7:4] == 4'h3) begin
                // Legacy form: bare PTS ('0010') or PTS+DTS ('0011') marker,
                // no stuffing or STD field ahead of it.
                if (!legacy_ts_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else begin
                    payload_len    <= legacy_ts_payload_calc[15:0];
                    pts_is_legacy  <= 1'b1;
                    legacy_has_dts <= (in_data[7:4] == 4'h3);
                    pts_pending    <= 1'b1;
                    // This marker byte is already being shifted into
                    // pts_shift below, unlike the MPEG-2 path (which
                    // transitions to S_PES_PTS on the header_data_length
                    // byte, a byte the PTS itself does not include) - so
                    // the count of already-consumed PTS bytes starts at 1,
                    // not 0, or S_PES_PTS's completion check fires one
                    // byte too late and swallows the packet's first real
                    // payload byte into the tail of pts_shift instead.
                    pts_byte_index <= 3'd1;
                    pts_shift      <= {pts_shift[31:0], in_data};
                    state          <= S_PES_PTS;
                end
            end else if (in_data == 8'h0f) begin
                // Legacy form: no timestamp, this one byte is the whole
                // header.
                if (!legacy_none_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else if (legacy_none_payload_calc[15:0] == 16'd0) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= legacy_none_payload_calc[15:0];
                    state      <= S_PES_PAYLOAD;
                end
            end else begin
                // Genuinely malformed: skip the remaining declared length
                // rather than mis-parse it.
                demux_error <= 1'b1;
                if (pes_length <= 16'd1) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= pes_length - 16'd1;
                    state      <= S_SKIP_PAYLOAD;
                end
            end
        end

        S_PES_LEGACY_STUFF: begin
            if (in_data == 8'hff) begin
                legacy_prefix_bytes <= legacy_prefix_bytes + 16'd1;
            end else if (in_data[7:6] == 2'b01) begin
                legacy_prefix_bytes <= legacy_prefix_bytes + 16'd1;
                state               <= S_PES_LEGACY_STD2;
            end else if (in_data[7:4] == 4'h2 || in_data[7:4] == 4'h3) begin
                if (!legacy_ts_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else begin
                    payload_len    <= legacy_ts_payload_calc[15:0];
                    pts_is_legacy  <= 1'b1;
                    legacy_has_dts <= (in_data[7:4] == 4'h3);
                    pts_pending    <= 1'b1;
                    // This marker byte is already being shifted into
                    // pts_shift below, unlike the MPEG-2 path (which
                    // transitions to S_PES_PTS on the header_data_length
                    // byte, a byte the PTS itself does not include) - so
                    // the count of already-consumed PTS bytes starts at 1,
                    // not 0, or S_PES_PTS's completion check fires one
                    // byte too late and swallows the packet's first real
                    // payload byte into the tail of pts_shift instead.
                    pts_byte_index <= 3'd1;
                    pts_shift      <= {pts_shift[31:0], in_data};
                    state          <= S_PES_PTS;
                end
            end else if (in_data == 8'h0f) begin
                if (!legacy_none_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else if (legacy_none_payload_calc[15:0] == 16'd0) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= legacy_none_payload_calc[15:0];
                    state      <= S_PES_PAYLOAD;
                end
            end else begin
                demux_error <= 1'b1;
                state       <= S_SYNC;
                zero_run    <= 2'd0;
            end
        end

        // The STD_buffer_scale/size field is exactly 2 bytes with no
        // constraint of its own on the second byte's value - it is not
        // itself a candidate for the timestamp-marker check. Just consume
        // it and look for the marker on the byte after.
        S_PES_LEGACY_STD2: begin
            legacy_prefix_bytes <= legacy_prefix_bytes + 16'd1;
            state <= S_PES_LEGACY_TS_CHECK;
        end

        // Spec order allows only one STD field and no further stuffing
        // after it; the byte here must be a timestamp marker or the
        // no-timestamp marker.
        S_PES_LEGACY_TS_CHECK: begin
            if (in_data[7:4] == 4'h2 || in_data[7:4] == 4'h3) begin
                if (!legacy_ts_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else begin
                    payload_len    <= legacy_ts_payload_calc[15:0];
                    pts_is_legacy  <= 1'b1;
                    legacy_has_dts <= (in_data[7:4] == 4'h3);
                    pts_pending    <= 1'b1;
                    // This marker byte is already being shifted into
                    // pts_shift below, unlike the MPEG-2 path (which
                    // transitions to S_PES_PTS on the header_data_length
                    // byte, a byte the PTS itself does not include) - so
                    // the count of already-consumed PTS bytes starts at 1,
                    // not 0, or S_PES_PTS's completion check fires one
                    // byte too late and swallows the packet's first real
                    // payload byte into the tail of pts_shift instead.
                    pts_byte_index <= 3'd1;
                    pts_shift      <= {pts_shift[31:0], in_data};
                    state          <= S_PES_PTS;
                end
            end else if (in_data == 8'h0f) begin
                if (!legacy_none_payload_valid) begin
                    demux_error <= 1'b1;
                    state       <= S_SYNC;
                    zero_run    <= 2'd0;
                end else if (legacy_none_payload_calc[15:0] == 16'd0) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= legacy_none_payload_calc[15:0];
                    state      <= S_PES_PAYLOAD;
                end
            end else begin
                demux_error <= 1'b1;
                state       <= S_SYNC;
                zero_run    <= 2'd0;
            end
        end

        S_PES_HDR_B1: begin
            pts_dts_flags <= in_data[7:6];
            state         <= S_PES_HDR_B2;
        end

        S_PES_HDR_B2: begin
            pts_pending    <= pts_dts_flags[1]; // '10' or '11' both start with a PTS
            pts_is_legacy  <= 1'b0;
            pts_byte_index <= 3'd0;
            if (!payload_len_valid || pts_dts_flags == 2'b01 ||
                (pts_dts_flags == 2'b10 && in_data < 8'd5) ||
                (pts_dts_flags == 2'b11 && in_data < 8'd10)) begin
                demux_error <= 1'b1;
                state       <= S_SYNC;
                zero_run    <= 2'd0;
            end else begin
                payload_len <= payload_len_calc[15:0];
                if (pts_dts_flags[1] && in_data != 8'd0) begin
                    state <= S_PES_PTS;
                end else if (in_data != 8'd0) begin
                    skip_count <= {8'd0, in_data};
                    state      <= S_PES_HDR_SKIP;
                end else if (payload_len_calc[15:0] == 16'd0) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= payload_len_calc[15:0];
                    state      <= S_PES_PAYLOAD;
                end
            end
        end

        S_PES_PTS: begin
            pts_shift      <= {pts_shift[31:0], in_data};
            pts_byte_index <= pts_byte_index + 3'd1;
            if (pts_byte_index == 3'd4) begin
                if (pts_is_legacy) begin
                    if (legacy_has_dts) begin
                        // Skip the 5 DTS bytes; payload_len was already
                        // computed net of them.
                        skip_count <= 16'd5;
                        state      <= S_PES_HDR_SKIP;
                    end else if (payload_len == 16'd0) begin
                        state    <= S_SYNC;
                        zero_run <= 2'd0;
                    end else begin
                        skip_count <= payload_len;
                        state      <= S_PES_PAYLOAD;
                    end
                end else begin
                    // header_data_len's 5 PTS bytes are already accounted
                    // for in payload_len (computed from the full
                    // header_data_len regardless of what it is spent on),
                    // so what remains here is only any header bytes
                    // *beyond* those 5 - e.g. a trailing DTS field or
                    // stuffing.
                    if (payload_len == 16'd0 && header_extra_after_pts == 16'd0) begin
                        state    <= S_SYNC;
                        zero_run <= 2'd0;
                    end else if (header_extra_after_pts != 16'd0) begin
                        skip_count <= header_extra_after_pts;
                        state      <= S_PES_HDR_SKIP;
                    end else begin
                        skip_count <= payload_len;
                        state      <= S_PES_PAYLOAD;
                    end
                end
            end
        end

        S_PES_HDR_SKIP: begin
            if (skip_count == 16'd1) begin
                if (payload_len == 16'd0) begin
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
                    skip_count <= payload_len;
                    state      <= S_PES_PAYLOAD;
                end
            end else begin
                skip_count <= skip_count - 16'd1;
            end
        end

        S_PES_PAYLOAD: begin
            if (is_video) begin
                video_data  <= in_data;
                video_valid <= 1'b1;
                video_pts_valid <= pts_pending;
            end else begin
                audio_data  <= in_data;
                audio_valid <= 1'b1;
                audio_pts_valid <= pts_pending;
            end
            if (pts_pending) begin
                if (is_video) begin
                    video_pts       <= decoded_pts;
                    video_pts_valid <= 1'b1;
                end else begin
                    audio_pts       <= decoded_pts;
                    audio_pts_valid <= 1'b1;
                end
                pts_pending <= 1'b0;
            end
            if (skip_count == 16'd1) begin
                state    <= S_SYNC;
                zero_run <= 2'd0;
            end else begin
                skip_count <= skip_count - 16'd1;
            end
        end

        default: begin
            state    <= S_SYNC;
            zero_run <= 2'd0;
        end
        endcase
    end
end

// header_data_len itself is never stored - only two derived quantities are
// ever needed, and both are computed once, when header_data_len (in_data)
// is still live, at S_PES_HDR_B2:
//   payload_len              - elementary bytes after the whole optional
//                               header, stored above.
//   header_extra_after_pts   - header_data_len minus the 5 PTS bytes just
//                               consumed at S_PES_PTS, i.e. any trailing
//                               DTS/stuffing bytes still to skip.
reg [15:0] header_extra_after_pts;
always @(posedge clk) begin
    if (accept && state == S_PES_HDR_B2 && pts_dts_flags[1] && in_data != 8'd0)
        header_extra_after_pts <= (in_data >= 8'd5) ? ({8'd0, in_data} - 16'd5) : 16'd0;
end

endmodule
