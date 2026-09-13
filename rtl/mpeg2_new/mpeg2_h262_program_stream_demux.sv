//============================================================================
// MiSTer Media Player - MPEG-2 Program Stream / PES demultiplexer
//
// Entry 979: first stage of moving Program Stream demux, audio decode and
// overlay rendering into the FPGA core so a plain .mpg file can be loaded
// the same way any ROM-loading MiSTer core loads a ROM - stock Main streams
// the raw file bytes in, and everything downstream (this module included)
// lives in RTL. Scope matches core-reference.md's adopted H.222.0 records
// H222-001 through H222-006: pack header/stuffing, PES framing via the
// 16-bit PES_packet_length, the MPEG-2-style PES optional header (marker
// bits '10'), and video (stream_id 0xE0-0xEF) / audio (stream_id 0xC0-0xDF)
// stream_id routing. The legacy MPEG-1 pack header form (marker '0010') is
// also accepted since it costs one extra state; the legacy MPEG-1 PES
// optional-header form (leading 0xFF stuffing bytes and a bare '0010'/
// '0011' timestamp marker outside the '10' form) is not - every real encode
// this project has actually parsed uses the MPEG-2 form, and
// host/arm/media_player_helper.c's own legacy branch exists only for
// defensiveness, not because a test file has ever needed it. A packet whose
// PES optional header does not start with the '10' marker is treated as a
// syntax error and its declared length is skipped whole.
//
// Unlike the ARM helper's replacement scheme, there is no need to smuggle
// audio or overlay data back through the video elementary-stream pipe as
// in-band metadata (mpeg2_h262_inband_metadata's whole reason to exist):
// this module outputs video and audio elementary bytes as two independent
// ready/valid streams, each with its own directly-attached PTS, so nothing
// downstream needs to parse an invented escape protocol back out again.
//============================================================================
module mpeg2_h262_program_stream_demux
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
    output reg         demux_error
);

localparam [4:0]
    S_SYNC           = 5'd0,
    S_CODE           = 5'd1,
    S_PACK_B0        = 5'd2,
    S_PACK_SKIP      = 5'd3,
    S_PACK_STUFF_LEN = 5'd4,
    S_PACK_STUFF     = 5'd5,
    S_LEN_HI         = 5'd6,
    S_LEN_LO         = 5'd7,
    S_SKIP_PAYLOAD   = 5'd8,
    S_PES_HDR_B0     = 5'd9,
    S_PES_HDR_B1     = 5'd10,
    S_PES_HDR_B2     = 5'd11,
    S_PES_PTS        = 5'd12,
    S_PES_HDR_SKIP   = 5'd13,
    S_PES_PAYLOAD    = 5'd14;

reg [4:0]  state;
reg [1:0]  zero_run;
reg [7:0]  code;
reg        is_video;
reg        is_pack_mpeg2;
reg [15:0] pes_length;    // PES_packet_length: bytes remaining after this field
reg [15:0] skip_count;    // generic "bytes left in this run" counter
reg [15:0] payload_len;   // elementary bytes left once the PES header is done
reg [1:0]  pts_dts_flags;
reg [2:0]  pts_byte_index;
reg [39:0] pts_shift;     // 5 bytes captured MSB-first
reg        pts_pending;   // this PES has a PTS to publish with its first payload byte

assign in_ready =
    (state == S_PES_PAYLOAD) ? (is_video ? video_ready : audio_ready) : 1'b1;

wire accept = in_valid && in_ready;

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

always @(posedge clk) begin
    video_valid     <= 1'b0;
    audio_valid     <= 1'b0;
    video_pts_valid <= 1'b0;
    audio_pts_valid <= 1'b0;
    stream_end      <= 1'b0;

    if (reset) begin
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
            if (code[7:4] == 4'he || code[7:5] == 3'b110) begin
                if ({pes_length[15:8], in_data} == 16'd0) begin
                    // A zero-length video PES is only legal in a Transport
                    // Stream, never here; a zero-length audio PES carries
                    // nothing to decode either way. Resync.
                    state    <= S_SYNC;
                    zero_run <= 2'd0;
                end else begin
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
            end else begin
                // Legacy MPEG-1 PES header, or a malformed packet: skip the
                // remaining declared length rather than mis-parse it.
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

        S_PES_HDR_B1: begin
            pts_dts_flags <= in_data[7:6];
            state         <= S_PES_HDR_B2;
        end

        S_PES_HDR_B2: begin
            pts_pending    <= pts_dts_flags[1]; // '10' or '11' both start with a PTS
            pts_byte_index <= 3'd0;
            if (!payload_len_valid) begin
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
                // header_data_len's 5 PTS bytes are already accounted for
                // in payload_len (computed from the full header_data_len
                // regardless of what it is spent on), so what remains here
                // is only any header bytes *beyond* those 5 - e.g. a
                // trailing DTS field or stuffing.
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
            end else begin
                audio_data  <= in_data;
                audio_valid <= 1'b1;
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
